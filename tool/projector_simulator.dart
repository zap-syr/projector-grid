// Loopback NTCONTROL projector simulator.
//
//   dart run tool/projector_simulator.dart [count] [--demo-errors]
//
// Starts [count] (default 6, max 250) fake projectors on 127.0.0.1,
// 127.0.0.2, … — each on the NTCONTROL port, unprotected (`NTCONTROL 0`) —
// and writes a project file with one card per projector laid out in a grid.
// Open that file in the app (File → Open) to exercise polling, controls and
// Alignment mode without real hardware. Ctrl+C stops the simulator.
//
// Each projector keeps its own state: power (with short warm-up/cool-down),
// shutter, input, test pattern and shutter fade times, and answers every
// query the app's poll cycle sends. Projector 2 starts with a 2.0 s fade-in
// so Alignment mode's fade zeroing and restore show up in the event log.
// Every command is printed as it arrives.
//
// Edge Blending / Black Level (the Edge Blending dialog): every register in
// its wire family, with the plan's §8 limits answered by ER402. Projector 1
// starts blended on Left/Right with non-zero black levels and border widths;
// the others start at the RQ25K factory values (mode Off, all levels 0).
//
// Geometry Correction (the Geometry Correction dialog): every Keystone,
// Curved and Corner register, the mode and Quad Pixel Drive, with their
// ranges answered by ER402. Projector 1 starts in Keystone (V +20, H +8),
// projector 2 in Curved Correction (arcs 30 / -20, throw ratio 0.8), the
// others with correction off.
//
// Self-diagnosis codes (QVX:ERRS2, see the panasonic-ntcontrol skill's
// Self-diagnosis codes) are set while it runs, by typing into its console:
//   err 3 F305 U200   projector 3 reports these codes
//   err all F011      every projector reports them
//   clear 3 | clear all
//   list              who reports what
// --demo-errors starts with a set that covers the app's Errors cell: a
// warning, a critical, five codes on one projector, an unknown code.
//
// The input signal (QVX:NSGS1), for the Signal lost alert:
//   sig 3 off | sig 3 on   cable out / back in on projector 3
//   sig all blip           a ~1 s pull: ~3.5 s without signal, like hardware
// While the signal is gone a powered-on projector answers ER401 for the
// first ~1.5 s (re-locking), then NSGS1=NO SIGNAL.
//
// The network link, for Offline cards:
//   net 3 off | net 3 on   network cable out / back in on projector 3
// While offline the listener is closed, so even the app's bare TCP
// reachability check fails, as with a pulled cable.
//
// Windows routes the whole 127.0.0.0/8 range to loopback out of the box;
// macOS only has 127.0.0.1 — add aliases first:
//   for i in $(seq 2 6); do sudo ifconfig lo0 alias 127.0.0.$i up; done
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ── Config ───────────────────────────────────────────────────────────────────
const int defaultCount = 6;
const int port = 1024;
const String model = 'PT-RQ35K2';
const int gridColumns = 3;
const Duration warmUp = Duration(seconds: 4);
const Duration coolDown = Duration(seconds: 2);

// Card grid matching WorkspaceNotifier.addProjectors (120×100 cards,
// 20 px horizontal / 40 px vertical gaps, origin 40,40).
const double _cardWidth = 120;
const double _cardHeight = 100;

class SimProjector {
  SimProjector(this.index)
    : fadeIn = index == 2 ? '2.0' : '0.0',
      serial = 'SIM${index.toString().padLeft(5, '0')}';

  final int index;
  final String serial;
  String get ip => '127.0.0.$index';

  // POWI1 codes: 1 standby, 2 turning on, 3 on, 4 cooling.
  int power = 3;
  String shutter = '0'; // 0 open, 1 closed
  String input = 'HD1';
  String pattern = '00';
  String fadeIn;
  String fadeOut = '0.0';

