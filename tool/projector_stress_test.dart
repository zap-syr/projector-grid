// Panasonic NTCONTROL concurrency stress test.
//
//   dart run tool/projector_stress_test.dart [ip] [login] [password]
//
// Talks to a REAL projector. Every command sent is the read-only `QID`
// (model-name query) — nothing here changes projector state.
//
// It answers two questions:
//   1. How many simultaneous TCP connections will the projector's embedded
//      stack accept at once (raw connect ceiling)?
//   2. How many concurrent full NTCONTROL command cycles (connect + handshake
//      + MD5 auth + command + reply + close) complete reliably, in a burst and
//      under sustained load?
//
// Use the numbers to sanity-check geometry_correction_dialog.dart's 15-wide
// `Future.wait` and PanasonicProtocolService.pollProjectorTelemetry's
// per-node concurrency cap.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

// ── Config ───────────────────────────────────────────────────────────────────
String ip = '192.168.0.8';
const int port = 1024;
String login = 'dispadmin';
String password = '@Panasonic';

const String probeCmd = 'QID'; // read-only model-name query
const Duration connectTimeout = Duration(seconds: 4);
const Duration handshakeTimeout = Duration(seconds: 5);
const Duration responseTimeout = Duration(seconds: 5);

// Which phases to run.
const bool runPhaseA = true; // raw connect ceiling
const bool runPhaseB = true; // burst concurrency sweep
const bool runPhaseC = true; // sustained load on the promising levels

const List<int> rawConnectLevels = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30];
const List<int> burstLevels = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20];
const int burstsPerLevel = 8;
const Duration gapBetweenBursts = Duration(milliseconds: 800);
const Duration gapBetweenPhases = Duration(seconds: 3);
const Duration sustainedDuration = Duration(seconds: 45);
const List<int> sustainedLevels = [2, 3, 5];

// ── Outcome model ────────────────────────────────────────────────────────────
enum Outcome {
  ok,
  authReject, // ERRA — bad credentials
  busyErr, // ERR3 etc. — projector refused this request right now
  errOther, // some other ERx reply
  connRefused, // TCP RST — connection cap hit, refusing new sockets
  connTimeout, // SYN dropped — stack saturated
  handshakeTimeout, // connected but never sent the NTCONTROL banner
  respTimeout, // authed but never answered the command
  socketError, // reset mid-exchange, etc.
}

bool isFailure(Outcome o) => o != Outcome.ok;

class CycleResult {
  final Outcome outcome;
  final int ms;
  final String detail;
  CycleResult(this.outcome, this.ms, [this.detail = '']);
}

// ── One full NTCONTROL cycle ─────────────────────────────────────────────────
Future<CycleResult> runCycle() async {
  final sw = Stopwatch()..start();
  Socket? socket;
  StreamSubscription<dynamic>? sub;
  try {
    try {
      socket = await Socket.connect(ip, port, timeout: connectTimeout);
    } on SocketException catch (e) {
      final msg = (e.osError?.message ?? e.message).toLowerCase();
      if (msg.contains('refused') || e.osError?.errorCode == 10061) {
        return CycleResult(Outcome.connRefused, sw.elapsedMilliseconds);
      }
      if (msg.contains('timed out') ||
          msg.contains('timeout') ||
          e.osError?.errorCode == 10060) {
        return CycleResult(Outcome.connTimeout, sw.elapsedMilliseconds);
      }
      return CycleResult(Outcome.socketError, sw.elapsedMilliseconds, msg);
    }

    var completer = Completer<String>();
    var buffer = StringBuffer();
    void pump() {
      final content = buffer.toString();
      final i = content.indexOf('\r');
      if (i != -1) {
        final line = content.substring(0, i);
        buffer = StringBuffer(content.substring(i + 1));
        if (!completer.isCompleted) completer.complete(line);
      }
    }

    sub = socket.listen(
      (data) {
        buffer.write(ascii.decode(data));
        pump();
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    final String banner;
    try {
      banner = await completer.future.timeout(handshakeTimeout);
    } on TimeoutException {
      return CycleResult(Outcome.handshakeTimeout, sw.elapsedMilliseconds);
    }

    if (!banner.startsWith('NTCONTROL')) {
      return CycleResult(
          Outcome.socketError, sw.elapsedMilliseconds, 'bad banner: $banner');
    }

    var prefix = '00';
    if (banner.contains(' 1 ')) {
      final m = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})').firstMatch(banner);
      if (m == null) {
        return CycleResult(
            Outcome.socketError, sw.elapsedMilliseconds, 'no token in: $banner');
      }
      prefix = '${md5.convert(utf8.encode('$login:$password:${m.group(1)}'))}00';
    }

    completer = Completer<String>();
    pump();
    socket.add(ascii.encode('$prefix$probeCmd\r'));
    await socket.flush();

    final String raw;
    try {
      raw = await completer.future.timeout(responseTimeout);
    } on TimeoutException {
      return CycleResult(Outcome.respTimeout, sw.elapsedMilliseconds);
    }

    var r = raw.trim();
    if (r.startsWith('00') && r.length > 2) r = r.substring(2);
    sw.stop();

    if (r.startsWith('ERRA')) {
      return CycleResult(Outcome.authReject, sw.elapsedMilliseconds, r);
    }
    if (r.startsWith('ER')) {
      final code = r.length >= 4 ? r.substring(0, 4) : r;
      return CycleResult(
          code == 'ERR3' ? Outcome.busyErr : Outcome.errOther,
          sw.elapsedMilliseconds,
          code);
    }
    return CycleResult(Outcome.ok, sw.elapsedMilliseconds, r);
  } on TimeoutException {
    return CycleResult(Outcome.respTimeout, sw.elapsedMilliseconds);
  } catch (e) {
    return CycleResult(Outcome.socketError, sw.elapsedMilliseconds, '$e');
  } finally {
    await sub?.cancel();
    socket?.destroy();
  }
}

