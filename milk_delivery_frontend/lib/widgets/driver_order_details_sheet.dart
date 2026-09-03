import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/live_order_model.dart';
import '../providers/app_state.dart';
import '../theme/ui_text.dart';
import '../theme/ui_tokens.dart';

/// Dedicated Driver Order Details Sheet
/// Displays all customer, item manifest, doorstep address, COD collection,
/// and Google Maps navigation details tailored specifically for delivery drivers.
class DriverOrderDetailsSheet extends StatelessWidget {
  final AppState state;
  final LiveOrderModel order;
  final VoidCallback? onCompleted;

  const DriverOrderDetailsSheet({
    super.key,
    required this.state,
    required this.order,
    this.onCompleted,
  });

  static void show(
    BuildContext context,
    AppState state,
    LiveOrderModel order, {
    VoidCallback? onCompleted,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverOrderDetailsSheet(
        state: state,
        order: order,
        onCompleted: onCompleted,
      ),
    );
  }

  static Future<void> launchMapsNavigation(double lat, double lon, {String? label}) async {
    HapticFeedback.mediumImpact();
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    final universalMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri);
      } else {
        await launchUrl(universalMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(universalMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  static void callPhone(BuildContext context, String phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Customer phone number is not available.'),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer for $phone')),
        );
      }
    }
  }

  static void sendSms(BuildContext context, String phone, String orderId) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final msg = Uri.encodeComponent('Hello, your Pamba delivery driver is en-route with order $orderId!');
    final uri = Uri.parse('sms:$cleanPhone?body=$msg');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  /// Clean display address by stripping raw Google Plus codes (e.g. 2X27+P3X)
  String _cleanAddress(String raw) {
    if (raw.trim().isEmpty || raw == 'Doorstep Delivery Location') {
      return 'Main Road / Colony Doorstep, Kodad';
    }
    // Remove Plus Code tokens like 2X27+P3X or 2X27+M36
    final cleaned = raw
        .replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4},?\s*'), '')
        .replaceAll(RegExp(r',\s*[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}'), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : raw;
  }

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status == 'DELIVERED';
    final isCancelled = order.status == 'CANCELLED';
    final cleanAddr = _cleanAddress(order.deliveryAddress);
    final customerName = order.customerName.isNotEmpty ? order.customerName : 'Pamba Customer';
    final customerPhone = order.customerPhone.isNotEmpty ? order.customerPhone : '+91 8919548905';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Drag Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: UiTone.surfaceBorder,
                borderRadius: BorderRadius.circular(UiRadius.pill),
              ),
            ),
          ),

          // ── Top Bar with Order ID & Status ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.id,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: UiTone.errorSoft,
                              borderRadius: BorderRadius.circular(UiRadius.pill),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flash_on_rounded, color: UiTone.error, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '30-MIN EXPRESS',
                                  style: UiText.caption.copyWith(
                                    color: UiTone.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDelivered ? UiTone.successSoft : UiTone.warningSoft,
                              borderRadius: BorderRadius.circular(UiRadius.pill),
                            ),
                            child: Text(
                              isDelivered ? 'DELIVERED ✅' : 'PICKUP READY 🛵',
                              style: UiText.caption.copyWith(
                                color: isDelivered ? UiTone.success : UiTone.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled: ${order.deliverySlot} • ${order.deliveryDate}',
                        style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Scrollable Body ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              children: [
                // ── 1. COD / Payment Collection Banner ──
                if (order.isCod) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE68A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFFB45309), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '💵 CASH ON DELIVERY (COD)',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Collect ₹${order.totalAmount.toStringAsFixed(0)} in cash from customer before handing over items!',
                                style: const TextStyle(
                                  color: Color(0xFF78350F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB45309),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UiTone.successSoft,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: UiTone.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: UiTone.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '💳 PREPAID ORDER (Wallet / Online) • No Cash Collection Required',
                            style: UiText.caption.copyWith(
                              color: UiTone.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── 2. Customer Contact Card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                    border: Border.all(color: UiTone.surfaceBorder),
                    boxShadow: UiShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: UiTone.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                    color: UiTone.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: UiText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    customerPhone,
                                    style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton.filled(
                                onPressed: () => callPhone(context, customerPhone),
                                icon: const Icon(Icons.phone_rounded, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton.filled(
                                onPressed: () => sendSms(context, customerPhone, order.id),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 3. Full Doorstep Address & 1-Tap Navigation Card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                    border: Border.all(color: UiTone.surfaceBorder),
                    boxShadow: UiShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Doorstep Delivery Location',
                                style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('GPS TARGET', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        cleanAddr,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 1-Tap Navigation Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => launchMapsNavigation(order.deliveryLatitude, order.deliveryLongitude),
                          icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'Navigate in Google Maps 🗺️',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7C66),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 4. Itemized Manifest & Quantities ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UiRadius.lg),
                    border: Border.all(color: UiTone.surfaceBorder),
                    boxShadow: UiShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_rounded, color: UiTone.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Items to Deliver (${order.totalItemCount})',
                                style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          Text(
                            'Total: ₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: UiTone.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item.product.category.toUpperCase().contains('MILK')
                                      ? '🥛'
                                      : item.product.category.toUpperCase().contains('WATER')
                                          ? '💧'
                                          : item.product.category.toUpperCase().contains('EGG')
                                              ? '🥚'
                                              : item.product.category.toUpperCase().contains('GHEE')
                                                  ? '🧈'
                                                  : '📦',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      '₹${item.unitPrice.toStringAsFixed(0)} each • ${item.product.unitQuantity.isNotEmpty ? item.product.unitQuantity : item.product.unit}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: UiTone.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'x${item.quantity}',
                                  style: const TextStyle(
                                    color: UiTone.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── 5. Driver OTP Verification Prompt ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pin_rounded, color: Color(0xFF0F172A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Secure Delivery OTP Required',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              isDelivered
                                  ? 'Verified with OTP: ${order.deliveryOtp}'
                                  : 'Ask the customer for their 4-digit SMS OTP upon arrival.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (isDelivered)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Bottom Action Bar ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: UiTone.surfaceBorder)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: isDelivered
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: UiTone.successSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: UiTone.success, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Order Delivered & Verified ✅',
                            style: TextStyle(color: UiTone.success, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => callPhone(context, customerPhone),
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: UiTone.primary,
                              side: const BorderSide(color: UiTone.primary, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isCancelled
                                ? null
                                : () => _showVerifyOtpModal(context),
                            icon: const Icon(Icons.pin_rounded, color: Colors.white, size: 18),
                            label: Text(
                              order.isCod ? 'Collect & Deliver 💵' : 'Verify OTP & Deliver',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVerifyOtpModal(BuildContext context) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
        title: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: UiTone.error),
            const SizedBox(width: 8),
            Text('Complete ${order.id}', style: UiText.h2.copyWith(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName.isNotEmpty ? order.customerName : "Customer"}', style: UiText.bodyStrong.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Address: ${_cleanAddress(order.deliveryAddress)}', style: UiText.body.copyWith(fontSize: 12)),
            if (order.isCod) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: UiTone.warningSoft,
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  border: Border.all(color: UiTone.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded, color: UiTone.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '💵 CASH ON DELIVERY: Collect ₹${order.totalAmount.toStringAsFixed(0)} cash at doorstep!',
                        style: UiText.caption.copyWith(color: UiTone.warning, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text('Enter 4-Digit Customer OTP:', style: UiText.bodyStrong.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter 4-digit OTP',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (otpController.text.trim() == order.deliveryOtp) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close sheet
                state.updateOrderStatus(order.id, 'DELIVERED', deliveryOtp: otpController.text.trim());
                onCompleted?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: UiTone.primary,
                    content: Text(
                      '🎉 Express Order ${order.id} Delivered Successfully!${order.isCod ? " ₹${order.totalAmount.toStringAsFixed(0)} cash collected." : ""}',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('⚠️ Invalid OTP! Please check with customer.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: UiTone.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify & Confirm'),
          ),
        ],
      ),
    );
  }
}