  /// Active self-diagnosis codes, sent space-separated after `ERRS2=`.
  List<String> errors = [];

  /// When the source signal went, or null while it is there.
  DateTime? signalLostAt;

  /// The NTCONTROL listener, null while the network cable is out.
  ServerSocket? server;
  bool get offline => server == null;

  Future<void> goOnline() async {
    if (server != null) return;
    server = await ServerSocket.bind(ip, port);
    server!.listen((socket) => _serve(socket, this));
  }

  Future<void> goOffline() async {
    final s = server;
    server = null;
    await s?.close();
  }

  void setSignal(bool present) =>
      signalLostAt = present ? null : (signalLostAt ?? DateTime.now());

  String get _signal {
    final lost = signalLostAt;
    if (power != 3) return 'ER401';
    if (lost == null) return 'NSGS1=1080/60p';
    return DateTime.now().difference(lost) < const Duration(milliseconds: 1500)
        ? 'ER401'
        : 'NSGS1=NO SIGNAL';
  }

  void _powerTo(int transitional, int target, Duration delay) {
    power = transitional;
    Timer(delay, () => power = target);
  }

  late final EdgeBlendSim edgeBlend = EdgeBlendSim(demo: index == 1);
  late final GeometrySim geometry = GeometrySim(index: index);

  String reply(String cmd) {
    final blend = edgeBlend.reply(cmd);
    if (blend != null) return blend;
    final geo = geometry.reply(cmd);
    if (geo != null) return geo;
    if (cmd == 'PON') {
      if (power == 1 || power == 4) _powerTo(2, 3, warmUp);
      return 'PON';
    }
    if (cmd == 'POF') {
      if (power == 3 || power == 2) _powerTo(4, 1, coolDown);
      return 'POF';
    }
    if (cmd.startsWith('OSH:')) return shutter = cmd.substring(4);
    if (cmd.startsWith('OTS:')) return pattern = cmd.substring(4);
    if (cmd.startsWith('IIS:')) return input = cmd.substring(4);
    if (cmd.startsWith('VXX:SEFS1=')) {
      return 'SEFS1=${fadeIn = cmd.substring(10)}';
    }
    if (cmd.startsWith('VXX:SEFS2=')) {
      return 'SEFS2=${fadeOut = cmd.substring(10)}';
    }
    return switch (cmd) {
      'QID' => model,
      'QSN' => serial,
      'QVX:POWI1' => 'POWI1=+0000$power',
      'QSH' => shutter,
      'QIN' => input,
      'QTS' => pattern,
      'QVX:NSGS1' => _signal,
      'QVX:RTMS1' => 'RTMS1=${1200 + index * 37}',
      'QVX:LRTS3=00' => 'LRTS3=00:${800 + index * 21}',
      'QTM:0' => '00${24 + index % 5}/0075',
      'QTM:1' => '00${38 + index % 7}/0100',
      'QVX:VMOI2' => 'VMOI2=+00230',
      'QVX:ERRS2' => 'ERRS2=${errors.join(' ')}',
      'QVX:SEFS1' => 'SEFS1=$fadeIn',
      'QVX:SEFS2' => 'SEFS2=$fadeOut',
      // Anything else (lens moves, picture settings, …) is acknowledged.
      _ => cmd.startsWith('Q') ? 'ER401' : cmd,
    };
  }
}

/// Edge Blending and Black Level registers of a 3840x2400 (Tier A) model,
/// in the three wire families and with the limits measured live
/// (plan/EDGE_BLENDING_PLAN.md §1, §8): a write that breaks one is refused
/// with ER402 and the value stays.
class EdgeBlendSim {
  EdgeBlendSim({required bool demo}) {
    if (!demo) return;
    // Projector 1: something to look at on both tabs, including an
    // Interlocked flag with unequal channels (set "elsewhere").
    vxx
      ..['EDBI0'] = 1
      ..['ELWI0'] = 600
      ..['ERWI0'] = 600
      ..['EBII2'] = 1
      ..['EBII3'] = 1;
    legacy
      ..['GL'] = 1
      ..['GR'] = 1
      ..['EL'] = 40
      ..['JL'] = 120
      ..['JB'] = 80;
    rgbw
      ..['JI'] = '010,012,014,016'
      ..['JO'] = '005,005,005,005'
      ..['EBBS0'] = '020,030,040,050'
      ..['EBBS2'] = '008,000,004,000'
      ..['EBBS3'] = '000,006,000,006';
  }

