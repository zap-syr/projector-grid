import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/app/app.dart';

import 'helpers/test_config_dir.dart';

void main() {
  // Otherwise the app loads (and may rewrite) the real user's settings.
  useTempConfigDir();

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    expect(
      find.text('Projector Grid'),
      findsNothing,
    ); // title is not rendered as a widget
  });
}
