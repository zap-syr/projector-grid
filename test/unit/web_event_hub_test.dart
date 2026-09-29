import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/web_event_hub.dart';

void main() {
  test('encodes an SSE event', () {
    expect(
      utf8.decode(encodeSseEvent((name: 'projector', data: {'id': '1'}))),
      'event: projector\ndata: {"id":"1"}\n\n',
    );
  });

  test(
    'a new client gets retry, the initial events, then broadcasts',
    () async {
      final hub = WebEventHub();
      final received = <String>[];
      final sub = hub
          .subscribe('t1', [(name: 'snapshot', data: 1)])
          .map(utf8.decode)
          .listen(received.add);
      hub.broadcast((name: 'projector', data: 2));
      await pumpEventQueue();

      expect(received, [
        'retry: 3000\n\n',
        'event: snapshot\ndata: 1\n\n',
        'event: projector\ndata: 2\n\n',
      ]);
      expect(hub.clientCount, 1);
      await sub.cancel();
      expect(hub.clientCount, 0);
    },
  );

  test('close ends only that token\'s streams, after the last event', () async {
    final hub = WebEventHub();
    final a = <String>[];
    final b = <String>[];
    var aDone = false;
    hub
        .subscribe('a', const [])
        .map(utf8.decode)
        .listen(a.add, onDone: () => aDone = true);
    hub.subscribe('b', const []).map(utf8.decode).listen(b.add);

    hub.close('a', last: (name: 'signedOut', data: const {}));
    await pumpEventQueue();

    expect(a.last, 'event: signedOut\ndata: {}\n\n');
    expect(aDone, isTrue);
    expect(hub.clientCount, 1);
    hub.closeAll();
    expect(hub.clientCount, 0);
  });

  test('heartbeat pings live sessions and drops dead ones', () async {
    var alive = true;
    final touched = <String>[];
    final hub = WebEventHub(
      heartbeat: const Duration(milliseconds: 10),
      onHeartbeat: (t) {
        touched.add(t);
        return alive;
      },
    );
    final received = <String>[];
    var done = false;
    hub
        .subscribe('t', const [])
        .map(utf8.decode)
        .listen(received.add, onDone: () => done = true);

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(received, contains(': ping\n\n'));
    expect(touched, contains('t'));

    alive = false;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(done, isTrue);
    expect(hub.clientCount, 0);
  });
}
