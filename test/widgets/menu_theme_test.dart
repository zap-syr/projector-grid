import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';

void main() {
  testWidgets('a submenu opens beside its parent menu, not over it', (
    tester,
  ) async {
    final controller = MenuController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MenuAnchor(
              controller: controller,
              menuChildren: [
                SubmenuButton(
                  key: const ValueKey('parent-item'),
                  alignmentOffset: AppTheme.submenuOffset,
                  menuChildren: [
                    MenuItemButton(
                      key: const ValueKey('child-item'),
                      onPressed: () {},
                      child: const Text('Child'),
                    ),
                  ],
                  child: const Text('Open Recent'),
                ),
                MenuItemButton(onPressed: () {}, child: const Text('Save')),
              ],
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      ),
    );
    controller.open();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parent-item')));
    await tester.pumpAndSettle();

    // The menus' panels (the radius 12 Material around the items): the
    // parent's holds Save, the submenu's holds Child.
    Rect panelOf(Finder item) => tester.getRect(
      find
          .ancestor(
            of: item,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Material &&
                  w.shape is RoundedRectangleBorder &&
                  (w.shape! as RoundedRectangleBorder).borderRadius ==
                      BorderRadius.circular(12),
            ),
          )
          .first,
    );
    final parent = panelOf(find.text('Save'));
    final child = panelOf(find.byKey(const ValueKey('child-item')));
    expect(child.left, greaterThanOrEqualTo(parent.right));
  });
}
