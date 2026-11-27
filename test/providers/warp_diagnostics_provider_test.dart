import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/app_log_file.dart';
import 'package:projector_grid/features/workspace/domain/log_event.dart';
import 'package:projector_grid/features/workspace/domain/warp_codec.dart';
import 'package:projector_grid/features/workspace/presentation/providers/event_log_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/warp_diagnostics_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

const _id = '1';
const _ip = '10.0.0.1';

// A row whose table format the app does not understand.
const _mids = 'MIDS1=0024:00:30';

/// One call of the fake save dialog.
typedef _DialogCall = ({
  String title,
  String defaultName,
  String filterLabel,
  String extension,
  String? initialDirectory,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final configDir = useTempConfigDir();

  late FakeProtocolService fake;
  late List<_DialogCall> dialogCalls;
  late FutureOr<String?> Function() onDialog;
  late List<WarpDiagnosticsState> states;

  setUp(() {
    fake = FakeProtocolService()..rawResponses['QVX:MIDS1'] = _mids;
    fake.warpFor(_ip);
    fake.warpFor(_ip).setBlock(0x72, Uint8List.fromList([1, 2, 3, 4, 5]));
    dialogCalls = [];
    onDialog = () => '${configDir().path}${Platform.pathSeparator}out.txt';
    states = [];
  });

  ProviderContainer newContainer() {
    final c = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(fake),
        warpDiagnosticsAppVersionProvider.overrideWith(
          (ref) async => '2.0.1+13',
        ),
        warpDiagnosticsSaveDialogProvider.overrideWithValue(({
          required title,
          required defaultName,
          required filterLabel,
          required extension,
          initialDirectory,
        }) async {
          dialogCalls.add((
            title: title,
            defaultName: defaultName,
            filterLabel: filterLabel,
            extension: extension,
            initialDirectory: initialDirectory,
          ));
          return onDialog();
        }),
      ],
    );
    addTearDown(c.dispose);
    c.read(workspaceProvider.notifier).setNodes([node(_id)]);
    return c;
  }

  // The provider is not keepAlive: a listener keeps it for the test.
  ProviderSubscription<WarpDiagnosticsState> keep(ProviderContainer c) =>
      c.listen(
        warpDiagnosticsProvider(_id),
        (_, next) => states.add(next),
        fireImmediately: true,
      );

  WarpDiagnostics notifier(ProviderContainer c) =>
      c.read(warpDiagnosticsProvider(_id).notifier);

  WarpDiagnosticsState stateOf(ProviderContainer c) =>
      c.read(warpDiagnosticsProvider(_id));

  List<LogEvent> logRows(ProviderContainer c) => c.read(eventLogProvider);

  bool isBusy(ProviderContainer c) =>
      c.read(workspaceProvider.notifier).isNodeBusy(_id);

  String outPath() => '${configDir().path}${Platform.pathSeparator}out.txt';

  test('starts idle and sends nothing on its own', () async {
    final c = newContainer();
    keep(c);
    await pumpEventQueue();

    expect(stateOf(c), isA<WarpDiagnosticsIdle>());
    expect(fake.sentRaw, isEmpty);
    expect(fake.sentBinary, isEmpty);
    expect(dialogCalls, isEmpty);
  });

  group('save', () {
    test('reads, asks for the path and writes the file there', () async {
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      final s = stateOf(c);
      expect(s, isA<WarpDiagnosticsSaved>());
      expect((s as WarpDiagnosticsSaved).path, outPath());
      expect(s.fileName, 'out.txt');
      expect(states.map((e) => e.runtimeType), [
        WarpDiagnosticsIdle,
        WarpDiagnosticsReading,
        WarpDiagnosticsSaved,
      ]);

      final text = File(outPath()).readAsStringSync();
      expect(text, startsWith('Projector Grid free grid diagnostics\n'));
      expect(text, contains('App version: 2.0.1+13'));
      expect(text, contains('Projector: Proj 1 (10.0.0.1), port 1024'));
      expect(text, contains('Model id (QVX:MIDS1): $_mids'));
      expect(text, contains('READ type 0x72: block of 5 bytes'));
      expect(text, contains('[PC-3]'));
      expect(File('${outPath()}.tmp').existsSync(), isFalse);
    });

    test('opens the dialog in the logs folder with the default name', () async {
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      expect(dialogCalls, hasLength(1));
      final call = dialogCalls.single;
      expect(call.title, 'Save diagnostics');
      expect(call.filterLabel, 'Text file');
      expect(call.extension, 'txt');
      expect(call.initialDirectory, logsFolderPath);
      expect(Directory(logsFolderPath).existsSync(), isTrue);
      expect(
        call.defaultName,
        matches(
          r'^warp-diagnostics-Proj-1-10\.0\.0\.1-\d{4}-\d{2}-\d{2}\.txt$',
        ),
      );
    });

    test('adds .txt when the chosen name has no extension', () async {
      onDialog = () => '${configDir().path}${Platform.pathSeparator}report';
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      final s = stateOf(c) as WarpDiagnosticsSaved;
      expect(s.fileName, 'report.txt');
      expect(File(s.path).existsSync(), isTrue);
    });

    test('keeps a chosen name that ends in .TXT as it is', () async {
      onDialog = () => '${configDir().path}${Platform.pathSeparator}R.TXT';
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      expect((stateOf(c) as WarpDiagnosticsSaved).fileName, 'R.TXT');
    });

    test('claims the projector while reading and gives it back', () async {
      final hold = Completer<void>();
      fake.holdBinary[_ip] = hold;
      final c = newContainer();
      keep(c);
      final workspace = c.read(workspaceProvider.notifier);

      final done = notifier(c).save();
      await pumpEventQueue();

      expect(stateOf(c), isA<WarpDiagnosticsReading>());
      expect(isBusy(c), isTrue);
      expect(workspace.claimNodeForExternalPoll(_id), isFalse);
      expect(dialogCalls, isEmpty, reason: 'the read is not over yet');

      hold.complete();
      await done;

      expect(stateOf(c), isA<WarpDiagnosticsSaved>());
      expect(isBusy(c), isFalse);
      expect(workspace.claimNodeForExternalPoll(_id), isTrue);
      workspace.releaseNodeFromExternalPoll(_id);
    });

    test('has given the projector back before the dialog opens', () async {
      final c = newContainer();
      keep(c);
      bool? busyInDialog;
      onDialog = () {
        busyInDialog = isBusy(c);
        return outPath();
      };

      await notifier(c).save();

      expect(busyInDialog, isFalse);
    });

    test('a second save while one runs does not start another read', () async {
      final hold = Completer<void>();
      fake.holdBinary[_ip] = hold;
      final c = newContainer();
      keep(c);

      final first = notifier(c).save();
      await pumpEventQueue();
      final second = notifier(c).save();
      hold.complete();
      await Future.wait([first, second]);

      expect(fake.sentRaw.where((e) => e.$2 == 'QVX:MIDS1'), hasLength(1));
      expect(dialogCalls, hasLength(1));
    });

    test(
      'only reads: no write, SAVE, VXX command, preview or overlay',
      () async {
        final c = newContainer();
        keep(c);

        await notifier(c).save();

        expect(fake.sentBinary, isNotEmpty);
        for (final (_, frame) in fake.sentBinary) {
          expect(frame[2], 0xA8, reason: warpBytesToHex(frame));
        }
        expect(fake.warpFor(_ip).saves, isEmpty);
        expect(fake.sentCommands, isEmpty);
        expect(fake.sentRaw, isNotEmpty);
        expect(fake.sentRaw.map((e) => e.$2), everyElement(startsWith('QVX:')));
      },
    );

    test('logs a success row', () async {
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      final row = logRows(c).single;
      expect(row.severity, LogSeverity.success);
      expect(row.message, 'Free grid diagnostics saved to out.txt');
      expect(row.projectorIp, _ip);
      expect(row.projectorName, 'Proj 1');
      expect(row.nodeId, _id);
    });
  });

  group('cancel', () {
    test('goes back to idle, writes nothing, logs nothing', () async {
      onDialog = () => null;
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      expect(stateOf(c), isA<WarpDiagnosticsIdle>());
      expect(states.map((e) => e.runtimeType), [
        WarpDiagnosticsIdle,
        WarpDiagnosticsReading,
        WarpDiagnosticsIdle,
      ]);
      expect(dialogCalls, hasLength(1));
      final written = configDir()
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.contains('warp-diagnostics') ||
                f.path.endsWith('out.txt'),
          );
      expect(written, isEmpty);
      expect(logRows(c), isEmpty);
      expect(isBusy(c), isFalse);
    });

    test('can be started again after a cancel', () async {
      onDialog = () => null;
      final c = newContainer();
      keep(c);
      await notifier(c).save();
      onDialog = outPath;

      await notifier(c).save();

      expect(stateOf(c), isA<WarpDiagnosticsSaved>());
      expect(File(outPath()).existsSync(), isTrue);
    });
  });

  group('failure', () {
    test(
      'a busy projector fails with the session message, sends nothing',
      () async {
        final c = newContainer();
        keep(c);
        final workspace = c.read(workspaceProvider.notifier);
        expect(workspace.claimNodeForExternalPoll(_id), isTrue);

        fakeAsync((async) {
          final done = notifier(c).save();
          async.elapse(const Duration(seconds: 2));
          expect(stateOf(c), isA<WarpDiagnosticsReading>());
          async.elapse(const Duration(seconds: 2));
          unawaited(done);
          final s = stateOf(c);
          expect(s, isA<WarpDiagnosticsFailed>());
          expect(
            (s as WarpDiagnosticsFailed).message,
            'Projector busy, try again',
          );
        });

        expect(fake.sentRaw, isEmpty);
        expect(fake.sentBinary, isEmpty);
        expect(dialogCalls, isEmpty);
        final row = logRows(c).single;
        expect(row.severity, LogSeverity.error);
        expect(
          row.message,
          'Free grid diagnostics failed: Projector busy, try again',
        );
        // The claim is still the other caller's.
        expect(isBusy(c), isTrue);
        workspace.releaseNodeFromExternalPoll(_id);
      },
    );

    test('a save dialog that throws is a failure, claim released', () async {
      onDialog = () => throw const FileSystemException('no dialog');
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      final s = stateOf(c) as WarpDiagnosticsFailed;
      expect(s.message, contains('no dialog'));
      expect(isBusy(c), isFalse);
      final row = logRows(c).single;
      expect(row.severity, LogSeverity.error);
      expect(row.message, startsWith('Free grid diagnostics failed: '));
    });

    test('a file that cannot be written is a failure', () async {
      // A folder cannot be made below a file.
      final blocker = File(
        '${configDir().path}${Platform.pathSeparator}blocker',
      )..writeAsStringSync('x');
      onDialog = () => '${blocker.path}${Platform.pathSeparator}out.txt';
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      expect(stateOf(c), isA<WarpDiagnosticsFailed>());
      expect(logRows(c).single.severity, LogSeverity.error);
      expect(isBusy(c), isFalse);
    });

    test(
      'an app version that cannot be read is a failure, nothing is sent',
      () async {
        final c = ProviderContainer(
          overrides: [
            protocolServiceProvider.overrideWithValue(fake),
            warpDiagnosticsAppVersionProvider.overrideWith(
              (ref) async => throw StateError('no package info'),
            ),
          ],
        );
        addTearDown(c.dispose);
        c.read(workspaceProvider.notifier).setNodes([node(_id)]);
        keep(c);

        await notifier(c).save();

        expect(
          (stateOf(c) as WarpDiagnosticsFailed).message,
          contains('no package info'),
        );
        expect(fake.sentRaw, isEmpty);
      },
    );

    test('a projector that does not answer still gives a report', () async {
      fake.rawResponses['QVX:MIDS1'] = null;
      final c = newContainer();
      keep(c);

      await notifier(c).save();

      expect(stateOf(c), isA<WarpDiagnosticsSaved>());
      final text = File(outPath()).readAsStringSync();
      expect(text, contains('Model id (QVX:MIDS1): no reply'));
      expect(text, contains('READ: skipped, '));
      expect(fake.sentBinary, isEmpty);
    });

    test('a retry after a failure works', () async {
      onDialog = () => throw StateError('first');
      final c = newContainer();
      keep(c);
      await notifier(c).save();
      expect(stateOf(c), isA<WarpDiagnosticsFailed>());
      onDialog = outPath;

      await notifier(c).save();

      expect(stateOf(c), isA<WarpDiagnosticsSaved>());
    });
  });

  test(
    'a provider that ends mid-read gives the claim back and writes nothing',
    () async {
      final hold = Completer<void>();
      fake.holdBinary[_ip] = hold;
      final c = newContainer();
      final sub = keep(c);
      final done = notifier(c).save();
      await pumpEventQueue();
      expect(isBusy(c), isTrue);

      sub.close();
      await c.pump();
      hold.complete();
      await done;

      expect(isBusy(c), isFalse);
      expect(dialogCalls, isEmpty);
      expect(File(outPath()).existsSync(), isFalse);
    },
  );
}
