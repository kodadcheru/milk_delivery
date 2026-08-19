import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/delivery_task_model.dart';
import '../models/live_order_model.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../screens/customer/help_support_screen.dart';
import '../screens/customer/live_driver_tracking_screen.dart';

class BookingDetailSheet extends StatelessWidget {
  final AppState state;
  final LiveOrderModel? liveOrder;
  final DeliveryTaskModel? subscriptionTask;

  const BookingDetailSheet({
    super.key,
    required this.state,
    this.liveOrder,
    this.subscriptionTask,
  });

  static void showForExpressOrder(BuildContext context, AppState state, LiveOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => BookingDetailSheet(state: state, liveOrder: order),
    );
  }

  static void showForSubscription(BuildContext context, AppState state, DeliveryTaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => BookingDetailSheet(state: state, subscriptionTask: task),
    );
  }

  void _callPhone(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D7C66),
            content: Text('📞 Dialing: $phone'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpress = liveOrder != null;

    final title = isExpress ? 'Express Order #${liveOrder!.id}' : 'Morning Delivery #${subscriptionTask!.id}';
    final status = isExpress ? liveOrder!.status : subscriptionTask!.status;
    final isDelivered = status == 'DELIVERED';
    final address = isExpress ? liveOrder!.deliveryAddress : subscriptionTask!.deliveryAddress;
    final driverName = isExpress ? liveOrder!.driverName : (subscriptionTask!.driverDetail?.fullName.isNotEmpty == true ? subscriptionTask!.driverDetail!.fullName : 'Assigning Delivery Partner...');
    final driverPhone = isExpress ? liveOrder!.driverPhone : (subscriptionTask!.driverDetail?.phone.isNotEmpty == true ? subscriptionTask!.driverDetail!.phone : '');
    final slot = isExpress ? liveOrder!.deliverySlot : subscriptionTask!.slotTime;
    final proofUrl = isExpress ? '' : subscriptionTask!.proofImageUrl;
    final otp = isExpress ? liveOrder!.deliveryOtp : '06AM';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(
                    isExpress ? '⚡ 30-Minute Priority Order' : '🥛 Daily Morning Subscription Slot',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Order Status Banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isDelivered ? const Color(0xFF10B981) : const Color(0xFF0284C7)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDelivered ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDelivered ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDelivered ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDelivered ? 'DELIVERED AT DOORSTEP' : 'OUT FOR DELIVERY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: isDelivered ? const Color(0xFF0D7C66) : const Color(0xFF0369A1),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDelivered ? 'Photo proof uploaded & wallet auto-debited' : 'Estimated Arrival within $slot',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDelivered ? const Color(0xFF0D7C66) : const Color(0xFF0369A1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isExpress && !isDelivered)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF0D7C66), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                const Text('OTP', style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                Text(otp, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Assigned Delivery Partner with 2-WAY CALLING ──
                  const Text('Assigned Delivery Partner:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.15),
                          child: const Text('👨‍🌾', style: TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      driverName,
                                      maxLines: 2,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('EV Scooter • TS 09 EQ 4821 • ⭐ 4.9', style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        // Direct 2-Way Calling Button
                        ElevatedButton.icon(
                          onPressed: () => _callPhone(context, driverPhone),
                          icon: const Icon(Icons.phone_rounded, size: 14),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 3. Doorstep Delivery Address ──
                  const Text('Doorstep Delivery Location:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_rounded, color: Color(0xFF0D7C66), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(address, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              Text(
                                'Timeslot: $slot',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF0D7C66), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 4. Itemized Product Breakdown ──
                  const Text('Order Items & Payment:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        if (isExpress) ...[
                          ...liveOrder!.items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(it.product.icon, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${it.quantity}x ${it.product.name} (${it.product.unitQuantity})',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                    ),
                                  ),
                                  Text(
                                    '₹${it.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              Text(liveOrder!.paymentStatus, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount Paid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('₹${liveOrder!.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0D7C66))),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Text(subscriptionTask!.subscriptionDetail?.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${subscriptionTask!.subscriptionDetail?.quantity ?? 1}x ${subscriptionTask!.subscriptionDetail?.productDetail?.name ?? "Fresh Vedic Milk"}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                              Text(
                                '₹${((subscriptionTask!.subscriptionDetail?.productDetail?.pricePerUnit ?? 40) * (subscriptionTask!.subscriptionDetail?.quantity ?? 1)).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0D7C66)),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subscription Schedule', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(subscriptionTask!.subscriptionDetail?.scheduleType ?? 'DAILY', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66))),
                            ],
                          ),
                          const Divider(height: 16),
                          // ── Subscription Management Controls ──
                          const Text('Subscription Controls ⚙️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Daily Qty:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF0D7C66)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                              final sub = subscriptionTask!.subscriptionDetail;
                                              if (sub != null && sub.quantity > 1) {
                                                final success = await ApiService.updateSubscription(sub.id, quantity: sub.quantity - 1);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(success ? 'Updated daily quantity to ${sub.quantity - 1}' : 'Failed to update subscription')),
                                                  );
                                                  if (success) state.reloadAllData();
                                                }
                                              }
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text('${subscriptionTask!.subscriptionDetail?.quantity ?? 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF0D7C66)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                              final sub = subscriptionTask!.subscriptionDetail;
                                              if (sub != null) {
                                                final success = await ApiService.updateSubscription(sub.id, quantity: sub.quantity + 1);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(success ? 'Updated daily quantity to ${sub.quantity + 1}' : 'Failed to update subscription')),
                                                  );
                                                  if (success) state.reloadAllData();
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final sub = subscriptionTask!.subscriptionDetail;
                                  if (sub == null) return;
                                  final now = DateTime.now();
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: now,
                                    lastDate: now.add(const Duration(days: 90)),
                                    helpText: 'Select Vacation Dates to Pause Milk Drops',
                                  );
                                  if (picked != null && context.mounted) {
                                    final startStr = picked.start.toIso8601String().split('T')[0];
                                    final endStr = picked.end.toIso8601String().split('T')[0];
                                    final success = await ApiService.pauseSubscription(sub.id, startStr, endStr);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: success ? const Color(0xFF0D7C66) : Colors.red,
                                          content: Text(success ? '🌴 Vacation Mode Active: Paused drops from $startStr to $endStr' : 'Failed to activate vacation mode'),
                                        ),
                                      );
                                      if (success) state.reloadAllData();
                                    }
                                  }
                                },
                                icon: const Icon(Icons.beach_access_rounded, size: 14),
                                label: const Text('Vacation 🌴', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D7C66),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 5. Doorstep Photo Proof (If Available) ──
                  if (proofUrl.isNotEmpty) ...[
                    const Text('Doorstep Delivery Photo Proof 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        color: const Color(0xFFF1F5F9),
                        child: Image.network(
                          proofUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom Action CTAs ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => HelpSupportScreen(state: state, initialTopic: 'I need help with booking $title'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.headset_mic_rounded, color: Color(0xFF0D7C66), size: 16),
                    label: const Text('Help & Chat', style: TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D7C66)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => LiveDriverTrackingScreen(
                            state: state,
                            liveOrder: liveOrder,
                            orderTitle: isExpress ? (liveOrder!.items.isNotEmpty ? liveOrder!.items.first.product.name : 'Express Order') : 'Morning Milk Delivery',
                            deliveryAddress: address,
                            driverName: driverName,
                            driverPhone: driverPhone,
                            deliveryOtp: otp,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                    label: const Text('Track Live on Map 🛰️', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
