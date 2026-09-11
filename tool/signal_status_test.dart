// Standby/pre-show signal source probe — dart run tool/signal_status_test.dart
//
// NTCONTROL QVX:NSGS1 returns ER401 while the projector is in Standby, even
// with pre-show streaming a real picture. The web UI's own preview.cgi reacts
// to a WebSocket 'SIGNAL' message by reloading simple_status_hidden.cgi and
// copying its #id_preview_table_td_info / #id_input_right_table into the
// visible status frame. This probe opens the preview WebSocket, watches every
// text message, and re-fetches + parses that HTTP page (via curl --digest,
// since it's proven against this server) on each 'SIGNAL' to see whether it
// reflects reality while NTCONTROL can't.

import 'dart:async';
import 'dart:io';

const host = '192.168.0.8';
const webUser = 'dispadmin';
const webPass = '@Panasonic';
const watch = Duration(seconds: 30);

Future<String> _fetchStatusPage() async {
  final result = await Process.run('curl', [
    '-s',
    '-m',
    '10',
    '--digest',
    '-u',
    '$webUser:$webPass',
    'http://$host/cgi-bin/simple_status_hidden.cgi?lang=e',
  ]);
  return result.stdout as String;
}

Map<String, String> _parseStatusPage(String html) {
  final out = <String, String>{};
  final preview = RegExp(
    r'id_preview_table_td_info"[^>]*>(.*?)</td>',
    dotAll: true,
  ).firstMatch(html);
  out['activeInput'] = (preview?.group(1) ?? '')
      .replaceAll(RegExp(r'<[^>]+>|&nbsp;'), '')
      .trim();

  for (final row in RegExp(
    r'<td class="td_left"><span[^>]*>([^<]*)</span></td>'
    r'<td class="td_right">(?:<span[^>]*>)?([^<]*)</span>',
    dotAll: true,
  ).allMatches(html)) {
    out[row.group(1)!.trim()] = row.group(2)!.trim();
  }
  return out;
}

Future<void> printStatus(String why) async {
  final html = await _fetchStatusPage();
  final s = _parseStatusPage(html);
  stdout.writeln(
    '  [$why] activeInput="${s['activeInput']}" '
    'INPUT="${s['INPUT']}" '
    'SIGNAL NAME="${s['SIGNAL NAME']}" '
    'SIGNAL FREQUENCY="${s['SIGNAL FREQUENCY']}"',
  );
}

Future<void> main() async {
  stdout.writeln('--- baseline (before opening preview) ---');
  await printStatus('baseline');

  final ws = await WebSocket.connect(
    'ws://$host/remotepreview',
    protocols: const ['pj-cast-protocol'],
  ).timeout(const Duration(seconds: 5));
  ws.add('start');
  final alive = Timer.periodic(
    const Duration(seconds: 5),
    (_) => ws.add('alive'),
  );

  stdout.writeln(
    '\n--- watching ${watch.inSeconds}s: text messages + status page on SIGNAL ---',
  );
  final done = Completer<void>();
  Timer(watch, () {
    if (!done.isCompleted) done.complete();
  });
  ws.listen(
    (d) {
      if (d is String) {
        stdout.writeln('  ws text: $d');
        if (d == 'PING') {
          ws.add('PONG');
        } else {
          ws.add('receive');
          if (d == 'SIGNAL') {
            printStatus('on SIGNAL');
          }
        }
      } else {
        ws.add('receive');
      }
    },
    cancelOnError: true,
  );

  await done.future;
  alive.cancel();
  await ws.close();

  stdout.writeln('\n--- final status page fetch ---');
  await printStatus('final');
}
