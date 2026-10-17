import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/dialog_parts.dart';

void main() {
  Future<Offset> textLeft(WidgetTester tester, {required bool loading}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: SentRightAwayNote(loading: loading)),
      ),
    );
    return tester.getTopLeft(find.byType(Text));
  }

  testWidgets('the text stays put when loading ends', (tester) async {
    final loading = await textLeft(tester, loading: true);
    final loaded = await textLeft(tester, loading: false);
    expect(loaded, loading);
  });
}
