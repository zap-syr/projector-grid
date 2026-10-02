import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osc/osc.dart';
import 'package:projector_grid/core/services/osc_service.dart';
import 'package:projector_grid/features/workspace/domain/custom_command.dart';

typedef _Call = ({String cmd, String? groupId, bool all});

void main() {
  late OscService osc;
  late List<_Call> calls;

  setUp(() {
    osc = OscService();
    calls = [];
    osc.onCommand = ({required ntcontrolCmd, groupId, all = false}) async {
      calls.add((cmd: ntcontrolCmd, groupId: groupId, all: all));
    };
    osc.resolveGroupId = (address) => address == '/group/stage' ? 'g1' : null;
    osc.resolveCustomCommand = (slug) =>
        slug == 'dynamic-contrast' ? 'VXX:DCNI0=+00001' : null;
  });
  tearDown(() => osc.stop());

  void send(String address, [List<Object> args = const []]) =>
      osc.processMessage(OSCMessage(address, arguments: args));

  group('inbound address matching', () {
    test('/pgrid/all/<command> maps to NTCONTROL', () {
      send('/pgrid/all/power/on');
      send('/pgrid/all/shutter/close');
      send('/pgrid/all/lens/shift/down/fast');
      send('/pgrid/all/shutter-fade-in/0.5');
      expect(calls, [
        (cmd: 'PON', groupId: null, all: true),
        (cmd: 'OSH:1', groupId: null, all: true),
        (cmd: 'VXX:LNSI3=+00201', groupId: null, all: true),
        (cmd: 'VXX:SEFS1=0.5', groupId: null, all: true),
      ]);
    });

    test('/pgrid/group/<name>/<command> resolves the group', () {
      send('/pgrid/group/stage/shutter/open');
      expect(calls.single, (cmd: 'OSH:0', groupId: 'g1', all: false));
    });

    test('unknown group, missing command and unknown path are ignored', () {
      send('/pgrid/group/nowhere/power/on');
      send('/pgrid/group/stage');
      send('/pgrid/all/power/sideways');
      send('/somethingelse');
      expect(calls, isEmpty);
    });

    test('custom commands via slug, for all and for a group', () {
      send('/pgrid/all/custom/dynamic-contrast');
      send('/pgrid/group/stage/custom/dynamic-contrast');
      send('/pgrid/all/custom/unknown');
      expect(calls, [
        (cmd: 'VXX:DCNI0=+00001', groupId: null, all: true),
        (cmd: 'VXX:DCNI0=+00001', groupId: 'g1', all: false),
      ]);
    });

    test('arguments are ignored — the address alone selects the command', () {
      send('/pgrid/all/power/off', [1]);
      expect(calls.single.cmd, 'POF');
    });

    test('the same address is rate-limited, different ones are not', () {
      send('/pgrid/all/power/on');
      send('/pgrid/all/power/on');
      send('/pgrid/all/power/off');
      expect(calls.map((c) => c.cmd), ['PON', 'POF']);
    });
  });

  group('codec', () {
    test('int arguments round-trip through bytes', () {
      final bytes = OSCMessage(
        '/pgrid/status/online',
        arguments: [3],
      ).toBytes();
      final decoded = OSCMessage.fromBytes(bytes);
      expect(decoded.address, '/pgrid/status/online');
      expect(decoded.arguments, [3]);
    });

    test('string and float arguments round-trip', () {
      final bytes = OSCMessage(
        '/pgrid/group/stage/power/on',
        arguments: ['x', 1.5],
      ).toBytes();
      final decoded = OSCMessage.fromBytes(bytes);
      expect(decoded.arguments, ['x', 1.5]);
    });
  });

  group('outbound status', () {
    late RawDatagramSocket receiver;
    late StreamController<OSCMessage> received;
    var status = (online: 2, offline: 1, critical: 0, warning: 0);

    setUp(() async {
      receiver = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      received = StreamController<OSCMessage>();
      receiver.listen((e) {
        if (e != RawSocketEvent.read) return;
        final dg = receiver.receive();
        if (dg != null) received.add(OSCMessage.fromBytes(dg.data));
      });
      status = (online: 2, offline: 1, critical: 0, warning: 0);
      osc.getStatus = () => status;
      await osc.start(
        networkDevice: '127.0.0.1',
        receivePort: 0,
        sendIp: '127.0.0.1',
        sendPort: receiver.port,
      );
    });
    tearDown(() {
      receiver.close();
      received.close();
    });

    Future<List<String>> collect(int n) async => [
      for (final m in await received.stream.take(n).toList())
        '${m.address} ${m.arguments}',
    ];

    test('first send broadcasts all four, then only what changed', () async {
      expect(osc.isActive, isTrue);
      osc.sendStatusIfActive();
      status = (online: 3, offline: 0, critical: 2, warning: 0);
      osc.sendStatusIfActive();
      osc.sendStatusIfActive(); // unchanged — nothing sent
      expect(await collect(7), [
        '/pgrid/status/online [2]',
        '/pgrid/status/offline [1]',
        '/pgrid/status/critical [0]',
        '/pgrid/status/warning [0]',
        '/pgrid/status/online [3]',
        '/pgrid/status/offline [0]',
        '/pgrid/status/critical [2]',
      ]);
    });

    test('/pgrid/status forces all four even when unchanged', () async {
      osc.sendStatusIfActive();
      send('/pgrid/status');
      final msgs = await collect(8);
      expect(msgs.sublist(4), [
        '/pgrid/status/online [2]',
        '/pgrid/status/offline [1]',
        '/pgrid/status/critical [0]',
        '/pgrid/status/warning [0]',
      ]);
    });

    test('sendMessage goes out on the socket', () async {
      osc.sendMessage('/pgrid/alert/offline', ['PRJ-03', 1]);
      expect(await collect(1), ['/pgrid/alert/offline [PRJ-03, 1]']);
    });
  });

  group('encodeOscMessage', () {
    // A spec-correct reader. package:osc's decoder steps over a string by
    // its length without the terminating null, so it misreads everything
    // after a string of 4n bytes (an IP like 10.0.0.3, "critical").
    List<Object> decode(List<int> bytes) {
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      var i = 0;
      String string() {
        final end = bytes.indexOf(0, i);
        final s = utf8.decode(bytes.sublist(i, end));
        i = (end + 4) & ~3;
        return s;
      }

      final args = <Object>[string()];
      for (final tag in string().substring(1).split('')) {
        if (tag == 's') {
          args.add(string());
        } else {
          args.add(data.getInt32(i));
          i += 4;
        }
      }
      return args;
    }

    test('mixed arguments, strings of 4n bytes included', () {
      expect(
        decode(
          encodeOscMessage('/pgrid/alert/offline', [
            'PRJ-03',
            '10.0.0.3',
            1,
            'critical',
            'No answer',
          ]),
        ),
        [
          '/pgrid/alert/offline',
          'PRJ-03',
          '10.0.0.3',
          1,
          'critical',
          'No answer',
        ],
      );
    });

    test('strings are UTF-8: degree sign and Cyrillic names survive', () {
      expect(decode(encodeOscMessage('/a', ['Проектор 1', '58 °C'])), [
        '/a',
        'Проектор 1',
        '58 °C',
      ]);
    });

    test('every string ends in at least one null, padded to 4', () {
      final bytes = encodeOscMessage('/abc', []);
      expect(bytes.length % 4, 0);
      expect(bytes.sublist(0, 8), [..."/abc".codeUnits, 0, 0, 0, 0]);
    });
  });

  group('custom command slugs', () {
    CustomCommand cmd(String name) =>
        CustomCommand(id: '1', name: name, command: 'X');

    test('lowercases and hyphenates', () {
      expect(cmd('Dynamic Contrast').oscSlug, 'dynamic-contrast');
      expect(cmd('House Lights!').oscSlug, 'house-lights');
      expect(cmd('  --A  B--  ').oscSlug, 'a-b');
      expect(cmd('Scene 2 / Warm').oscSlug, 'scene-2-warm');
    });

    test('address uses the custom prefix', () {
      expect(
        cmd('Dynamic Contrast').oscAddress,
        '/pgrid/custom/dynamic-contrast',
      );
    });

    test('json round-trip', () {
      final c = CustomCommand.fromJson(
        const CustomCommand(id: 'a', name: 'N', command: 'OSH:1').toJson(),
      );
      expect((c.id, c.name, c.command), ('a', 'N', 'OSH:1'));
    });
  });
}