  static const int h = 3840;
  static const int v = 2400;

  static const _edges = [
    (start: 'EU', width: 'EUWI0', border: 'JU', opposite: 'EBWI0', span: v),
    (start: 'EB', width: 'EBWI0', border: 'JB', opposite: 'EUWI0', span: v),
    (start: 'EL', width: 'ELWI0', border: 'JL', opposite: 'ERWI0', span: h),
    (start: 'ER', width: 'ERWI0', border: 'JR', opposite: 'ELWI0', span: h),
  ];

  /// `VXX:KEY=+0000N` / `QVX:KEY` → `KEY=+0000N`. Widths default to the
  /// RQ25K's factory values.
  final vxx = <String, int>{
    'EDBI0': 0,
    'EATI1': 0,
    'EBMI1': 0,
    'EUWI0': 240,
    'EBWI0': 240,
    'ELWI0': 384,
    'ERWI0': 384,
    for (var i = 1; i <= 6; i++) 'EBII$i': 0,
  };

  /// `VEU:0010` / `QEU` → bare unpadded `10`.
  final legacy = <String, int>{
    for (final k in ['GU', 'GB', 'GL', 'GR', 'GM']) k: 0,
    for (final e in _edges) ...{e.start: 0, e.border: 0},
  };

  /// `VJI:W,R,G,B` / `QJI` → bare tuple; `EBBSn` goes through VXX and
  /// answers `EBBSn=W,R,G,B`.
  final rgbw = <String, String>{
    for (final k in ['JI', 'JO', 'EBBS0', 'EBBS1', 'EBBS2', 'EBBS3'])
      k: '000,000,000,000',
  };

  /// The reply, or null when [cmd] isn't an edge blending command.
  String? reply(String cmd) {
    if (cmd.startsWith('QVX:')) {
      final key = cmd.substring(4);
      if (vxx.containsKey(key)) return '$key=${_nt(vxx[key]!)}';
      if (rgbw.containsKey(key)) return '$key=${rgbw[key]}';
      return null;
    }
    if (cmd.startsWith('VXX:')) {
      final eq = cmd.indexOf('=');
      if (eq < 0) return null;
      final key = cmd.substring(4, eq);
      final value = cmd.substring(eq + 1);
      if (vxx.containsKey(key)) {
        final n = int.tryParse(value);
        if (n == null || !_write(vxx, key, n)) return 'ER402';
        return '$key=${_nt(n)}';
      }
      if (rgbw.containsKey(key)) {
        if (!_validTuple(value)) return 'ER402';
        rgbw[key] = value;
        return '$key=$value';
      }
      return null;
    }
    if (cmd.length == 3 && cmd.startsWith('Q')) {
      final key = cmd.substring(1);
      if (legacy.containsKey(key)) return '${legacy[key]}';
      if (rgbw.containsKey(key)) return rgbw[key];
      return null;
    }
    if (cmd.length > 4 && cmd.startsWith('V') && cmd[3] == ':') {
      final key = cmd.substring(1, 3);
      final value = cmd.substring(4);
      if (legacy.containsKey(key)) {
        final n = int.tryParse(value);
        if (n == null || !_write(legacy, key, n)) return 'ER402';
        return cmd;
      }
      if (rgbw.containsKey(key)) {
        if (!_validTuple(value)) return 'ER402';
        rgbw[key] = value;
        return cmd;
      }
    }
    return null;
  }

