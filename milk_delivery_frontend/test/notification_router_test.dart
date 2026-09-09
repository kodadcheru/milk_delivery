import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/notification_model.dart';
import 'package:milk_delivery_frontend/models/live_order_model.dart';
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

      expect(find.text('Farm Fresh Paneer'), findsWidgets);
    });

    testWidgets('Order notification deep-links to specific order and shows details', (tester) async {
      final testOrder = LiveOrderModel(
        id: 'MD-8899',
        items: [],
        totalAmount: 180.0,
        status: 'PREPARING',
        deliveryDate: '2026-09-10',
        deliverySlot: '06:00 AM - 08:00 AM',
        deliveryAddress: 'Flat 401, Kodad',
        customerName: 'Test User',
        customerPhone: '+919876543210',
        createdAt: 'Today',
      );
      state.liveOrders = [testOrder];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final notif = NotificationModel(
                    id: 105,
                    title: '⚡ Express Order MD-8899 Confirmed!',
                    message: 'Your order is scheduled for tomorrow 06:00 AM',
                    notificationType: 'DELIVERY',
                    targetScreen: 'DELIVERIES',
                    targetParam: 'MD-8899',
                    isRead: false,
                    createdAt: 'Today',
                  );
                  NotificationRouter.navigate(context, notif, state);
                },
                child: const Text('Test Order Notif'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(state.currentTabIndex, 3);
      expect(find.textContaining('MD-8899'), findsWidgets);
    });
  });
}
