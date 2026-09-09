import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/product_model.dart';
import 'package:milk_delivery_frontend/models/subscription_model.dart';
import 'package:milk_delivery_frontend/providers/app_state.dart';
import 'package:milk_delivery_frontend/widgets/subscriptions/subscription_card.dart';

void main() {
  group('Subscription Pause and Resume Tests', () {
    late AppState state;
    late ProductModel product;
    late SubscriptionModel activeSub;

    setUp(() {
      state = AppState();
      product = ProductModel(
        id: 1,
        name: 'Farm Fresh Cow Milk',
        category: 'MILK',
        description: 'Farm fresh pure milk',
        unit: 'Litre',
        unitQuantity: '1 Litre',
        pricePerUnit: 68.0,
        imageUrl: '',
        isAvailable: true,
      );

      activeSub = SubscriptionModel(
        id: 42,
        customerId: 1,
        productId: 1,
        productDetail: product,
        quantity: 2,
        packSize: '1 Litre',
        scheduleType: 'DAILY',
        deliverySlot: '06:00 AM - 08:00 AM',
        status: 'ACTIVE',
        startDate: '2026-09-01',
      );

      state.subscriptions = [activeSub];
    });

    testWidgets('Active subscription displays Pause Delivery button and opens confirmation dialog', (tester) async {
      bool toggleInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionCard(
              state: state,
              sub: activeSub,
              isTelugu: false,
              onTogglePauseRequested: (ctx, s, isTe) async {
                toggleInvoked = true;
              },
            ),
          ),
        ),
      );

      // Verify Active badge and Pause button exist
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Pause Delivery'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap Pause button
      await tester.tap(find.text('Pause Delivery'));
      await tester.pumpAndSettle();

      expect(toggleInvoked, isTrue);
    });

    testWidgets('Paused subscription displays Resume Delivery button and resumes on tap', (tester) async {
      final pausedSub = activeSub.copyWith(status: 'PAUSED');
      bool toggleInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionCard(
              state: state,
              sub: pausedSub,
              isTelugu: false,
              onTogglePauseRequested: (ctx, s, isTe) async {
                toggleInvoked = true;
              },
            ),
          ),
        ),
      );

      // Verify Paused badge and Resume button exist
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Resume Delivery'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap Resume button
      await tester.tap(find.text('Resume Delivery'));
      await tester.pumpAndSettle();

      expect(toggleInvoked, isTrue);
    });

    testWidgets('Pause confirmation dialog renders with appropriate actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscriptionCard(
              state: state,
              sub: activeSub,
              isTelugu: false,
            ),
          ),
        ),
      );

      // Tap Pause button to open built-in dialog
      await tester.tap(find.text('Pause Delivery'));
      await tester.pumpAndSettle();

      // Verify Dialog text and action buttons
      expect(find.text('Pause Subscription?'), findsOneWidget);
      expect(find.text('Keep Active'), findsOneWidget);
      expect(find.text('Pause Delivery'), findsNWidgets(2)); // On card + inside dialog

      // Tap Keep Active (Cancel)
      await tester.tap(find.text('Keep Active'));
      await tester.pumpAndSettle();

      // Dialog is dismissed, active card remains
      expect(find.text('Pause Subscription?'), findsNothing);
      expect(find.text('ACTIVE'), findsOneWidget);
    });
  });
}
