import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/projector_card.dart';

void main() {
  late List<String> invoked;

  Future<void> pumpCard(WidgetTester tester, {bool hasGroup = true}) async {
    invoked = [];
    VoidCallback record(String name) =>
        () => invoked.add(name);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ProjectorCard(
                  node: const ProjectorNode(
                    id: '1',
                    name: 'PT-RQ25K',
                    ipAddress: '10.0.0.1',
                    x: 40,
                    y: 40,
                  ),
                  dragOverrides: ValueNotifier(const {}),
                  zoom: 1,
                  onTap: record('tap'),
                  onPanDown: (_) {},
                  onPanUpdate: (_) {},
                  onPanEnd: (_) {},
                  onEdit: record('edit'),
                  onDelete: record('delete'),
                  onColorCorrection: record('color'),
                  onBrightnessControl: record('brightness'),
                  onGeometryCorrection: record('geometry'),
                  onRemotePreview: record('preview'),
                  onSelectGroup: hasGroup ? record('selectGroup') : null,
                  buildGroupMenuItems: () => [
                    MenuItemButton(
                      onPressed: record('assign'),
                      child: const Text('Stage'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('PT-RQ25K'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  const items = [
    'Edit',
    'Brightness Control',
    'Color Correction',
    'Geometry Correction',
    'Remote Preview',
    'Open in Browser',
    'Select in Group',
    'Assign to Group',
    'Delete',
  ];

  testWidgets('right-click shows every menu item', (tester) async {
    await pumpCard(tester);
    await openMenu(tester);
    for (final label in items) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  const wiring = {
    'Edit': 'edit',
    'Brightness Control': 'brightness',
    'Color Correction': 'color',
    'Geometry Correction': 'geometry',
    'Remote Preview': 'preview',
    'Select in Group': 'selectGroup',
    'Delete': 'delete',
  };
  for (final MapEntry(key: label, value: callback) in wiring.entries) {
    testWidgets('"$label" runs its callback and closes the menu', (
      tester,
    ) async {
      await pumpCard(tester);
      await openMenu(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(invoked, [callback]);
      expect(find.text('Edit'), findsNothing);
    });
  }

  testWidgets('Assign to Group opens the group submenu', (tester) async {
    await pumpCard(tester);
    await openMenu(tester);
    await tester.tap(find.text('Assign to Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stage'));
    await tester.pumpAndSettle();
    expect(invoked, ['assign']);
  });

  testWidgets('Select in Group is disabled without a group', (tester) async {
    await pumpCard(tester, hasGroup: false);
    await openMenu(tester);
    final button = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Select in Group'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
