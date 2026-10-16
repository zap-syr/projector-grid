import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:projector_grid/core/services/external_links.dart';
import 'package:projector_grid/core/theme/app_theme.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/about_dialog.dart';

void main() {
  final opened = <String>[];

  setUp(() {
    opened.clear();
    debugOpenInBrowserOverride = opened.add;
    PackageInfo.setMockInitialValues(
      appName: 'Projector Grid',
      packageName: 'projector_grid',
      version: '1.4.2',
      buildNumber: '11',
      buildSignature: '',
    );
  });
  tearDown(() => debugOpenInBrowserOverride = null);

  /// Opens About from a button, as the menus do, in the minimum window.
  Future<void> pumpAbout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AppAboutDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows version and build, lays out at 800x600', (tester) async {
    await pumpAbout(tester);
    expect(find.text('Projector Grid'), findsOneWidget);
    expect(find.text('Version 1.4.2 (build 11)'), findsOneWidget);
    expect(find.text("What's new in 1.4.2"), findsOneWidget);
    expect(find.text('© 2025–2026 Aleksei Vlasov'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each external link opens its page from the hint', (
    tester,
  ) async {
    await pumpAbout(tester);
    for (final hint in [
      'Release notes',
      'github.com/zap-syr',
      'GitHub issues',
      'gumroad.com',
    ]) {
      await tester.tap(find.text(hint));
      await tester.pump();
    }
    expect(opened, [
      'https://github.com/zap-syr/projector-grid/releases/tag/v1.4.2',
      'https://github.com/zap-syr/projector-grid',
      'https://github.com/zap-syr/projector-grid/issues/new',
      'https://projectorhub.gumroad.com/l/projectorgrid',
    ]);
  });

  testWidgets('row labels are not links', (tester) async {
    await pumpAbout(tester);
    await tester.tap(find.text('Project page'), warnIfMissed: false);
    await tester.pump();
    expect(opened, isEmpty);
  });

  testWidgets('the chevron opens the license page', (tester) async {
    await pumpAbout(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.byType(AppAboutDialog), findsNothing);
    expect(opened, isEmpty);
  });
}
