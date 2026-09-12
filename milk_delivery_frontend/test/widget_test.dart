import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/main.dart';

void main() {
  testWidgets('App boots with Pamba branding smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PambaApp());
    expect(find.byType(PambaApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