// ── Raw connect: open [n] sockets at once, hold, count survivors ─────────────
Future<({int ok, int refused, int timeout, int other})> runRawConnect(
    int n) async {
  var ok = 0, refused = 0, timeout = 0, other = 0;
  final sockets = <Socket>[];
  await Future.wait(List.generate(n, (_) async {
    try {
      final s = await Socket.connect(ip, port, timeout: connectTimeout);
      sockets.add(s);
      s.listen((_) {}, onError: (_) {}, cancelOnError: true);
      ok++;
    } on SocketException catch (e) {
      final msg = (e.osError?.message ?? e.message).toLowerCase();
      if (msg.contains('refused') || e.osError?.errorCode == 10061) {
        refused++;
      } else if (msg.contains('timed out') ||
          msg.contains('timeout') ||
          e.osError?.errorCode == 10060) {
        timeout++;
      } else {
        other++;
      }
    } catch (_) {
      other++;
    }
  }));
  // Hold them concurrently for a beat so the projector sees them all open,
  // then drop everything.
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  for (final s in sockets) {
    s.destroy();
  }
  return (ok: ok, refused: refused, timeout: timeout, other: other);
}

// ── Stats helpers ────────────────────────────────────────────────────────────
int pct(List<int> sorted, int p) {
  if (sorted.isEmpty) return 0;
  final idx = ((p / 100) * (sorted.length - 1)).round();
  return sorted[idx.clamp(0, sorted.length - 1)];
}

String tally(List<CycleResult> results) {
  final counts = <Outcome, int>{};
  for (final r in results) {
    counts[r.outcome] = (counts[r.outcome] ?? 0) + 1;
  }
  final parts = <String>[];
  for (final o in Outcome.values) {
    final c = counts[o] ?? 0;
    if (c > 0) parts.add('${o.name}=$c');
  }
  return parts.join(' ');
}