  /// Sets [key] if the whole state still fits the §8 rules, else keeps the
  /// old value.
  bool _write(Map<String, int> regs, String key, int n) {
    final old = regs[key]!;
    regs[key] = n;
    if (_valid()) return true;
    regs[key] = old;
    return false;
  }

  bool _valid() {
    bool flag(int x, [int max = 1]) => x >= 0 && x <= max;
    if (!flag(vxx['EDBI0']!, 2) ||
        !flag(vxx['EATI1']!) ||
        !flag(vxx['EBMI1']!) ||
        [for (var i = 1; i <= 6; i++) vxx['EBII$i']!].any((x) => !flag(x)) ||
        ['GU', 'GB', 'GL', 'GR', 'GM'].any((k) => !flag(legacy[k]!))) {
      return false;
    }
    for (final e in _edges) {
      final start = legacy[e.start]!;
      final width = vxx[e.width]!;
      final border = legacy[e.border]!;
      if (start < 0 || width < 0 || border < 0) return false;
      if (start + width > e.span) return false;
      if (width + vxx[e.opposite]! > e.span) return false;
      if (border + width > e.span) return false;
    }
    return true;
  }

  static bool _validTuple(String s) {
    final parts = s.split(',');
    return parts.length == 4 &&
        parts.every((p) {
          final n = int.tryParse(p);
          return p.length == 3 && n != null && n >= 0 && n <= 255;
        });
  }

  static String _nt(int n) =>
      '${n < 0 ? '-' : '+'}${n.abs().toString().padLeft(5, '0')}';
}

/// Geometry Correction registers (the Geometry Correction dialog) in the wire
/// formats a PT-RQ25K answers with: degrees and throw ratio as `+20.0` /
/// `+01.5`, the rest as `+00030`. A write echoes the command, a value out of
/// the register's range is refused with ER402. Like the hardware, Vertical
/// Keystone reads back up to ±40 even where the projector applies less.
class GeometrySim {
  GeometrySim({required int index}) {
    // Something for the preview to show on opening: projector 1 in Keystone,
    // projector 2 in Curved Correction.
    if (index == 1) {
      ints['QPDI1'] = 1;
      ints['GMMI0'] = 1;
      decimals['GMKS8'] = 20;
      decimals['GMKS9'] = 8;
    } else if (index == 2) {
      ints
        ..['QPDI1'] = 1
        ..['GMMI0'] = 2
        ..['GMCI3'] = 30
        ..['GMCI7'] = -20
        ..['GMCIA'] = 1;
      decimals['GMCS0'] = 0.8;
    }
  }

  /// Integer registers and their range. Corner limits are the Tier A
  /// inward reach (geometry_values.dart): 960 H, 600 V.
  static final _intRange = <String, (int, int)>{
    'GMMI0': (0, 10), // 0 off, 1 Keystone, 2 Curved, 10 Corner
    'QPDI1': (0, 1), // Quad Pixel Drive
    'GMKI4': (-60, 60),
    'GMKI7': (-30, 30),
    'GMCI2': (-60, 60),
    'GMCI3': (-40, 40),
    'GMCI6': (-30, 30),
    'GMCI7': (-40, 40),
    'GMCIA': (0, 1),
    for (final k in ['GMFI1', 'GMFI2', 'GMFI3', 'GMFI4']) k: (-600, 600),
    for (final k in ['GMFI6', 'GMFI7', 'GMFI8', 'GMFI9']) k: (-960, 960),
    'GMFI5': (-127, 127),
    'GMFIA': (-127, 127),
    for (final k in ['GMFIB', 'GMFIC', 'GMFID', 'GMFIE']) k: (-100, 100),
    'GMFIF': (0, 1),
  };

