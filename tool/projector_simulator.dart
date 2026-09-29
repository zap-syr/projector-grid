// Loopback NTCONTROL projector simulator.
//
//   dart run tool/projector_simulator.dart [count]
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

  void _powerTo(int transitional, int target, Duration delay) {
    power = transitional;
    Timer(delay, () => power = target);
  }

  String reply(String cmd) {
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
    final on = power == 3;
    return switch (cmd) {
      'QID' => model,
      'QSN' => serial,
      'QVX:POWI1' => 'POWI1=+0000$power',
      'QSH' => shutter,
      'QIN' => input,
      'QTS' => pattern,
      'QVX:NSGS1' => on ? 'NSGS1=1080/60p' : 'ER401',
      'QVX:RTMS1' => 'RTMS1=${1200 + index * 37}',
      'QVX:LRTS3=00' => 'LRTS3=00:${800 + index * 21}',
      'QTM:0' => '00${24 + index % 5}/0075',
      'QTM:1' => '00${38 + index % 7}/0100',
      'QVX:VMOI2' => 'VMOI2=+00230',
      'QVX:ERRS2' => 'ERRS2=',
      'QVX:SEFS1' => 'SEFS1=$fadeIn',
      'QVX:SEFS2' => 'SEFS2=$fadeOut',
      // Anything else (lens moves, picture settings, …) is acknowledged.
      _ => cmd.startsWith('Q') ? 'ER401' : cmd,
    };
  }
}

Future<void> main(List<String> args) async {
  final count = (args.isEmpty ? defaultCount : int.parse(args.first)).clamp(
    1,
    250,
  );
  final projectors = [for (var i = 1; i <= count; i++) SimProjector(i)];

  for (final p in projectors) {
    final server = await ServerSocket.bind(p.ip, port);
    server.listen((socket) => _serve(socket, p));
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
    ..writeln('Ctrl+C to stop.\n');
}

void _serve(Socket socket, SimProjector p) {
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
    unawaited(socket.flush().then((_) => socket.close()));
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
