// Panasonic NTCONTROL Edge Blending live probe.
//
//   dart run tool/edge_blend_test.dart [ip] [login] [password]
//
// Talks to a REAL projector. Backs the open questions in
// plan/EDGE_BLENDING_PLAN.md §7 before the Edge Blending dialog is built:
//
//   Phase 1 (read-only, always runs): query every edge-blending register from
//     the command sheet and print the raw reply, so the reply shape of each
//     command family (VXX / legacy short / RGBW tuple) is confirmed — notably
//     QJI/QJO, which the sheet documents as replying a bare `0`.
//   Phase 2 (writes, opt-in via runWriteTests): find the real Start / Width /
//     Black-border-width ceilings per edge by binary search (write + read-back),
//     record what max+1 does (ERR2 vs silent clamp), check whether the
//     projector constrains Start+Width, round-trip the RGBW tuples, check what
//     Interlocked does to R/G/B, and check which registers answer while
//     Edge Blending is Off (the QPDI1 ER401 trap from
//     plan/QUAD_PIXEL_DRIVE_CORNER_LIMITS.md).
//
// Phase 2 visibly changes the projected image while it runs. Use a unit that
// is not in a live show. Every register it touches is restored from the
// Phase 1 snapshot at the end (also on error). The free-shape Execute
// commands (VXX:EFII1-4) are never sent — they aren't reversible.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

// ── Config ───────────────────────────────────────────────────────────────────
String ip = '192.168.0.8';
const int port = 1024;
String login = 'dispadmin';
String password = '@Panasonic';

const bool runWriteTests = false; // Phase 2 — changes projector state
const bool probeLimits = true; // binary-search Start/Width/Border ceilings
const bool probeRgbw = true; // RGBW round-trip + Interlocked behavior
const bool probeModeOff = true; // which registers answer while EDBI0 = Off
const bool probeQpd = true; // limits with Quad Pixel Drive on vs off

// Upper bound for the ceiling search — legacy start/border commands only
// carry 4 digits, so nothing above 9999 is expressible on the wire.
const int searchCeiling = 9999;
// Small gap between sequential commands so the probe never stacks up
// connections on the projector (see references/concurrency_limits.md).
const Duration gap = Duration(milliseconds: 40);
const Duration connectTimeout = Duration(seconds: 4);
const Duration replyTimeout = Duration(seconds: 4);

// ── Register table (from Panasonic - Edge Blending - Sheet1.csv) ─────────────
enum Fmt {
  vxxInt, // VXX:KEY=+0000N   / QVX:KEY → KEY=+0000N
  legacyInt4, // VKEY:NNNN     / QKEY    → NNNN
  legacyBool, // VKEY:N        / QKEY    → N
  legacyRgbw, // VKEY:W,R,G,B  / QKEY    → W,R,G,B (unconfirmed)
  vxxRgbw, // VXX:KEY=W,R,G,B / QVX:KEY → KEY=W,R,G,B
}

class Reg {
  final String label;
  final String key;
  final Fmt fmt;
  const Reg(this.label, this.key, this.fmt);

  bool get isVxx => fmt == Fmt.vxxInt || fmt == Fmt.vxxRgbw;
  bool get isRgbw => fmt == Fmt.legacyRgbw || fmt == Fmt.vxxRgbw;
  String get query => isVxx ? 'QVX:$key' : 'Q$key';

  String write(Object v) => switch (fmt) {
    Fmt.vxxInt => 'VXX:$key=${f5(v as int)}',
    Fmt.legacyInt4 => 'V$key:${f4(v as int)}',
    Fmt.legacyBool => 'V$key:$v',
    Fmt.legacyRgbw => 'V$key:$v',
    Fmt.vxxRgbw => 'VXX:$key=$v',
  };
}

const edges = ['Upper', 'Lower', 'Left', 'Right'];

// Per-edge keys, in `edges` order.
const enableKeys = ['GU', 'GB', 'GL', 'GR'];
const startKeys = ['EU', 'EB', 'EL', 'ER'];
const widthKeys = ['EUWI0', 'EBWI0', 'ELWI0', 'ERWI0'];
const borderWidthKeys = ['JU', 'JB', 'JL', 'JR'];
const overlapKeys = ['EBBS0', 'EBBS1', 'EBBS2', 'EBBS3'];
const overlapIlKeys = ['EBII3', 'EBII4', 'EBII5', 'EBII6'];
const areaKeys = ['EBFI1', 'EBFI2', 'EBFI3', 'EBFI4'];
const pointsKeys = ['EFPI1', 'EFPI2', 'EFPI3', 'EFPI4'];

