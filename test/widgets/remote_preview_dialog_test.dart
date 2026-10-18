import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/services/projector_web_status_service.dart';
import 'package:projector_grid/core/services/remote_preview_service.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/preview_signal_status_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/remote_preview_provider.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/dialog_parts.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/preview_viewport.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/remote_preview_dialog.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/test_config_dir.dart';

/// A 1×1 PNG: a frame the plane can decode.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// The projector's socket, without a socket: starts in [initial] per host.
class _FakePreview extends RemotePreview {
  static final initial = <String, RemotePreviewState>{};

  @override
  RemotePreviewState build(String host) =>
      initial[host] ?? const RemotePreviewConnecting();

  void emit(RemotePreviewState s) => state = s;

  @override
  void retry() {}

  @override
  void setPreshow(bool on) {}
}

class _WebStatus extends PreviewSignalStatus {
  static WebSignalStatus? value;

  @override
  WebSignalStatus? build(String host, String login, String password) => value;
}

ProjectorNode _node(
  int last, {
  PowerStatus power = PowerStatus.on,
  ShutterStatus shutter = ShutterStatus.open,
  ConnectionStatus status = ConnectionStatus.connected,
  String? groupId,
}) => ProjectorNode(
  id: '$last',
  name: 'RQ25K',
  ipAddress: '192.168.0.$last',
  x: 0,
  y: 0,
  powerStatus: power,
  shutterStatus: shutter,
  connectionStatus: status,
  groupId: groupId,
);

