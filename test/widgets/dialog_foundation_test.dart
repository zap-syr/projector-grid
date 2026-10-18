import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/domain/projector_group.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/providers/workspace_provider.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/confirm_dialog.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/status_pill.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/custom_tooltip.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/dialog_title_bar.dart';

import 'package:projector_grid/features/workspace/presentation/providers/protocol_service_provider.dart';

import '../helpers/fake_protocol_service.dart';
import '../helpers/provider_harness.dart';
import '../helpers/test_config_dir.dart';

Widget _app(Widget child) => ProviderScope(
  overrides: [protocolServiceProvider.overrideWithValue(FakeProtocolService())],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: Center(child: child)),
  ),
);

/// Pumps [bar] and seeds the workspace through the scope's own container,
/// which goes (with its polling timers) when the tree is torn down.
Future<WorkspaceNotifier> _pumpWithNodes(
  WidgetTester tester,
  Widget bar,
  List<ProjectorNode> nodes, {
  List<ProjectorGroup> groups = const [],
}) async {
  await tester.pumpWidget(_app(SizedBox(width: 700, child: bar)));
  final notifier = ProviderScope.containerOf(
    tester.element(find.byType(DialogTitleBar)),
  ).read(workspaceProvider.notifier);
  notifier.setGroups(groups);
  notifier.setNodes(nodes);
  await tester.pump();
  return notifier;
}