// ── Main ─────────────────────────────────────────────────────────────────────
Future<void> main(List<String> args) async {
  if (args.isNotEmpty) ip = args[0];
  if (args.length > 1) login = args[1];
  if (args.length > 2) password = args[2];

  stdout.writeln('Panasonic NTCONTROL stress test');
  stdout.writeln('target : $ip:$port   login: $login');
  stdout.writeln('probe  : $probeCmd (read-only)');
  stdout.writeln('=' * 72);

  // Phase 0 — sanity.
  stdout.write('\n[warm-up] single cycle ... ');
  final warm = await runCycle();
  stdout.writeln('${warm.outcome.name} (${warm.ms} ms) ${warm.detail}');
  if (warm.outcome == Outcome.authReject) {
    stdout.writeln('\nABORT: credentials rejected (ERRA). Fix login/password.');
    exit(1);
  }
  if (warm.outcome == Outcome.connRefused ||
      warm.outcome == Outcome.connTimeout ||
      warm.outcome == Outcome.handshakeTimeout) {
    stdout.writeln('\nABORT: projector not reachable on $ip:$port.');
    exit(1);
  }

  // Phase A — raw connect ceiling.
  if (runPhaseA) {
    stdout.writeln('\n── Phase A: raw simultaneous TCP connections ──');
    stdout.writeln('  N   ok  refused  timeout  other');
    for (final n in rawConnectLevels) {
      final r = await runRawConnect(n);
      stdout.writeln('${n.toString().padLeft(3)}  '
          '${r.ok.toString().padLeft(3)}  '
          '${r.refused.toString().padLeft(7)}  '
          '${r.timeout.toString().padLeft(7)}  '
          '${r.other.toString().padLeft(5)}');
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }

  // Phase B — burst concurrency sweep.
  final bestByLevel = <int, double>{};
  if (runPhaseB) {
    if (runPhaseA) await Future<void>.delayed(gapBetweenPhases);
    stdout.writeln('\n── Phase B: concurrent full command cycles (burst) ──');
    stdout.writeln('conc  n   ok%   p50    p95    max   breakdown');
    for (final c in burstLevels) {
      final all = <CycleResult>[];
      for (var b = 0; b < burstsPerLevel; b++) {
        final batch = await Future.wait(List.generate(c, (_) => runCycle()));
        all.addAll(batch);
        await Future<void>.delayed(gapBetweenBursts);
      }
      final oks = all.where((r) => r.outcome == Outcome.ok).map((r) => r.ms).toList()
        ..sort();
      final okPct = 100.0 * oks.length / all.length;
      bestByLevel[c] = okPct;
      stdout.writeln('${c.toString().padLeft(4)}  '
          '${all.length.toString().padLeft(3)}  '
          '${okPct.toStringAsFixed(0).padLeft(3)}  '
          '${pct(oks, 50).toString().padLeft(5)}  '
          '${pct(oks, 95).toString().padLeft(5)}  '
          '${(oks.isEmpty ? 0 : oks.last).toString().padLeft(5)}   '
          '${tally(all)}');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  // Phase C — sustained load.
  if (runPhaseC) {
    if (runPhaseA || runPhaseB) await Future<void>.delayed(gapBetweenPhases);
    stdout.writeln('\n── Phase C: sustained load '
        '(${sustainedDuration.inSeconds}s per level) ──');
    stdout.writeln('conc  cycles  ok%   p50    p95    max   breakdown');
    for (final c in sustainedLevels) {
      final all = <CycleResult>[];
      final deadline = DateTime.now().add(sustainedDuration);
      while (DateTime.now().isBefore(deadline)) {
        all.addAll(await Future.wait(List.generate(c, (_) => runCycle())));
      }
      final oks = all.where((r) => r.outcome == Outcome.ok).map((r) => r.ms).toList()
        ..sort();
      final okPct = 100.0 * oks.length / all.length;
      stdout.writeln('${c.toString().padLeft(4)}  '
          '${all.length.toString().padLeft(6)}  '
          '${okPct.toStringAsFixed(0).padLeft(3)}  '
          '${pct(oks, 50).toString().padLeft(5)}  '
          '${pct(oks, 95).toString().padLeft(5)}  '
          '${(oks.isEmpty ? 0 : oks.last).toString().padLeft(5)}   '
          '${tally(all)}');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  // Recommendation.
  if (bestByLevel.isNotEmpty) {
    stdout.writeln('\n── Summary ──');
    final clean = bestByLevel.entries.where((e) => e.value >= 100).map((e) => e.key);
    final safe = clean.isEmpty ? 0 : clean.reduce((a, b) => a > b ? a : b);
    final degrade = bestByLevel.entries
        .where((e) => e.value < 100 && e.value >= 90)
        .map((e) => e.key)
        .toList()
      ..sort();
    stdout.writeln('highest burst concurrency at 100% success : '
        '${safe == 0 ? "none" : safe}');
    if (degrade.isNotEmpty) {
      stdout.writeln('starts degrading (90-99%) at             : ${degrade.first}');
    }
    stdout.writeln('geometry dialog currently fires 15 at once.');
  }
  stdout.writeln('\ndone.');
}