  static const _decimalRange = <String, (double, double)>{
    'GMKS0': (0.7, 16.5), // throw ratio
    'GMKS8': (-40, 40),
    'GMKS9': (-15, 15),
    'GMCS0': (0.7, 16.5),
    'GMCS8': (-40, 40),
    'GMCS9': (-15, 15),
  };

  final ints = {for (final k in _intRange.keys) k: 0};
  final decimals = <String, double>{
    for (final k in _decimalRange.keys) k: k.endsWith('S0') ? 1.5 : 0,
  };

  /// The reply, or null when [cmd] isn't a geometry command.
  String? reply(String cmd) {
    if (cmd.startsWith('QVX:')) {
      final key = cmd.substring(4);
      if (ints.containsKey(key)) return '$key=${_int(ints[key]!)}';
      if (decimals.containsKey(key)) return '$key=${_decimal(decimals[key]!)}';
      return null;
    }
    if (!cmd.startsWith('VXX:')) return null;
    final eq = cmd.indexOf('=');
    if (eq < 0) return null;
    final key = cmd.substring(4, eq);
    final value = cmd.substring(eq + 1);
    if (_intRange[key] case (final lo, final hi)) {
      final n = int.tryParse(value);
      if (n == null || n < lo || n > hi) return 'ER402';
      if (key == 'GMMI0' && ![0, 1, 2, 10].contains(n)) return 'ER402';
      ints[key] = n;
      return cmd;
    }
    if (_decimalRange[key] case (final lo, final hi)) {
      final d = double.tryParse(value);
      if (d == null || d < lo || d > hi) return 'ER402';
      decimals[key] = d;
      return cmd;
    }
    return null;
  }

  static String _int(int n) =>
      '${n < 0 ? '-' : '+'}${n.abs().toString().padLeft(5, '0')}';

  static String _decimal(double d) =>
      '${d < 0 ? '-' : '+'}${d.abs().toStringAsFixed(1).padLeft(4, '0')}';
}

/// What --demo-errors starts with, by projector number.
const Map<int, List<String>> demoErrors = {
  2: ['U200'], // a warning
  3: ['F011'], // a critical
  5: ['U201', 'F305', 'H001', 'F011', 'F306'], // more than fit the cell
  6: ['X912'], // not in the code table
};

Future<void> main(List<String> args) async {
  final numbers = args.where((a) => !a.startsWith('--'));
  final count = (numbers.isEmpty ? defaultCount : int.parse(numbers.first))
      .clamp(1, 250);
  final projectors = [for (var i = 1; i <= count; i++) SimProjector(i)];
  if (args.contains('--demo-errors')) {
    for (final e in demoErrors.entries) {
      if (e.key <= count) projectors[e.key - 1].errors = [...e.value];
    }
  }

  for (final p in projectors) {
    await p.goOnline();
  }

  final project = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'projector_simulator_$count.pgrid',
  );
  project.writeAsStringSync(jsonEncode(_projectJson(projectors)));

  stdout
    // ASCII only: the Windows console mangles ×, – and →.
    ..writeln('Simulating $count x $model on 127.0.0.1-$count, port $port.')
    ..writeln('Open in the app: ${project.path}')
    ..writeln('Type "help" for console commands. Ctrl+C to stop.\n');
  _listErrors(projectors);

  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => _command(line.trim(), projectors));
}

const _help = '''
  err <n|all> <codes...>   set self-diagnosis codes, e.g. err 3 F305 U200
  clear <n|all>            remove them
  list                     who reports what
  sig <n|all> off|on|blip  input signal gone, back, or gone for ~3.5 s
  net <n|all> off|on       network link down (no replies) or back''';