void main() {
  useTempConfigDir();

  group('DialogTitleBar', () {
    testWidgets('renders icon, title and close', (tester) async {
      await tester.pumpWidget(
        _app(const DialogTitleBar(icon: Icons.layers, title: 'Groups')),
      );
      expect(find.byIcon(Icons.layers), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('with a projector: model + IP, group pill, live status', (
      tester,
    ) async {
      final notifier = await _pumpWithNodes(
        tester,
        const DialogTitleBar(
          icon: Icons.palette_outlined,
          title: 'Color Correction',
          projectorId: '1',
        ),
        [
          node('1', ip: '192.168.0.41', groupId: 'g'),
          node('2', ip: '192.168.0.42'),
        ],
        groups: const [
          ProjectorGroup(
            id: 'g',
            name: 'Left wall',
            color: 0xFF3B82F6,
            oscAddress: '/group/left-wall',
          ),
        ],
      );
      expect(find.text('Proj 1 (192.168.0.41)'), findsOneWidget);
      expect(find.text('Left wall'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);

      notifier.setNodes([
        node(
          '1',
          ip: '192.168.0.41',
          groupId: 'g',
          status: ConnectionStatus.offline,
        ),
        node('2', ip: '192.168.0.42'),
      ]);
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('the pills sit against ✕, not mid-bar', (tester) async {
      await _pumpWithNodes(
        tester,
        const DialogTitleBar(
          icon: Icons.palette_outlined,
          title: 'Color Correction',
          projectorId: '1',
        ),
        [node('1', ip: '192.168.0.41', groupId: 'g')],
        groups: const [
          ProjectorGroup(
            id: 'g',
            name: 'Left wall',
            color: 0xFF3B82F6,
            oscAddress: '/group/left-wall',
          ),
        ],
      );
      final badge = tester.getRect(find.byType(ConnectionStatusBadge));
      final close = tester.getRect(find.byIcon(Icons.close));
      final pill = tester.getRect(find.byType(GroupPill));
      // Badge, then 4 px and the 40 px ✕ button around its 20 px icon.
      expect(close.left - badge.right, lessThanOrEqualTo(4 + 10 + 0.5));
      expect(badge.left - pill.right, 8);
    });

    testWidgets('no group pill for an ungrouped projector', (tester) async {
      await _pumpWithNodes(
        tester,
        const DialogTitleBar(
          icon: Icons.crop_free,
          title: 'Geometry Correction',
          projectorId: '2',
        ),
        [node('2', ip: '192.168.0.42', status: ConnectionStatus.unauthorized)],
      );
      expect(find.text('Proj 2 (192.168.0.42)'), findsOneWidget);
      expect(find.text('Wrong login'), findsOneWidget);
      expect(find.byType(GroupPill), findsNothing);
    });

    group('a pair', () {
      const leftWall = ProjectorGroup(
        id: 'g',
        name: 'Left wall',
        color: 0xFF3B82F6,
        oscAddress: '/group/left-wall',
      );
      const bar = DialogTitleBar(
        icon: Icons.gradient,
        title: 'Edge Blending',
        pairIds: ('1', '2'),
        badges: [Text('B not replying')],
      );

      testWidgets('both projectors, the shared group and the given badge', (
        tester,
      ) async {
        await _pumpWithNodes(
          tester,
          bar,
          [
            node('1', ip: '192.168.0.41', groupId: 'g'),
            node('2', ip: '192.168.0.42', groupId: 'g'),
          ],
          groups: const [leftWall],
        );
        expect(
          find.text('Pair: Proj 1 (192.168.0.41), Proj 2 (192.168.0.42)'),
          findsOneWidget,
        );
        expect(find.text('Left wall'), findsOneWidget);
        expect(find.text('B not replying'), findsOneWidget);
        // The pair's status is the dialog's, not a connection badge.
        expect(find.byType(ConnectionStatusBadge), findsNothing);
      });

      testWidgets('no group pill when the two are in different groups', (
        tester,
      ) async {
        await _pumpWithNodes(
          tester,
          bar,
          [
            node('1', ip: '192.168.0.41', groupId: 'g'),
            node('2', ip: '192.168.0.42'),
          ],
          groups: const [leftWall],
        );
        expect(find.byType(GroupPill), findsNothing);
      });
    });
  });

  group('ConfirmDialog', () {
    Future<bool?> open(WidgetTester tester, String tap) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmDestructive(
                context,
                title: 'Delete “Left wall”?',
                subtitle: 'The group is removed from this project.',
                confirmLabel: 'Delete group',
                changes: const [
                  ConfirmChange(
                    icon: Icons.sensors,
                    lead: '/group/left-wall',
                    rest: 'no longer answers',
                    monoLead: true,
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('What changes'), findsOneWidget);
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm returns true', (tester) async {
      expect(await open(tester, 'Delete group'), isTrue);
    });

    testWidgets('cancel returns false', (tester) async {
      expect(await open(tester, 'Cancel'), isFalse);
    });
  });

  group('CustomTooltip', () {
    Future<void> hover(WidgetTester tester, Widget tooltip) async {
      await tester.pumpWidget(_app(tooltip));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('anchor')));
      await tester.pump();
    }

    testWidgets('title, detail, shortcut and warning render', (tester) async {
      await hover(
        tester,
        const CustomTooltip(
          message: 'Enter Alignment mode',
          detail: 'Step through the projectors one by one',
          shortcut: ['Ctrl', 'L'],
          warning: true,
          child: Text('anchor'),
        ),
      );
      expect(find.text('Enter Alignment mode'), findsOneWidget);
      expect(find.text('Step through the projectors one by one'), findsOne);
      expect(find.text('Ctrl'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    for (final placement in TooltipPlacement.values) {
      testWidgets('arrow follows the placement: ${placement.name}', (
        tester,
      ) async {
        await hover(
          tester,
          CustomTooltip(
            message: 'Tip',
            placement: placement,
            child: const Text('anchor'),
          ),
        );
        final anchor = tester.getRect(find.text('anchor'));
        final bubble = tester.getRect(find.byType(TooltipBubble));
        final arrow = tester.getRect(
          find
              .descendant(
                of: find.byType(CustomMultiChildLayout),
                matching: find.byType(CustomPaint),
              )
              .last,
        );
        if (placement == TooltipPlacement.top) {
          expect(bubble.bottom, lessThanOrEqualTo(arrow.top));
          expect(arrow.bottom, lessThan(anchor.top));
        } else {
          expect(arrow.top, greaterThan(anchor.bottom));
          expect(bubble.top, greaterThanOrEqualTo(arrow.bottom));
        }
        expect(arrow.center.dx, closeTo(anchor.center.dx, 0.5));
      });
    }
  });
}
