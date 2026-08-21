import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/notification_model.dart';
import 'package:milk_delivery_frontend/models/user_model.dart';
import 'package:milk_delivery_frontend/providers/app_state.dart';
import 'package:milk_delivery_frontend/services/notification_router.dart';

void main() {
  group('NotificationRouter Tests', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.currentUser = UserModel(
        id: 1,
        username: 'testuser',
        firstName: 'Test',
        lastName: 'User',
        phone: '+919876543210',
        email: 'test@example.com',
        address: 'Flat 401, Kodad, Telangana',
        city: 'Kodad',
        role: 'CUSTOMER',
        walletBalance: 250.0,
        deliveryInstructions: 'Ring doorbell twice',
      );
    });

    testWidgets('Delivery notification marks read and sets tab to Orders/Deliveries (tab 3)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final notif = NotificationModel(
                    id: 101,
                    title: 'Milk Dispatched 🥛',
                    message: 'Your morning drop is out for delivery',
                    notificationType: 'DELIVERY',
                    targetScreen: 'DELIVERIES',
                    isRead: false,
                    createdAt: 'Today',
                  );
                  NotificationRouter.navigate(context, notif, state);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(state.currentTabIndex, 3);
    });

    testWidgets('Wallet notification marks read and sets tab to Wallet (tab 2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final notif = NotificationModel(
                    id: 102,
                    title: 'Cashback Credited 🎉',
                    message: '₹50 credited to your wallet balance',
                    notificationType: 'WALLET',
                    targetScreen: 'WALLET',
                    isRead: false,
                    createdAt: 'Today',
                  );
                  NotificationRouter.navigate(context, notif, state);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(state.currentTabIndex, 2);
    });

    testWidgets('Subscription & Vacation notification sets tab to Subs (tab 1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final notif = NotificationModel(
                    id: 103,
                    title: 'Subscription Paused ⏸️',
                    message: 'Vacation mode active until Monday',
                    notificationType: 'VACATION',
                    targetScreen: 'SUBSCRIPTIONS',
                    isRead: false,
                    createdAt: 'Today',
                  );
                  NotificationRouter.navigate(context, notif, state);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(state.currentTabIndex, 1);
    });

    testWidgets('Category offer notification pushes CategoryProductsScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final notif = NotificationModel(
                    id: 104,
                    title: 'Fresh Paneer Special Discount 🧀',
                    message: 'Get 20% off on malai soft paneer today',
                    notificationType: 'OFFER',
                    targetScreen: 'CATEGORY',
                    targetParam: 'PANEER',
                    isRead: false,
                    createdAt: 'Today',
                  );
                  NotificationRouter.navigate(context, notif, state);
                },
                child: const Text('Test'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Screen pushed on top of navigator
      expect(find.text('Farm Fresh Paneer'), findsWidgets);
    });
  });
}
