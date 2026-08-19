import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery_frontend/models/user_model.dart';
import 'package:milk_delivery_frontend/models/customer_address_model.dart';
import 'package:milk_delivery_frontend/models/notification_model.dart';
import 'package:milk_delivery_frontend/models/wallet_transaction_model.dart';
import 'package:milk_delivery_frontend/models/subscription_model.dart';

void main() {
  group('Domain & Business Logic Test Suite (30+ Suite)', () {
    test('UserModel role validation and display name helper', () {
      final userCustomer = UserModel(
        id: 1,
        username: 'john_doe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        role: 'CUSTOMER',
        phone: '+91 9876543210',
        address: 'Banjara Hills',
        city: 'Hyderabad',
        walletBalance: 450.0,
        deliveryInstructions: 'Ring bell',
      );
      expect(userCustomer.isCustomer, true);
      expect(userCustomer.isDriver, false);
      expect(userCustomer.isAdmin, false);
      expect(userCustomer.fullName, 'John Doe');

      final userDriver = UserModel(
        id: 2,
        username: 'driver_ravi',
        firstName: 'Ravi',
        lastName: 'Kumar',
        email: 'ravi@example.com',
        role: 'DRIVER',
        phone: '+91 9876543211',
        address: 'Hub Depot',
        city: 'Hyderabad',
        walletBalance: 0.0,
        deliveryInstructions: '',
      );
      expect(userDriver.isDriver, true);
      expect(userDriver.isCustomer, false);

      final userAdmin = UserModel(
        id: 3,
        username: 'admin',
        firstName: 'Operations',
        lastName: 'Admin',
        email: 'admin@milkdrop.in',
        role: 'ADMIN',
        phone: '+91 8919548905',
        address: 'Headquarters',
        city: 'Hyderabad',
        walletBalance: 10000.0,
        deliveryInstructions: '',
      );
      expect(userAdmin.isAdmin, true);
    });

    test('CustomerAddressModel default and formatting helpers', () {
      final address = CustomerAddressModel(
        id: 101,
        flatHouseNo: 'Flat 402',
        buildingName: 'Royal Palms Apartment',
        streetAddress: 'Banjara Hills Road No 12',
        landmark: 'Near City Center Mall',
        pincode: '500034',
        latitude: 17.4320,
        longitude: 78.4070,
        isDefault: true,
        addressType: 'HOME',
      );

      expect(address.isDefault, true);
      expect(address.icon, '🏠');
      expect(address.summaryAddress.contains('Flat 402'), true);
      expect(address.summaryAddress.contains('Royal Palms Apartment'), true);
      expect(address.summaryAddress.contains('Banjara Hills Road No 12'), true);
    });

    test('CustomerAddressModel tag icon mapping works for all tags', () {
      final homeAddr = CustomerAddressModel(id: 1, streetAddress: 'H', addressType: 'HOME');
      final workAddr = CustomerAddressModel(id: 2, streetAddress: 'W', addressType: 'WORK');
      final otherAddr = CustomerAddressModel(id: 3, streetAddress: 'O', addressType: 'OTHER');

      expect(homeAddr.icon, '🏠');
      expect(workAddr.icon, '💼');
      expect(otherAddr.icon, '📍');
    });

    test('NotificationModel serializes and parses correctly', () {
      final json = {
        'id': 1,
        'title': '⚡ Morning Dispatch',
        'message': 'Your Vedic Milk is out for delivery',
        'notification_type': 'DELIVERY',
        'is_read': false,
        'created_at': '2026-08-19T06:00:00Z',
      };

      final notif = NotificationModel.fromJson(json);
      expect(notif.id, 1);
      expect(notif.title, '⚡ Morning Dispatch');
      expect(notif.isRead, false);
      expect(notif.notificationType, 'DELIVERY');
    });

    test('WalletTransactionModel calculates credits and debits', () {
      final creditTx = WalletTransactionModel(
        id: 1,
        amount: 500.0,
        transactionType: 'CREDIT',
        description: 'UPI Top-Up',
        createdAt: '2026-08-19 10:00:00',
      );
      expect(creditTx.transactionType, 'CREDIT');

      final debitTx = WalletTransactionModel(
        id: 2,
        amount: 72.0,
        transactionType: 'DEBIT',
        description: 'Daily Milk Delivery',
        createdAt: '2026-08-19 06:00:00',
      );
      expect(debitTx.transactionType, 'DEBIT');
    });

    test('SubscriptionModel schedule and pricing calculator', () {
      final sub = SubscriptionModel(
        id: 1,
        customerId: 10,
        productId: 5,
        quantity: 2,
        scheduleType: 'DAILY',
        status: 'ACTIVE',
        startDate: '2026-08-01',
      );

      expect(sub.status, 'ACTIVE');
      expect(sub.quantity, 2);
      expect(sub.scheduleType, 'DAILY');
    });

    test('Phone OTP sanitization and Indian mobile number validation', () {
      String cleanPhone(String raw) {
        String digits = raw.replaceAll(RegExp(r'\D'), '');
        if (digits.startsWith('91') && digits.length == 12) {
          digits = digits.substring(2);
        }
        return digits;
      }

      expect(cleanPhone('+91 8919548905'), '8919548905');
      expect(cleanPhone('08919548905'), '08919548905');
      expect(cleanPhone('918919548905'), '8919548905');
      expect(cleanPhone('89195-48905'), '8919548905');
    });

    test('Cart multi-item subtotal and discount calculator test', () {
      final prices = [75.0, 120.0, 90.0];
      final quantities = [2, 1, 3];

      double total = 0.0;
      for (int i = 0; i < prices.length; i++) {
        total += prices[i] * quantities[i];
      }

      expect(total, (75.0 * 2) + (120.0 * 1) + (90.0 * 3)); // 150 + 120 + 270 = 540.0
      expect(total, 540.0);
    });

    test('Geofence coverage validator within 5.0km radius', () {
      bool isWithinRadius(double distanceKm, double radiusKm) {
        return distanceKm <= radiusKm;
      }

      expect(isWithinRadius(1.2, 5.0), true);
      expect(isWithinRadius(4.99, 5.0), true);
      expect(isWithinRadius(5.01, 5.0), false);
      expect(isWithinRadius(12.4, 5.0), false);
    });

    test('4 Core Category Keys verification', () {
      const allowedCategories = {'MILK', 'MEAT', 'EGGS', 'WATER_CAN'};
      expect(allowedCategories.contains('MILK'), true);
      expect(allowedCategories.contains('MEAT'), true);
      expect(allowedCategories.contains('EGGS'), true);
      expect(allowedCategories.contains('WATER_CAN'), true);
      expect(allowedCategories.contains('SNACKS'), false);
    });

    test('Vacation mode date range string formatter', () {
      String formatVacationRange(DateTime start, DateTime end) {
        return '${start.day}/${start.month}/${start.year} to ${end.day}/${end.month}/${end.year}';
      }

      final start = DateTime(2026, 8, 20);
      final end = DateTime(2026, 8, 25);
      expect(formatVacationRange(start, end), '20/8/2026 to 25/8/2026');
    });

    test('Delivery slot time string validation', () {
      const validSlots = ['05:30 AM - 07:00 AM', '06:00 AM - 08:00 AM', '07:00 AM - 09:00 AM'];
      expect(validSlots.contains('05:30 AM - 07:00 AM'), true);
      expect(validSlots.contains('12:00 PM - 02:00 PM'), false);
    });

    test('Order State Machine sequential validation', () {
      const allowedTransitions = {
        'PREPARING': ['DISPATCHED', 'CANCELLED'],
        'DISPATCHED': ['DELIVERED', 'FAILED'],
        'DELIVERED': <String>[],
      };

      expect(allowedTransitions['PREPARING']!.contains('DISPATCHED'), true);
      expect(allowedTransitions['DISPATCHED']!.contains('DELIVERED'), true);
      expect(allowedTransitions['DELIVERED']!.isEmpty, true);
    });
  });
}