void main() {
  useTempConfigDir();

  late FakeProtocolService fake;

  setUp(() {
    fake = FakeProtocolService();
    _FakePreview.initial.clear();
    _WebStatus.value = null;
  });

  late ProviderContainer container;

  Future<void> pumpDialog(
    WidgetTester tester,
    List<ProjectorNode> nodes, {
    Size size = const Size(1600, 1000),
    Map<String, ProjectorGroup> groups = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          protocolServiceProvider.overrideWithValue(fake),
          remotePreviewProvider.overrideWith2((_) => _FakePreview()),
          previewSignalStatusProvider.overrideWith2((_) => _WebStatus()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showRemotePreviewDialog(context, nodes, groups: groups),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.text('open')));
    // Kept alive from here, as the app's canvas does: an auto-dispose
    // workspace read only once would be rebuilt empty.
    container.listen(workspaceProvider, (_, _) {});
    container.read(workspaceProvider.notifier).setNodes(nodes);
    await tester.tap(find.text('open'));
    // The connecting spinner never settles, so no pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> emit(
    WidgetTester tester,
    String ip,
    RemotePreviewState s,
  ) async {
    (container.read(remotePreviewProvider(ip).notifier) as _FakePreview).emit(
      s,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // The Dialog's own Material: the Dialog widget spans its insets.
  Finder dialogBox() => find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first;

  Finder plane() => find.byKey(const ValueKey('preview-plane'));
  Finder preShowCard() => find.byKey(const ValueKey('pre-show-card'));

  ({Rect dialog, Rect plane, Rect card, Rect footer}) layout(
    WidgetTester tester,
  ) => (
    dialog: tester.getRect(dialogBox()),
    plane: tester.getRect(plane().first),
    card: tester.getRect(preShowCard()),
    footer: tester.getRect(find.byType(DialogFooter)),
  );

  group('one projector', () {
    testWidgets('title bar names the projector, footer has the legend', (
      tester,
    ) async {
      await pumpDialog(tester, [_node(41)]);
      expect(find.text('Remote Preview'), findsOneWidget);
      expect(find.text('RQ25K (192.168.0.41)'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(
        find.text('Live from the projector, about 1 frame a second'),
        findsOneWidget,
      );
      expect(find.text('Shutter open'), findsOneWidget);
      expect(find.text('Shutter closed'), findsOneWidget);
      expect(find.text('Not on'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('plane, Pre-show card and footer stay put across states', (
      tester,
    ) async {
      await pumpDialog(tester, [_node(41, power: PowerStatus.standby)]);
      final connecting = layout(tester);

      _WebStatus.value = const WebSignalStatus(
        input: 'HDMI1',
        signalName: '3840x2160/60p',
        signalFrequency: '134.99kHz/59.99Hz',
      );
      container.invalidate(previewSignalStatusProvider);
      await emit(tester, '192.168.0.41', RemotePreviewFrame(_png));
      expect(
        find.text('HDMI1: 3840x2160/60p (134.99 kHz, 59.99 Hz)'),
        findsOneWidget,
      );
      final live = layout(tester);

      await emit(
        tester,
        '192.168.0.41',
        const RemotePreviewNotice(RemotePreviewNoticeKind.noSignal),
      );
      expect(find.text('No signal'), findsOneWidget);
      final notice = layout(tester);

      await emit(tester, '192.168.0.41', const RemotePreviewUnavailable());
      expect(find.text('Preview not available'), findsOneWidget);
      expect(
        find.text("The projector's web page did not answer."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      final unavailable = layout(tester);

      for (final other in [live, notice, unavailable]) {
        expect(other, connecting);
      }
    });

    testWidgets('Pre-show subtitles follow power and the feed', (tester) async {
      await pumpDialog(tester, [_node(41, power: PowerStatus.standby)]);
      // Standby, the feed still connecting.
      expect(find.text('Connecting to the live feed'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      // Standby, no feed.
      await emit(tester, '192.168.0.41', const RemotePreviewUnavailable());
      expect(find.text('Needs the live feed and Standby'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      await emit(tester, '192.168.0.41', RemotePreviewFrame(_png));
      expect(
        find.text(
          'Keeps the input alive for preview, the projector stays off. '
          'Stays on after you close this window.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    });

    testWidgets('Pre-show is disabled while the projector is on', (
      tester,
    ) async {
      await pumpDialog(tester, [_node(41)]);
      await emit(tester, '192.168.0.41', RemotePreviewFrame(_png));
      expect(
        find.text('Only in Standby: this projector is on'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      // A one-line subtitle: the text is centred on the icon tile.
      final text = tester.getCenter(
        find.byKey(const ValueKey('pre-show-text')),
      );
      final icon = tester.getCenter(
        find.descendant(
          of: preShowCard(),
          matching: find.byIcon(Icons.visibility_outlined),
        ),
      );
      expect(text.dy, closeTo(icon.dy, 0.5));
    });

    testWidgets('pre-show on: PRE-SHOW tag, switch on, snackbar on close', (
      tester,
    ) async {
      fake.rawResponses['QVX:PSMI1'] = 'PSMI1=+00001';
      await pumpDialog(tester, [_node(41, power: PowerStatus.standby)]);
      final before = layout(tester);
      await emit(tester, '192.168.0.41', RemotePreviewFrame(_png));
      expect(find.text('PRE-SHOW'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(layout(tester), before);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(
        find.text('Pre-show stays active on the projector'),
        findsOneWidget,
      );
    });

    testWidgets('fits an 800x600 window without overflow', (tester) async {
      await pumpDialog(tester, [_node(41)], size: const Size(800, 600));
      await emit(tester, '192.168.0.41', const RemotePreviewUnavailable());
      expect(tester.takeException(), isNull);
      final dialog = tester.getSize(dialogBox());
      expect(dialog.width, lessThanOrEqualTo(720));
      expect(dialog.height, lessThanOrEqualTo(600));
      // The plane keeps 16:9 in the room left.
      final p = tester.getSize(plane());
      expect(p.width / p.height, closeTo(16 / 9, 0.01));
    });

    testWidgets('at its largest the dialog is capped at 720x600', (
      tester,
    ) async {
      await pumpDialog(tester, [_node(41)]);
      final dialog = tester.getSize(dialogBox());
      expect(dialog.width, 720);
      expect(dialog.height, lessThanOrEqualTo(600));
    });
  });

  group('several projectors', () {
    const groups = {
      'g': ProjectorGroup(id: 'g', name: 'Main stage', color: 0xFF3B82F6),
    };
    List<ProjectorNode> eight() => [
      for (var i = 41; i <= 48; i++)
        _node(
          i,
          groupId: i < 44 ? 'g' : null,
          status: i >= 47
              ? ConnectionStatus.offline
              : ConnectionStatus.connected,
        ),
    ];

    testWidgets('title bar: count, IP range and online badge', (tester) async {
      await pumpDialog(tester, eight(), groups: groups);
      expect(find.text('Remote Preview'), findsOneWidget);
      expect(find.text('8 projectors (192.168.0.41 to .48)'), findsOneWidget);
      expect(find.text('6 of 8 online'), findsOneWidget);
      // Captions: model and IP, no `·`.
      expect(find.text('192.168.0.41'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
      expect(
        find.textContaining('In Standby with a live feed: 0 of 8 projectors.'),
        findsOneWidget,
      );
    });

    testWidgets('tiles are 300 wide at most, three columns', (tester) async {
      await pumpDialog(tester, eight(), groups: groups);
      final tiles = find.byType(PreviewViewport);
      final first = tester.getRect(tiles.at(0));
      final second = tester.getRect(tiles.at(1));
      expect(first.width, lessThanOrEqualTo(300));
      expect(second.left - first.right, 8);
      expect(tester.getSize(dialogBox()).width, lessThanOrEqualTo(980));
    });

    testWidgets('grid and Pre-show card stay put across states', (
      tester,
    ) async {
      await pumpDialog(tester, eight(), groups: groups);
      final before = layout(tester);
      await emit(tester, '192.168.0.41', RemotePreviewFrame(_png));
      await emit(
        tester,
        '192.168.0.42',
        const RemotePreviewNotice(RemotePreviewNoticeKind.noSignal),
      );
      await emit(tester, '192.168.0.43', const RemotePreviewUnavailable());
      expect(layout(tester), before);
    });

    testWidgets('fits an 800x600 window without overflow', (tester) async {
      await pumpDialog(
        tester,
        eight(),
        groups: groups,
        size: const Size(800, 600),
      );
      await emit(tester, '192.168.0.41', const RemotePreviewUnavailable());
      expect(tester.takeException(), isNull);
      final dialog = tester.getSize(dialogBox());
      expect(dialog.width, lessThanOrEqualTo(980));
      expect(dialog.height, lessThanOrEqualTo(600));
    });
  });
}
