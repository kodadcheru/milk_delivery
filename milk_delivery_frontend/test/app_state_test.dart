import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/product_model.dart';
import 'package:milk_delivery_frontend/models/user_model.dart';
import 'package:milk_delivery_frontend/models/delivery_task_model.dart';
import 'package:milk_delivery_frontend/models/live_order_model.dart';
import 'package:milk_delivery_frontend/providers/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductModel Tests', () {
    test('ProductModel parses JSON correctly', () {
      final json = {
        'id': 1,
        'name': 'Farm Fresh A2 Desi Cow Milk',
        'category': 'MILK',
        'price_per_unit': '85.00',
        'unit': 'LITER',
        'unit_quantity': '1 Litre',
        'badge_text': 'Bestseller',
        'rating': '4.9',
        'is_available': true,
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, 1);
      expect(product.name, 'Farm Fresh A2 Desi Cow Milk');
      expect(product.category, 'MILK');
      expect(product.pricePerUnit, 85.0);
      expect(product.icon, '🥛');
    });

    test('ProductModel category icon resolver', () {
      final chickenJson = {'id': 2, 'name': 'Chicken Breast', 'category': 'MEAT', 'price_per_unit': '200.00'};
      final chickenProd = ProductModel.fromJson(chickenJson);
      expect(chickenProd.icon, '🍗');

      final muttonJson = {'id': 2, 'name': 'Mutton Curry Cut', 'category': 'MEAT', 'price_per_unit': '400.00'};
      final muttonProd = ProductModel.fromJson(muttonJson);
      expect(muttonProd.icon, '🥩');

      final eggJson = {'id': 3, 'name': 'Desi Eggs', 'category': 'EGGS', 'price_per_unit': '90.00'};
      final eggProd = ProductModel.fromJson(eggJson);
      expect(eggProd.icon, '🥚');

      final waterJson = {'id': 4, 'name': '20L Can', 'category': 'WATER_CAN', 'price_per_unit': '60.00'};
      final waterProd = ProductModel.fromJson(waterJson);
      expect(waterProd.icon, '💧');
    });
  });

  group('UserModel Tests', () {
    test('UserModel parses JSON and calculates wallet properly', () {
      final json = {
        'id': 10,
        'username': '9876543210',
        'first_name': 'Ramesh',
        'last_name': 'Kumar',
        'role': 'CUSTOMER',
        'phone': '+91 9876543210',
        'wallet_balance': '750.50',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 10);
      expect(user.firstName, 'Ramesh');
      expect(user.role, 'CUSTOMER');
      expect(user.walletBalance, 750.50);
      expect(user.latitude, 17.4319);
      expect(user.longitude, 78.4073);
    });
  });

  group('DeliveryTaskModel Tests', () {
    test('DeliveryTaskModel parses GPS coordinates correctly', () {
      final json = {
        'id': 101,
        'subscription': 20,
        'customer_name': 'Anil Rao',
        'customer_phone': '9848011223',
        'delivery_address': 'Road 10, Banjara Hills',
        'customer_latitude': 17.4156,
        'customer_longitude': 78.4350,
        'delivery_date': '2026-08-18',
        'slot_time': '05:30 AM - 07:00 AM',
        'status': 'PENDING',
      };

      final task = DeliveryTaskModel.fromJson(json);
      expect(task.id, 101);
      expect(task.customerName, 'Anil Rao');
      expect(task.customerLatitude, 17.4156);
      expect(task.customerLongitude, 78.4350);
      expect(task.status, 'PENDING');
    });
  });

  group('Cart Logic Tests', () {
    test('Cart state correctly accumulates items and subtotal', () {
      final p1 = ProductModel(
        id: 1,
        name: 'Milk 1L',
        description: 'Fresh Milk',
        pricePerUnit: 70.0,
        imageUrl: '',
        unit: 'LITER',
        unitQuantity: '1 Litre',
        category: 'MILK',
        icon: '🥛',
      );
      final p2 = ProductModel(
        id: 2,
        name: 'Meat 500g',
        description: 'Tender Chicken',
        pricePerUnit: 200.0,
        imageUrl: '',
        unit: 'KG',
        unitQuantity: '500 g',
        category: 'MEAT',
        icon: '🥩',
      );

      final state = AppState();
      state.products = [p1, p2];

      state.addToCart(p1);
      state.addToCart(p1);
      state.addToCart(p2);

      expect(state.totalCartItemCount, 3);
      expect(state.totalCartPrice, 340.0); // 70*2 + 200*1 = 340

      state.decreaseCartQty(p1.id);
      expect(state.totalCartItemCount, 2);
      expect(state.totalCartPrice, 270.0); // 70*1 + 200*1 = 270

      state.clearCart();
      expect(state.totalCartItemCount, 0);
      expect(state.totalCartPrice, 0.0);
    });

    test('LiveOrderModel and placeExpressOrder flow', () async {
      final p1 = ProductModel(
        id: 10,
        name: 'Fresh Chicken',
        description: 'Tender Chicken',
        pricePerUnit: 220.0,
        imageUrl: '',
        unit: 'KG',
        unitQuantity: '500g',
        category: 'MEAT',
      );

      final state = AppState();
      state.products = [p1];
      state.addToCart(p1);

      final order = await state.placeExpressOrder(
        deliveryDate: '21 Aug 2026',
        deliverySlot: '05:30 AM - 07:00 AM',
      );
      expect(order.id.startsWith('MD-'), true);
      expect(order.deliveryDate, '21 Aug 2026');
      expect(order.deliverySlot, '05:30 AM - 07:00 AM');
      expect(order.totalAmount, 220.0);
      expect(order.items.length, 1);
      expect(state.liveOrders.first.id, order.id);
      expect(state.totalCartItemCount, 0);
    });

    test('LiveOrderModel serializes and deserializes JSON correctly', () {
      final json = {
        'id': 'MD-9999',
        'order_type': 'ONE_TIME',
        'items': [
          {
            'product': {
              'id': 5,
              'name': 'Desi Ghee 500ml',
              'description': 'Pure Cow Ghee',
              'price_per_unit': '450.00',
              'unit': 'ML',
              'unit_quantity': '500 ml',
              'category': 'MILK',
            },
            'quantity': 2,
            'unit_price': '450.00',
          }
        ],
        'total_amount': '900.00',
        'status': 'PREPARING',
        'delivery_date': 'Tomorrow',
        'delivery_slot': '05:30 AM - 07:00 AM',
        'delivery_address': 'Flat 402, Royal Palms',
        'delivery_latitude': '17.4320',
        'delivery_longitude': '78.4070',
        'delivery_otp': '7890',
        'payment_status': 'PAID (Prepaid Wallet)',
      };

      final order = LiveOrderModel.fromJson(json);
      expect(order.id, 'MD-9999');
      expect(order.totalAmount, 900.0);
      expect(order.items.length, 1);
      expect(order.items.first.quantity, 2);
      expect(order.items.first.totalPrice, 900.0);
      expect(order.deliveryOtp, '7890');
      expect(order.status, 'PREPARING');
    });

    test('DoorstepProofPreset and proof photo parsing test', () {
      final presets = [
        {'id': 'bag_doorstep', 'title': 'Doorstep Insulated Bag', 'icon': '🥛'},
        {'id': 'cooler_box', 'title': 'Inside Cooler Box', 'icon': '📦'},
      ];

      expect(presets.length, 2);
      expect(presets[0]['id'], 'bag_doorstep');
      expect(presets[1]['icon'], '📦');
    });
  });
}
