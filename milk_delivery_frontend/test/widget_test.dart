import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/main.dart';

void main() {
  testWidgets('App boots with MilkDrop branding smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MilkDeliveryApp());
    expect(find.byType(MilkDeliveryApp), findsOneWidget);
  });
}