const modeReg = Reg('Mode (0 off/1 on/2 user)', 'EDBI0', Fmt.vxxInt);
const nonOvReg = Reg('Non-overlapped level', 'JI', Fmt.legacyRgbw);
const nonOvIlReg = Reg('Non-overlapped interlocked', 'EBII1', Fmt.vxxInt);
const borderReg = Reg('Black border level', 'JO', Fmt.legacyRgbw);
const borderIlReg = Reg('Black border interlocked', 'EBII2', Fmt.vxxInt);

List<Reg> get allRegs => [
  modeReg,
  const Reg('Markers', 'GM', Fmt.legacyBool),
  const Reg('Auto test pattern', 'EATI1', Fmt.vxxInt),
  const Reg(
    'Black level mode (0 soft+black/1 black only)',
    'EBMI1',
    Fmt.vxxInt,
  ),
  for (var i = 0; i < 4; i++) ...[
    Reg('${edges[i]} enable', enableKeys[i], Fmt.legacyBool),
    Reg('${edges[i]} start', startKeys[i], Fmt.legacyInt4),
    Reg('${edges[i]} width', widthKeys[i], Fmt.vxxInt),
  ],
  nonOvReg,
  nonOvIlReg,
  borderReg,
  borderIlReg,
  for (var i = 0; i < 4; i++) ...[
    Reg('${edges[i]} border width', borderWidthKeys[i], Fmt.legacyInt4),
    Reg('${edges[i]} overlapped level', overlapKeys[i], Fmt.vxxRgbw),
    Reg('${edges[i]} overlapped interlocked', overlapIlKeys[i], Fmt.vxxInt),
    Reg('${edges[i]} border area adjust', areaKeys[i], Fmt.vxxInt),
    Reg('${edges[i]} free-shape points', pointsKeys[i], Fmt.vxxInt),
  ],
];

// ── Wire helpers ─────────────────────────────────────────────────────────────
String f4(int v) => v.toString().padLeft(4, '0');
String f5(int v) => '${v < 0 ? '-' : '+'}${v.abs().toString().padLeft(5, '0')}';

// `ER\d+` only — a bare `ER` prefix would also match the valid reply
// `ERWI0=…` (Right width).
bool isError(String r) =>
    r == 'Timeout' || r.startsWith('Error') || RegExp(r'^ER\d+$').hasMatch(r);

/// One command per TCP connection, as the app does. Returns the reply with
/// the leading `00` stripped (same rule as `_sendSingleCommandEx`), or
/// `Timeout` / `Error: …` on transport failure.
Future<String> send(String cmd) async {
  await Future<void>.delayed(gap);
  Socket? socket;
  try {
    socket = await Socket.connect(ip, port, timeout: connectTimeout);
    final lines = StreamController<String>();
    var buffer = '';
    final sub = socket.listen((data) {
      buffer += ascii.decode(data, allowInvalid: true);
      var i = buffer.indexOf('\r');
      while (i >= 0) {
        lines.add(buffer.substring(0, i));
        buffer = buffer.substring(i + 1);
        i = buffer.indexOf('\r');
      }
    }, onError: (Object e) => lines.addError(e));
    final replies = StreamIterator(lines.stream);

    if (!await replies.moveNext().timeout(replyTimeout)) return 'Error: closed';
    final banner = replies.current;
    var prefix = '00';
    final token = RegExp(r'NTCONTROL\s1\s([0-9a-fA-F]{8})')
        .firstMatch(banner)
        ?.group(1);
    if (token != null) {
      prefix = '${md5.convert(utf8.encode('$login:$password:$token'))}00';
    }

    socket.add(ascii.encode('$prefix$cmd\r'));
    await socket.flush();
    if (!await replies.moveNext().timeout(replyTimeout)) return 'Error: closed';
    final reply = replies.current.trim();
    await sub.cancel();
    return reply.startsWith('00') && reply.length > 2
        ? reply.substring(2)
        : reply;
  } on TimeoutException {
    return 'Timeout';
  } catch (e) {
    return 'Error: $e';
  } finally {
    socket?.destroy();
  }
}

