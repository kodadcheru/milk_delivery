import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/category_products_screen.dart';
import '../screens/customer/help_support_screen.dart';
import '../screens/customer/address_book_screen.dart';
import '../screens/driver/morning_batch_screen.dart';
import '../screens/driver/driver_route_map_screen.dart';

class NotificationRouter {
  static void navigate(BuildContext context, NotificationModel item, AppState state) {
    // 1. Mark notification as read immediately
    if (!item.isRead) {
      state.markNotificationRead(item.id);
    }

    final targetScreen = item.targetScreen.toUpperCase().trim();
    final type = item.notificationType.toUpperCase().trim();
    final title = item.title.toLowerCase();
    final message = item.message.toLowerCase();
    final param = item.targetParam.trim();

    // 2. Driver-specific routing
    final userRole = (state.currentUser?.role ?? 'CUSTOMER').toUpperCase();
    if (userRole == 'DRIVER' || userRole == 'DELIVERY_PARTNER') {
      if (targetScreen == 'MORNING_BATCH' ||
          targetScreen == 'BATCH' ||
          title.contains('batch') ||
          message.contains('batch') ||
          title.contains('dispatch') ||
          message.contains('dispatch')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (ctx) => MorningBatchScreen(state: state)),
        );
        return;
      }
      if (targetScreen == 'DRIVER_ROUTE' ||
          targetScreen == 'ROUTE' ||
          title.contains('route') ||
          message.contains('route') ||
          message.contains('map')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => DriverRouteMapScreen(
              state: state,
              tasks: state.deliveries,
            ),
          ),
        );
        return;
      }
      // Return to driver main screen
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    // 3. Customer Routing

    // A. Specific Offers or Categories (e.g. Milk, Curd, Ghee, Paneer, Eggs, Water, Bread, Meat)
    if (targetScreen == 'CATEGORY' || targetScreen == 'OFFERS' || type == 'OFFER') {
      String? categoryKey = param.isNotEmpty ? param.toUpperCase() : null;

      if (categoryKey == null || categoryKey.isEmpty) {
        if (title.contains('milk') || message.contains('milk') || title.contains('cow') || title.contains('buffalo')) {
          categoryKey = 'MILK';
        } else if (title.contains('curd') || message.contains('curd') || title.contains('dahi') || title.contains('yogurt')) {
          categoryKey = 'CURD';
        } else if (title.contains('ghee') || message.contains('ghee') || title.contains('butter') || title.contains('makkhan')) {
          categoryKey = 'GHEE';
        } else if (title.contains('paneer') || message.contains('paneer') || title.contains('cheese')) {
          categoryKey = 'PANEER';
        } else if (title.contains('egg') || message.contains('egg')) {
          categoryKey = 'EGGS';
        } else if (title.contains('water') || message.contains('water') || title.contains('can')) {
          categoryKey = 'WATER_CAN';
        } else if (title.contains('bread') || message.contains('bread') || title.contains('bakery') || title.contains('sourdough')) {
          categoryKey = 'BAKERY';
        } else if (title.contains('meat') || message.contains('meat') || title.contains('chicken') || title.contains('mutton') || title.contains('poultry')) {
          categoryKey = 'MEAT';
        }
      }

      if (categoryKey != null && categoryKey.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => CategoryProductsScreen(categoryKey: categoryKey!, state: state),
          ),
        );
        return;
      }
    }

    // B. Delivery / Order Tracking
    if (targetScreen == 'DELIVERIES' ||
        targetScreen == 'DELIVERY' ||
        targetScreen == 'TRACKER' ||
        targetScreen == 'ORDERS' ||
        type == 'DELIVERY' ||
        title.contains('delivered') ||
        title.contains('dispatched') ||
        title.contains('arriving') ||
        title.contains('order') ||
        title.contains('morning drop') ||
        title.contains('out for delivery') ||
        message.contains('delivery') ||
        message.contains('dispatched') ||
        message.contains('delivered')) {
      state.setTab(3); // Switch to Orders / DeliveryTrackerTab
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    // C. Wallet / Recharge / Cashback
    if (targetScreen == 'WALLET' ||
        type == 'WALLET' ||
        title.contains('wallet') ||
        title.contains('recharge') ||
        title.contains('cashback') ||
        title.contains('balance') ||
        title.contains('refund') ||
        title.contains('credited') ||
        title.contains('deducted') ||
        message.contains('wallet') ||
        message.contains('balance') ||
        message.contains('recharge')) {
      state.setTab(2); // Switch to WalletTab
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    // D. Subscriptions / Vacation / Schedule
    if (targetScreen == 'SUBSCRIPTIONS' ||
        targetScreen == 'SUBSCRIPTION' ||
        targetScreen == 'VACATION' ||
        type == 'VACATION' ||
        title.contains('vacation') ||
        title.contains('pause') ||
        title.contains('resume') ||
        title.contains('subscription') ||
        title.contains('daily milk') ||
        message.contains('subscription') ||
        message.contains('vacation') ||
        message.contains('schedule')) {
      state.setTab(1); // Switch to SubscriptionsTab
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    // E. Customer Support / Help Desk
    if (targetScreen == 'SUPPORT' ||
        targetScreen == 'HELP' ||
        type == 'SUPPORT' ||
        title.contains('support') ||
        title.contains('ticket') ||
        title.contains('agent') ||
        title.contains('help') ||
        message.contains('support') ||
        message.contains('complaint') ||
        message.contains('executive')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => HelpSupportScreen(state: state)),
      );
      return;
    }

    // F. Saved Address / Profile
    if (targetScreen == 'ADDRESS' ||
        targetScreen == 'PROFILE' ||
        title.contains('address') ||
        message.contains('address') ||
        title.contains('location')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => AddressBookScreen(state: state)),
      );
      return;
    }

    // G. Default fallback -> Switch to Home Tab
    state.setTab(0);
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
