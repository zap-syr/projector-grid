import 'package:flutter_test/flutter_test.dart';
import 'package:projectors_manager/app/app.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Panasonic Projectors Manager'), findsNothing); // Will be nothing because title is not rendered in a widget, but the app should load
  });
}