/// Value part of a reply: after `KEY=` when present, else the whole reply.
String valueOf(String reply, String key) {
  final i = reply.indexOf('$key=');
  return i >= 0 ? reply.substring(i + key.length + 1).trim() : reply.trim();
}

int? intOf(String reply, String key) => isError(reply)
    ? null
    : int.tryParse(valueOf(reply, key).replaceAll('+', ''));

/// Normalizes an RGBW reply to `WWW,RRR,GGG,BBB`, or null when it isn't a
/// 4-value tuple (the sheet shows QJI replying a bare `0` — see Phase 1).
String? rgbwOf(String reply, String key) {
  if (isError(reply)) return null;
  final parts = valueOf(reply, key).split(',');
  if (parts.length != 4) return null;
  final nums = parts.map((p) => int.tryParse(p.trim())).toList();
  if (nums.any((n) => n == null)) return null;
  return nums.map((n) => n!.toString().padLeft(3, '0')).join(',');
}

Future<int?> readInt(Reg r) async => intOf(await send(r.query), r.key);

// ── Report ───────────────────────────────────────────────────────────────────
final findings = <String>[];
void note(String s) {
  findings.add(s);
  stdout.writeln('  → $s');
}

void header(String s) => stdout.writeln('\n══ $s ${'═' * (70 - s.length)}');

// ── Phase 1: snapshot ────────────────────────────────────────────────────────
Future<Map<Reg, String>> snapshot() async {
  header('Phase 1 — read every register');
  final snap = <Reg, String>{};
  for (final r in allRegs) {
    final reply = await send(r.query);
    snap[r] = reply;
    final shape = switch (r.fmt) {
      _ when isError(reply) => 'ERROR',
      Fmt.legacyRgbw || Fmt.vxxRgbw =>
        rgbwOf(reply, r.key) != null ? 'tuple ok' : 'NOT a W,R,G,B tuple',
      _ => intOf(reply, r.key) != null ? 'int ok' : 'NOT an int',
    };
    stdout.writeln(
      '${r.query.padRight(10)} ${r.label.padRight(46)} "$reply"  [$shape]',
    );
    if (shape != 'int ok' && shape != 'tuple ok') {
      note('${r.query} (${r.label}) replied "$reply" — $shape');
    }
  }
  return snap;
}

// ── Phase 2: limits ──────────────────────────────────────────────────────────
/// True when the projector accepted [v] and reads it back unchanged. A value
/// that is accepted but read back clamped counts as "not accepted", so the
/// search lands on the real ceiling either way.
Future<bool> accepts(Reg r, int v) async {
  final w = await send(r.write(v));
  if (isError(w)) return false;
  return await readInt(r) == v;
}

