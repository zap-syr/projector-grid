import 'dart:async';
import 'dart:io';

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
    var status = (online: 2, offline: 1, warnings: 0);

    setUp(() async {
      receiver = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      received = StreamController<OSCMessage>();
      receiver.listen((e) {
        if (e != RawSocketEvent.read) return;
        final dg = receiver.receive();
        if (dg != null) received.add(OSCMessage.fromBytes(dg.data));
      });
      status = (online: 2, offline: 1, warnings: 0);
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

    test('first send broadcasts all three, then only what changed', () async {
      expect(osc.isActive, isTrue);
      osc.sendStatusIfActive();
      status = (online: 3, offline: 0, warnings: 0);
      osc.sendStatusIfActive();
      osc.sendStatusIfActive(); // unchanged — nothing sent
      expect(await collect(5), [
        '/pgrid/status/online [2]',
        '/pgrid/status/offline [1]',
        '/pgrid/status/warning [0]',
        '/pgrid/status/online [3]',
        '/pgrid/status/offline [0]',
      ]);
    });

    test('/pgrid/status forces all three even when unchanged', () async {
      osc.sendStatusIfActive();
      send('/pgrid/status');
      final msgs = await collect(6);
      expect(msgs.sublist(3), [
        '/pgrid/status/online [2]',
        '/pgrid/status/offline [1]',
        '/pgrid/status/warning [0]',
      ]);
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