Future<void> _command(String line, List<SimProjector> projectors) async {
  final parts = line.split(RegExp(r'\s+'));
  if (line.isEmpty) return;
  if (parts.first == 'list') {
    _listErrors(projectors);
    return _listOffline(projectors);
  }
  if (parts.first == 'help' || parts.length < 2) return stdout.writeln(_help);

  final List<SimProjector> targets;
  if (parts[1] == 'all') {
    targets = projectors;
  } else {
    final n = int.tryParse(parts[1]);
    if (n == null || n < 1 || n > projectors.length) {
      return stdout.writeln(
        'No projector ${parts[1]} (1-${projectors.length}).',
      );
    }
    targets = [projectors[n - 1]];
  }

  switch (parts.first) {
    case 'err' when parts.length > 2:
      final codes = [for (final c in parts.skip(2)) c.toUpperCase()];
      for (final p in targets) {
        p.errors = codes;
      }
    case 'clear':
      for (final p in targets) {
        p.errors = [];
      }
    case 'sig' when parts.length > 2:
      final how = parts[2];
      if (how != 'off' && how != 'on' && how != 'blip') {
        return stdout.writeln(_help);
      }
      for (final p in targets) {
        p.setSignal(how == 'on');
        if (how == 'blip') {
          Timer(const Duration(milliseconds: 3500), () => p.setSignal(true));
        }
      }
      return stdout.writeln(
        '${parts[1] == 'all' ? 'All projectors' : targets.single.ip}: '
        'signal $how.',
      );
    case 'net' when parts.length > 2:
      final how = parts[2];
      if (how != 'off' && how != 'on') return stdout.writeln(_help);
      await Future.wait([
        for (final p in targets) how == 'off' ? p.goOffline() : p.goOnline(),
      ]);
      return _listOffline(projectors);
    default:
      return stdout.writeln(_help);
  }
  _listErrors(projectors);
}

void _listErrors(List<SimProjector> projectors) {
  final faulty = projectors.where((p) => p.errors.isNotEmpty).toList();
  if (faulty.isEmpty) {
    stdout.writeln('No projector reports errors.');
    return;
  }
  for (final p in faulty) {
    stdout.writeln('${p.ip}  ERRS2=${p.errors.join(' ')}');
  }
  stdout.writeln('The app picks these up on its next poll.');
}

void _listOffline(List<SimProjector> projectors) {
  final down = [for (final p in projectors.where((p) => p.offline)) p.ip];
  stdout.writeln(
    down.isEmpty ? 'All projectors online.' : 'Offline: ${down.join(', ')}',
  );
}

void _serve(Socket socket, SimProjector p) {
  // The app's reachability check connects and resets at once; on macOS the
  // greeting then fails with ECONNRESET, which would kill the simulator.
  socket.done.catchError((_) {});
  socket.add(ascii.encode('NTCONTROL 0\r'));
  final buffer = StringBuffer();
  socket.listen((data) {
    buffer.write(ascii.decode(data));
    final content = buffer.toString();
    final end = content.indexOf('\r');
    if (end < 0) return;
    // Unprotected mode: the command arrives with a bare `00` header.
    final cmd = content.substring(0, end).replaceFirst(RegExp('^00'), '');
    final reply = p.reply(cmd);
    // Queries are left out: the poll cycle would drown the actual commands.
    if (!cmd.startsWith('Q')) stdout.writeln('${p.ip}  $cmd -> $reply');
    socket.add(ascii.encode('00$reply\r'));
    unawaited(socket.flush().then((_) => socket.close()).catchError((_) {}));
  }, onError: (_) {});
}

Map<String, dynamic> _projectJson(List<SimProjector> projectors) => {
  'version': 2,
  'groups': [],
  'nodes': [
    for (final p in projectors)
      {
        'id': 'sim-${p.index}',
        'name': model,
        'ipAddress': p.ip,
        'port': port,
        'login': '',
        'password': '',
        'x': 40 + ((p.index - 1) % gridColumns) * (_cardWidth + 20),
        'y': 40 + ((p.index - 1) ~/ gridColumns) * (_cardHeight + 40),
      },
  ],
  'scheduledTasks': [],
};
