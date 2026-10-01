import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/projector_web_status_service.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/preview_signal_status_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/remote_preview_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/web_preview_feeds.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

/// The projector's socket, without a socket.
class _FakePreview extends RemotePreview {
  static final opened = <String>[];
  static final closed = <String>[];
  static final retried = <String>[];

  @override
  RemotePreviewState build(String host) {
    opened.add(host);
    ref.onDispose(() => closed.add(host));
    return const RemotePreviewConnecting();
  }

  void emit(RemotePreviewState s) => state = s;

  @override
  void retry() => retried.add(host);
}

class _NoWebStatus extends PreviewSignalStatus {
  @override
  WebSignalStatus? build(String host, String login, String password) => null;
}

final _feedsProvider = Provider(
  (ref) => WebPreviewFeeds(
    ref,
    onHeartbeat: (_) => true,
    grace: const Duration(milliseconds: 50),
  ),
);

/// One page's preview stream, parsed back into (event, data) pairs.
class _Page {
  _Page(Stream<List<int>> stream) {
    _sub = stream.map(utf8.decode).listen((chunk) {
      final lines = chunk.split('\n');
      final name = lines.where((l) => l.startsWith('event: ')).firstOrNull;
      final data = lines.where((l) => l.startsWith('data: ')).firstOrNull;
      if (name == null || data == null) return;
      events.add((name.substring(7), jsonDecode(data.substring(6))));
    });
  }

  late final StreamSubscription<String> _sub;
  final events = <(String, Object?)>[];

  List<Object?> of(String name) => [
    for (final (n, d) in events)
      if (n == name) d,
  ];

  Future<void> leave() => _sub.cancel();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTempConfigDir();

  late FakeProtocolService fake;
  late ProviderContainer c;

  setUp(() {
    _FakePreview.opened.clear();
    _FakePreview.closed.clear();
    _FakePreview.retried.clear();
    fake = FakeProtocolService();
    c = ProviderContainer(
      overrides: [
        protocolServiceProvider.overrideWithValue(fake),
        remotePreviewProvider.overrideWith2((_) => _FakePreview()),
        previewSignalStatusProvider.overrideWith2((_) => _NoWebStatus()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(workspaceProvider, (_, _) {});
    c.read(workspaceProvider.notifier).setNodes([
      node('1').copyWith(input: 'HDMI1', signal: '1080/60p'),
      node('2').copyWith(powerStatus: PowerStatus.standby),
    ]);
  });

  WebPreviewFeeds feeds() => c.read(_feedsProvider);
  _FakePreview preview(String ip) =>
      c.read(remotePreviewProvider(ip).notifier) as _FakePreview;
  Future<void> settle() => pumpEventQueue();

  test('a page gets the status, then each new frame once', () async {
    final page = _Page(feeds().subscribe('t', '1')!);
    await settle();
    expect(page.of('status'), [
      {
        'state': 'connecting',
        'notice': null,
        'overlay': null,
        'signal': 'HDMI1 · 1080/60p',
        'preShow': null,
        'preShowApplying': false,
      },
    ]);

    final jpeg = Uint8List.fromList([1, 2, 3]);
    preview('10.0.0.1').emit(RemotePreviewFrame(jpeg));
    // The same image re-sent with a tag: a new status, no new frame.
    preview(
      '10.0.0.1',
    ).emit(RemotePreviewFrame(jpeg, overlay: RemotePreviewOverlay.testPattern));
    await settle();
    expect(page.of('frame'), [
      {'jpeg': base64Encode(jpeg)},
    ]);
    expect(
      [for (final s in page.of('status')) (s as Map)['overlay']],
      [null, null, 'testPattern'],
    );
    expect((page.of('status').last as Map)['state'], 'live');
    await page.leave();
  });

  test('pages share one feed; it closes a grace period after the last '
      'leaves', () async {
    final a = _Page(feeds().subscribe('t1', '1')!);
    preview('10.0.0.1').emit(RemotePreviewFrame(Uint8List.fromList([9])));
    await settle();
    // A late page starts from the current status and image.
    final b = _Page(feeds().subscribe('t2', '1')!);
    await settle();
    expect(_FakePreview.opened, ['10.0.0.1']);
    expect((b.of('status').single as Map)['state'], 'live');
    expect(b.of('frame'), hasLength(1));

    await a.leave();
    await b.leave();
    await settle();
    expect(feeds().isOpen('1'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await settle();
    expect(feeds().isOpen('1'), isFalse);
    expect(_FakePreview.closed, ['10.0.0.1']);
  });

  test('coming back within the grace period keeps the feed', () async {
    await _Page(feeds().subscribe('t', '1')!).leave();
    await settle();
    final again = _Page(feeds().subscribe('t', '1')!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(_FakePreview.opened, ['10.0.0.1']);
    expect(_FakePreview.closed, isEmpty);
    await again.leave();
  });

  test('an unknown projector has no feed', () {
    expect(feeds().subscribe('t', 'zz'), isNull);
  });

  test('a projector in Standby reads its pre-show', () async {
    fake.rawResponses['QVX:PSMI1'] = 'PSMI1=+00001';
    final page = _Page(feeds().subscribe('t', '2')!);
    await settle();
    expect((page.of('status').last as Map)['preShow'], isTrue);
    expect(fake.sentRaw, contains(('10.0.0.2', 'QVX:PSMI1')));
    await page.leave();
  });
}