/// Largest value in [0, searchCeiling] the register accepts verbatim.
Future<int?> findCeiling(Reg r) async {
  if (!await accepts(r, 0)) return null;
  if (await accepts(r, searchCeiling)) return searchCeiling;
  var lo = 0, hi = searchCeiling - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (await accepts(r, mid)) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

/// What max+1 does: rejected with an ER code, or accepted and clamped.
Future<String> overshoot(Reg r, int max) async {
  final w = await send(r.write(max + 1));
  final back = await send(r.query);
  return 'write ${max + 1} → "$w", read back "$back"';
}

Reg startReg(int i) => Reg('${edges[i]} start', startKeys[i], Fmt.legacyInt4);
Reg widthReg(int i) => Reg('${edges[i]} width', widthKeys[i], Fmt.vxxInt);
Reg borderWidthReg(int i) =>
    Reg('${edges[i]} border width', borderWidthKeys[i], Fmt.legacyInt4);

/// Zeroes every start/width/border width. Opposite edges share the raster
/// (a first run on an RQ25K showed Upper + Lower zones capped at 2400 in
/// total), so a zone left over from an earlier step skews the next ceiling.
Future<void> zeroZones() async {
  for (var i = 0; i < 4; i++) {
    await send(borderWidthReg(i).write(0));
    await send(startReg(i).write(0));
    await send(widthReg(i).write(0));
  }
}

Future<void> probeEdgeLimits() async {
  header('Phase 2a — Start / Width ceilings per edge (others zeroed)');
  for (var i = 0; i < 4; i++) {
    final start = startReg(i);
    final width = widthReg(i);
    stdout.writeln('\n${edges[i]}:');

    await zeroZones();
    final maxStart = await findCeiling(start);
    note('${edges[i]} start ceiling (width=0): $maxStart');
    if (maxStart != null && maxStart < searchCeiling) {
      note('${edges[i]} start overshoot: ${await overshoot(start, maxStart)}');
    }

    await send(start.write(0));
    final maxWidth = await findCeiling(width);
    note('${edges[i]} width ceiling (start=0): $maxWidth');
    if (maxWidth != null && maxWidth < searchCeiling) {
      note('${edges[i]} width overshoot: ${await overshoot(width, maxWidth)}');
    }

    // Does the projector enforce start + width <= max, and how?
    if (maxStart != null && maxWidth != null) {
      final s = maxStart ~/ 2;
      final ws = await send(start.write(s));
      final ww = await send(width.write(maxWidth));
      final rs = await readInt(start);
      final rw = await readInt(width);
      note(
        '${edges[i]} start=$s + width=$maxWidth → replies "$ws"/"$ww", '
        'read back start=$rs width=$rw',
      );
    }
  }

  header('Phase 2a\' — opposite edges share the raster?');
  // Pairs: (Upper, Lower), (Left, Right). Park a 1000-wide zone on one
  // edge, then measure the opposite edge's width ceiling.
  for (final (a, b) in [(0, 1), (2, 3)]) {
    await zeroZones();
    final wa = await send(widthReg(a).write(1000));
    final maxB = await findCeiling(widthReg(b));
    note('${edges[a]} width=1000 ("$wa") → ${edges[b]} width ceiling: $maxB');
    await send(startReg(a).write(200));
    final maxB2 = await findCeiling(widthReg(b));
    note(
      '${edges[a]} start=200 width=1000 → ${edges[b]} width ceiling: $maxB2',
    );
  }

  header('Phase 2b — Black border width ceilings');
  for (var i = 0; i < 4; i++) {
    final bw = borderWidthReg(i);
    final enable = Reg('${edges[i]} enable', enableKeys[i], Fmt.legacyBool);
    await zeroZones();

    // Edge disabled, no blend zone: the first run rejected every write here.
    final disabled = await send(bw.write(10));
    // Edge enabled with a blend zone — is the border bound to either?
    final en = await send(enable.write(1));
    final enabledNoZone = await send(bw.write(10));
    await send(widthReg(i).write(200));
    final max = await findCeiling(bw);
    note(
      '${edges[i]} border width=10: disabled → "$disabled", '
      'enabled ("$en") width=0 → "$enabledNoZone"; '
      'ceiling with width=200: $max',
    );
    if (max != null && max < searchCeiling) {
      note('${edges[i]} border width overshoot: ${await overshoot(bw, max)}');
    }

    // Border area adjust answered ER401 on 3 of 4 edges in Phase 1.
    if (max != null && max > 0) await send(bw.write(max));
    final area = await send(Reg('', areaKeys[i], Fmt.vxxInt).query);
    note('${edges[i]} ${areaKeys[i]} with edge enabled + border > 0: "$area"');
    await send(enable.write(0));
  }
}

// ── Phase 2: RGBW + Interlocked ──────────────────────────────────────────────
Future<void> probeRgbwRoundTrip() async {
  header('Phase 2c — RGBW tuples and Interlocked');
  const tuple = '010,020,030,040';

  for (final r in [
    nonOvReg,
    borderReg,
    Reg('Upper overlapped', overlapKeys[0], Fmt.vxxRgbw),
  ]) {
    final w = await send(r.write(tuple));
    final back = await send(r.query);
    note(
      '${r.label}: write $tuple → "$w", read back "$back" '
      '(${rgbwOf(back, r.key) == tuple ? 'round-trips' : 'DIFFERS'})',
    );
  }

  // Interlocked ON: does W drag R/G/B along, or are R/G/B ignored?
  for (final (lvl, il) in [
    (nonOvReg, nonOvIlReg),
    (borderReg, borderIlReg),
    (
      Reg('Upper overlapped', overlapKeys[0], Fmt.vxxRgbw),
      Reg('Upper overlapped interlocked', overlapIlKeys[0], Fmt.vxxInt),
    ),
  ]) {
    await send(il.write(1));
    final w = await send(lvl.write('050,010,020,030'));
    final back = await send(lvl.query);
    note(
      '${lvl.label} with interlocked ON: write 050,010,020,030 → "$w", '
      'read back "$back"',
    );
    await send(il.write(0));
    final back2 = await send(lvl.query);
    note('${lvl.label} after interlocked OFF: read back "$back2"');
  }
}

// ── Phase 2: behavior while Edge Blending is Off ─────────────────────────────
Future<void> probeWhileOff() async {
  header('Phase 2d — registers while EDBI0 = Off');
  // Zones zeroed first so a write rejected here can't be the shared-raster
  // cap instead of the mode.
  await zeroZones();
  await send(modeReg.write(0));
  final failing = <String>[];
  for (final r in allRegs.where((r) => r != modeReg)) {
    final reply = await send(r.query);
    if (isError(reply)) failing.add('${r.query}="$reply"');
  }
  note(
    failing.isEmpty
        ? 'all queries answer while Off'
        : 'queries failing while Off: ${failing.join(', ')}',
  );

  final start = Reg('Upper start', startKeys[0], Fmt.legacyInt4);
  final w = await send(start.write(10));
  note(
    'write VEU:0010 while Off → "$w", read back "${await send(start.query)}"',
  );
}

// ── Phase 2: Quad Pixel Drive on vs off ──────────────────────────────────────
/// Measures Upper/Left ceilings in both QPD states, and whether toggling QPD
/// rescales stored values. QPDI1 only answers while geometry mode (GMMI0) is
/// Off — see plan/QUAD_PIXEL_DRIVE_CORNER_LIMITS.md.
Future<void> probeQuadPixelDrive() async {
  header('Phase 2e — Quad Pixel Drive on vs off');
  const gmReg = Reg('Geometry mode', 'GMMI0', Fmt.vxxInt);
  const qpdReg = Reg('Quad Pixel Drive', 'QPDI1', Fmt.vxxInt);
  final gm = await send(gmReg.query);
  final qpd = await send(qpdReg.query);
  note('geometry mode "$gm", QPDI1 "$qpd"');
  final originalGm = intOf(gm, gmReg.key);
  if (originalGm == null) {
    note('GMMI0 unreadable — skipping QPD probe');
    return;
  }

  // Geometry values the app edits — compared after restoring GMMI0 to show
  // the Off round trip didn't lose them.
  const geometryKeys = [
    'GMFI1', 'GMFI2', 'GMFI3', 'GMFI4', 'GMFI5', 'GMFI6', 'GMFI7', 'GMFI8',
    'GMFI9', 'GMFIA', 'GMFIB', 'GMFIC', 'GMFID', 'GMFIE', 'GMFIF', //
    'GMKS0', 'GMKI4', 'GMKI7', 'GMKS8', 'GMKS9',
  ];
  Future<List<String>> geometrySnapshot() async => [
    for (final k in geometryKeys) await send('QVX:$k'),
  ];
  final geoBefore = await geometrySnapshot();

  if (originalGm != 0) {
    // QPDI1 answers ER401 while any geometry mode is active.
    final w = await send(gmReg.write(0));
    await Future<void>.delayed(const Duration(seconds: 2));
    note('GMMI0 → 0: "$w"');
  }
  final original = intOf(await send(qpdReg.query), qpdReg.key);
  if (original == null) {
    note('QPDI1 unreadable even with geometry Off');
    await restoreGeometry(gmReg, originalGm, geometrySnapshot, geoBefore);
    return;
  }
  note('QPDI1 with geometry Off: $original');
  try {
    for (final state in [original, 1 - original]) {
      if (state != original) {
        // Marker values: does the toggle rescale what's stored?
        await zeroZones();
        await send(widthReg(0).write(500));
        await send(widthReg(2).write(800));
        final w = await send(qpdReg.write(state));
        // QPD switching re-inits the video path; give it time.
        await Future<void>.delayed(const Duration(seconds: 3));
        note(
          'QPDI1 → $state: "$w", read back "${await send(qpdReg.query)}"; '
          'Upper width 500 → ${await readInt(widthReg(0))}, '
          'Left width 800 → ${await readInt(widthReg(2))}',
        );
      }
      await zeroZones();
      final us = await findCeiling(startReg(0));
      await zeroZones();
      final uw = await findCeiling(widthReg(0));
      await zeroZones();
      final ls = await findCeiling(startReg(2));
      await zeroZones();
      final lw = await findCeiling(widthReg(2));
      note(
        'QPD=$state: Upper start ≤ $us, width ≤ $uw; '
        'Left start ≤ $ls, width ≤ $lw',
      );
    }
  } finally {
    final w = await send(qpdReg.write(original));
    await Future<void>.delayed(const Duration(seconds: 3));
    note(
      'QPDI1 restored to $original: "$w", '
      'read back "${await send(qpdReg.query)}"',
    );
    // QPD first: Tier A refuses to enter a geometry mode while QPD is off.
    await restoreGeometry(gmReg, originalGm, geometrySnapshot, geoBefore);
  }
}

Future<void> restoreGeometry(
  Reg gmReg,
  int originalGm,
  Future<List<String>> Function() snapshot,
  List<String> before,
) async {
  if (originalGm != 0) {
    final w = await send(gmReg.write(originalGm));
    await Future<void>.delayed(const Duration(seconds: 2));
    note(
      'GMMI0 restored to $originalGm: "$w", '
      'read back "${await send(gmReg.query)}"',
    );
  }
  final after = await snapshot();
  final changed = [
    for (var i = 0; i < before.length; i++)
      if (before[i] != after[i]) '"${before[i]}" → "${after[i]}"',
  ];
  note(
    changed.isEmpty
        ? 'geometry values unchanged (${before.length} registers)'
        : 'geometry values CHANGED: ${changed.join(', ')}',
  );
}

// ── Restore ──────────────────────────────────────────────────────────────────
Future<void> restore(Map<Reg, String> snap) async {
  header('Restore');
  // Zones zeroed first: restoring one edge while the opposite one still holds
  // a probe-sized zone would hit the shared-raster cap (ER402).
  await zeroZones();
  // Mode last — some registers may only accept writes while blending is on.
  final order = [...snap.keys.where((r) => r != modeReg), modeReg];
  for (final r in order) {
    final reply = snap[r]!;
    final Object? value = r.isRgbw ? rgbwOf(reply, r.key) : intOf(reply, r.key);
    if (value == null) {
      stdout.writeln('  skip ${r.query}: original "$reply" not restorable');
      continue;
    }
    final w = await send(r.write(value));
    final ok = r.isRgbw
        ? rgbwOf(await send(r.query), r.key) == value
        : await readInt(r) == value;
    stdout.writeln(
      '  ${r.write(value).padRight(34)} → "$w" ${ok ? 'ok' : 'MISMATCH'}',
    );
    if (!ok) note('restore mismatch on ${r.query} (wanted $value)');
  }
}

// ── Main ─────────────────────────────────────────────────────────────────────
Future<void> main(List<String> args) async {
  if (args.isNotEmpty) ip = args[0];
  if (args.length > 1) login = args[1];
  if (args.length > 2) password = args[2];

  // Bail out before ~45 identical transport errors when the unit isn't there.
  final model = await send('QID');
  if (isError(model)) {
    stderr.writeln('$ip:$port unreachable or rejected auth: $model');
    exitCode = 1;
    return;
  }
  stdout.writeln('Model: $model');

  final snap = await snapshot();

  if (runWriteTests) {
    final originalMode = intOf(snap[modeReg]!, modeReg.key);
    if (originalMode == null) {
      stdout.writeln('\nEDBI0 unreadable — skipping write tests.');
    } else {
      try {
        await send(modeReg.write(1));
        if (probeLimits) await probeEdgeLimits();
        if (probeRgbw) await probeRgbwRoundTrip();
        if (probeModeOff) await probeWhileOff();
        if (probeQpd) await probeQuadPixelDrive();
      } finally {
        await restore(snap);
      }
    }
  } else {
    stdout.writeln('\n(write tests disabled — set runWriteTests = true)');
  }

  header('Findings (paste into plan/EDGE_BLENDING_PLAN.md → Live test)');
  if (findings.isEmpty) stdout.writeln('  none');
  for (final f in findings) {
    stdout.writeln('- $f');
  }
}
