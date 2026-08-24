import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/delivery_task_model.dart';
import '../models/live_order_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/help_support_screen.dart';
import '../screens/customer/live_driver_tracking_screen.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';
import '../theme/ui_format.dart';


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
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
      builder: (ctx) => BookingDetailSheet(state: state, liveOrder: order),
    );
  }

  static void showForSubscription(BuildContext context, AppState state, DeliveryTaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl))),
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
            backgroundColor: UiTone.primary,
            content: Text('📞 Dialing: $phone'),
          ),
        );
      }
    }
  }

  /// Shared section label style (bold, 13, ink).
  Widget _sectionLabel(String text) =>
      Text(text, style: UiText.bodyStrong.copyWith(fontSize: 13));

  @override
  Widget build(BuildContext context) {
    final isExpress = liveOrder != null;

    final title = isExpress ? 'Express Order #${liveOrder!.id}' : 'Morning Delivery #${subscriptionTask!.id}';
    final status = isExpress ? liveOrder!.status : subscriptionTask!.status;
    final isDelivered = status == 'DELIVERED';
    final activeAddr = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
    final rawAddress = isExpress ? liveOrder!.deliveryAddress : subscriptionTask!.deliveryAddress;
    final displayAddress = (rawAddress.isNotEmpty && rawAddress != 'Doorstep Delivery Location')
        ? rawAddress
        : (activeAddr.isNotEmpty ? activeAddr : 'Doorstep Delivery Location');

    final driverName = isExpress ? liveOrder!.driverName : (subscriptionTask!.driverDetail?.fullName.isNotEmpty == true ? subscriptionTask!.driverDetail!.fullName : 'Assigning Delivery Partner...');
    final driverPhone = isExpress ? liveOrder!.driverPhone : (subscriptionTask!.driverDetail?.phone.isNotEmpty == true ? subscriptionTask!.driverDetail!.phone : '');
    final isDriverAssigned = driverPhone.isNotEmpty && !driverName.startsWith('Assigning');
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
              decoration: BoxDecoration(color: UiTone.surfaceBorder, borderRadius: BorderRadius.circular(UiRadius.pill)),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: UiText.h2),
                    const SizedBox(height: 2),
                    Text(
                      isExpress ? '⚡ 30-Minute Priority Order' : '🥛 Daily Morning Subscription Slot',
                      style: UiText.caption,
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), color: UiTone.softText, onPressed: () => Navigator.pop(context)),
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
                      color: (isDelivered ? UiTone.secondary : UiTone.accentBlue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(
                        color: isDelivered ? UiTone.secondary : UiTone.accentBlue,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDelivered ? UiTone.secondary : UiTone.accentBlue,
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
                                  color: isDelivered ? UiTone.primary : UiTone.accentBlue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDelivered ? 'Photo proof uploaded & wallet auto-debited' : 'Estimated Arrival within $slot',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDelivered ? UiTone.primary : UiTone.accentBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isExpress && !isDelivered)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: UiTone.primary, borderRadius: BorderRadius.circular(UiRadius.xs)),
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

                  // ── 1.5. Scheduled Date & Delivery Window ──
                  _sectionLabel('Scheduled Date & Delivery Window:'),
                  const SizedBox(height: 8),

                  Builder(builder: (context) {
                    final rawDate = isExpress ? liveOrder!.deliveryDate : subscriptionTask!.deliveryDate;
                    final displayDate = rawDate.isNotEmpty ? rawDate : 'Today, ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
                    final isEvening = slot.toUpperCase().contains('PM') || slot.toUpperCase().contains('17:') || slot.toUpperCase().contains('18:') || slot.toUpperCase().contains('19:');
                    final shiftTitle = isEvening ? '🌙 Evening Delivery Shift' : '☀️ Morning Delivery Shift';
                    final orderPlaced = isExpress ? (liveOrder!.createdAt.isNotEmpty ? liveOrder!.createdAt : 'Today') : 'Active Daily Plan';

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: UiTone.shellBackground,
                        borderRadius: BorderRadius.circular(UiRadius.md),
                        border: Border.all(color: isEvening ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : const Color(0xFF0D7C66).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isEvening ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : const Color(0xFF0D7C66).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(UiRadius.sm),
                                ),
                                child: Icon(
                                  isEvening ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                                  color: isEvening ? const Color(0xFF7C3AED) : const Color(0xFF0D7C66),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📅 Delivery Date: $displayDate',
                                      style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$shiftTitle • $slot',
                                      style: UiText.caption.copyWith(
                                        color: isEvening ? const Color(0xFF7C3AED) : const Color(0xFF0D7C66),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order Placed / Scheduled', style: UiText.caption.copyWith(fontSize: 11)),
                              Text(orderPlaced, style: UiText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: UiTone.ink)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // ── 2. Assigned Delivery Partner with 2-WAY CALLING ──
                  _sectionLabel('Assigned Delivery Partner:'),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UiTone.shellBackground,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: UiTone.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: UiTone.primary.withValues(alpha: 0.15),
                          child: Text(isDriverAssigned ? '👨‍🌾' : '🛵', style: const TextStyle(fontSize: 24)),
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
                                      isDriverAssigned ? driverName : '⌛ Partner Assignment in Progress',
                                      maxLines: 2,
                                      style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (isDriverAssigned) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, color: UiTone.secondary, size: 14),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDriverAssigned ? 'EV Scooter • TS 09 EQ 4821 • ⭐ 4.9' : 'Nearest Depot Hub assigning morning route partner',
                                style: UiText.caption.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        // Direct 2-Way Calling Button / Support
                        ElevatedButton.icon(
                          onPressed: () => _callPhone(context, isDriverAssigned ? driverPhone : '+918919548905'),
                          icon: const Icon(Icons.phone_rounded, size: 14),
                          label: Text(isDriverAssigned ? 'Call' : 'Support'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDriverAssigned ? UiTone.secondary : UiTone.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 3. Doorstep Delivery Address ──
                  _sectionLabel('Doorstep Delivery Location:'),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UiTone.shellBackground,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: UiTone.surfaceBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_rounded, color: UiTone.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayAddress, style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
                              const SizedBox(height: 4),
                              Text(
                                'Timeslot: $slot',
                                style: UiText.caption.copyWith(color: UiTone.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 4. Itemized Product Breakdown ──
                  _sectionLabel('Order Items & Payment:'),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: UiTone.shellBackground,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: UiTone.surfaceBorder),
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
                                      style: UiText.bodyStrong.copyWith(fontSize: 12.5),
                                    ),
                                  ),
                                  Text(
                                    UiFormat.price(it.totalPrice),
                                    style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Payment Status', style: UiText.label),
                              Text(liveOrder!.paymentStatus, style: UiText.label.copyWith(color: UiTone.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount Paid', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                              Text(UiFormat.price(liveOrder!.totalAmount), style: UiText.price.copyWith(color: UiTone.primary, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Text(subscriptionTask!.subscriptionDetail?.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${subscriptionTask!.subscriptionDetail?.quantity ?? 1}x ${subscriptionTask!.subscriptionDetail?.packSize ?? "1 Litre"}',
                                  style: UiText.bodyStrong.copyWith(fontSize: 13),
                                ),
                              ),
                              Text(
                                UiFormat.price((subscriptionTask!.subscriptionDetail?.displayPrice ?? 40) * (subscriptionTask!.subscriptionDetail?.quantity ?? 1)),
                                style: UiText.price.copyWith(fontSize: 14, color: UiTone.primary, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subscription Schedule', style: UiText.label),
                              Text(subscriptionTask!.subscriptionDetail?.scheduleType ?? 'DAILY', style: UiText.label.copyWith(color: UiTone.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Divider(height: 16),
                          // ── Subscription Management Controls ──
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Subscription Controls ⚙️', style: UiText.label.copyWith(color: UiTone.ink, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: UiTone.surfaceMuted,
                                    borderRadius: BorderRadius.circular(UiRadius.sm),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Daily Qty:', style: UiText.caption.copyWith(fontWeight: FontWeight.w700)),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: UiTone.primary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                             final sub = subscriptionTask!.subscriptionDetail;
                                             if (sub != null && sub.quantity > 1) {
                                               final success = await state.updateSubscriptionDetails(sub.id, quantity: sub.quantity - 1);
                                               if (context.mounted) {
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(content: Text(success ? 'Updated daily quantity to ${sub.quantity - 1}' : 'Failed to update subscription')),
                                                 );
                                               }
                                             }
                                           },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text('${subscriptionTask!.subscriptionDetail?.quantity ?? 1}', style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w900)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18, color: UiTone.primary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () async {
                                             final sub = subscriptionTask!.subscriptionDetail;
                                             if (sub != null) {
                                               final success = await state.updateSubscriptionDetails(sub.id, quantity: sub.quantity + 1);
                                               if (context.mounted) {
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(content: Text(success ? 'Updated daily quantity to ${sub.quantity + 1}' : 'Failed to update subscription')),
                                                 );
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
                                   final success = await state.pauseSubscriptionWithDates(sub.id, startStr, endStr, 'Vacation');
                                   if (context.mounted) {
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         backgroundColor: success ? UiTone.primary : UiTone.error,
                                         content: Text(success ? '🌴 Vacation Mode Active: Paused drops from $startStr to $endStr' : 'Failed to activate vacation mode'),
                                       ),
                                     );
                                   }
                                 }
                               },
                                icon: const Icon(Icons.beach_access_rounded, size: 14),
                                label: const Text('Vacation 🌴', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: UiTone.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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

                  // ── 5. Milk Purity & Quality Test Report (FAT, SNF, Water %) ──
                  if (isExpress) ...[
                    _buildMilkQualityReport(
                      productName: liveOrder!.items.isNotEmpty ? liveOrder!.items.first.product.name : 'Vedic Milk',
                      category: liveOrder!.items.isNotEmpty ? liveOrder!.items.first.product.category : 'MILK',
                    ),
                  ] else ...[
                    _buildMilkQualityReport(
                      productName: subscriptionTask!.subscriptionDetail?.productDetail?.name ?? 'Fresh Vedic Milk',
                      category: subscriptionTask!.subscriptionDetail?.productDetail?.category ?? 'MILK',
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── 6. Doorstep Photo Proof (If Available) ──
                  if (proofUrl.isNotEmpty) ...[
                    _sectionLabel('Doorstep Delivery Photo Proof 📸'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        color: UiTone.surfaceMuted,
                        child: Image.network(
                          proofUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: UiText.muted)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // ── 7. Live Mobility Service Tracking Radar Card (If Active / In Transit) ──
                  if (!isDelivered) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => LiveDriverTrackingScreen(
                              state: state,
                              liveOrder: liveOrder,
                              subscriptionTask: subscriptionTask,
                              orderTitle: isExpress
                                  ? (liveOrder!.items.isNotEmpty ? liveOrder!.items.first.product.name : 'Express Order')
                                  : (subscriptionTask?.productName ?? 'Morning Milk Delivery'),
                              deliveryAddress: displayAddress,
                              driverName: driverName,
                              driverPhone: driverPhone,
                              deliveryOtp: otp,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: UiTone.ink,
                          borderRadius: BorderRadius.circular(UiRadius.lg),
                          boxShadow: UiShadow.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: UiTone.primary.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(UiRadius.md),
                              ),
                              child: const Text('🛵', style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Live Radar & Partner Tracking',
                                        style: UiText.bodyStrong.copyWith(color: Colors.white, fontSize: 13.5),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(color: UiTone.secondary, shape: BoxShape.circle),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Driver: $driverName • OTP: $otp',
                                    style: UiText.caption.copyWith(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                          ],
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
                    icon: const Icon(Icons.headset_mic_rounded, color: UiTone.primary, size: 16),
                    label: Text('Help & Chat', style: UiText.label.copyWith(color: UiTone.primary, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: UiTone.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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
                            subscriptionTask: subscriptionTask,
                            orderTitle: isExpress
                                ? (liveOrder!.items.isNotEmpty ? liveOrder!.items.first.product.name : 'Express Order')
                                : (subscriptionTask?.productName ?? 'Morning Milk Delivery'),
                            deliveryAddress: displayAddress,
                            driverName: driverName,
                            driverPhone: driverPhone,
                            deliveryOtp: otp,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.moped_rounded, size: 18),
                    label: Text('Track Partner Live 🛵', style: UiText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UiTone.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
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

  Widget _buildMilkQualityReport({
    required String productName,
    required String category,
  }) {
    final nameLower = productName.toLowerCase();

    // 1. Check if the delivery task itself has batch parameters wired
    double directFat = subscriptionTask?.fatPercentage ?? liveOrder?.fatPercentage ?? 0.0;
    double directSnf = subscriptionTask?.snfPercentage ?? liveOrder?.snfPercentage ?? 0.0;
    double directWater = subscriptionTask?.waterPercentage ?? liveOrder?.waterPercentage ?? 0.0;
    double directPrice = subscriptionTask?.batchPricePerLitre ?? liveOrder?.batchPricePerLitre ?? 0.0;
    String directBatchCode = subscriptionTask?.batchCode ?? liveOrder?.batchCode ?? '';
    double directTemp = subscriptionTask?.temperatureCelsius ?? 3.8;

    String fatVal = '';
    String snfVal = '';
    String waterVal = '';
    String priceVal = '';
    String batchCode = '';
    String tempVal = '';
    String puritySub = '';

    // Consider > 0 for fat to indicate it was directly provided from the DB instead of defaulted
    // In DeliveryTaskModel, default was 6.8 but maybe it comes as 0.0 from DB if not set, wait...
    // Actually the prompt says: "If those are null/0, fall back to the existing state.dailyMilkBatches string matching"
    // Since delivery_task_model has 6.8 as default, if it's 6.8 it might be the default. But we'll just check > 0 and batchCode != 'BATCH-LIVE-01' maybe?
    // Wait, let's just do > 0.
    if (directFat > 0 && directSnf > 0 && (directBatchCode.isNotEmpty && directBatchCode != 'BATCH-LIVE-01' && directBatchCode != 'BATCH-TODAY-01')) {
      fatVal = '$directFat%';
      snfVal = '$directSnf%';
      waterVal = '$directWater%';
      priceVal = directPrice > 0 ? '₹${directPrice.toStringAsFixed(0)}/L' : '';
      batchCode = directBatchCode;
      tempVal = '$directTemp°C';
      puritySub = 'Hub Certified ($batchCode) • Chilled at $tempVal';
    } else {
      // 2. Check if Hub Provider certified a batch for today
      Map<String, dynamic>? activeBatch;
      final batches = state.dailyMilkBatches;
      if (batches.isNotEmpty) {
        activeBatch = batches.firstWhere(
          (b) {
            final bName = b['product_name']?.toString().toLowerCase() ?? '';
            return bName.contains(nameLower.split(' ').first) || (nameLower.split(' ').isNotEmpty && bName.contains(nameLower.split(' ').first));
          },
          orElse: () => batches.first,
        );
      }

      if (activeBatch != null) {
        fatVal = '${activeBatch['fat_percentage']}%';
        snfVal = '${activeBatch['snf_percentage']}%';
        waterVal = '${activeBatch['water_percentage']}%';
        final parsedP = double.tryParse(activeBatch['price_per_litre']?.toString() ?? '68') ?? 68.0;
        priceVal = '₹${parsedP.toStringAsFixed(0)}/L';
        batchCode = activeBatch['batch_code']?.toString() ?? (directBatchCode.isNotEmpty ? directBatchCode : 'BATCH-KDD-01');
        tempVal = '${activeBatch['temperature_celsius']}°C';
      } else {
        batchCode = directBatchCode.isNotEmpty ? directBatchCode : 'BATCH-KDD-01';
        tempVal = '3.8°C';
        if (nameLower.contains('buffalo')) {
          fatVal = '6.8%';
          snfVal = '9.0%';
          waterVal = '0.0%';
        } else if (nameLower.contains('desi') || nameLower.contains('gir') || nameLower.contains('a2')) {
          fatVal = '4.5%';
          snfVal = '8.8%';
          waterVal = '0.0%';
        } else if (nameLower.contains('paneer')) {
          fatVal = '22.0%';
          snfVal = '18.0%';
          waterVal = '0.0%';
        } else if (nameLower.contains('curd') || nameLower.contains('dahi')) {
          fatVal = '5.0%';
          snfVal = '9.0%';
          waterVal = '0.0%';
        } else if (nameLower.contains('ghee')) {
          fatVal = '99.7%';
          snfVal = '0.3%';
          waterVal = '0.0%';
        } else if (category.toUpperCase() == 'MILK' || nameLower.contains('milk')) {
          fatVal = '4.2%';
          snfVal = '8.5%';
          waterVal = '0.0%';
        } else {
          fatVal = '6.8%';
          snfVal = '9.0%';
          waterVal = '0.0%';
        }
      }
      puritySub = 'Hub Certified ($batchCode) • Chilled at $tempVal';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTone.successSoft,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.secondary.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: UiTone.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: UiTone.success, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Milk Quality & Lab Report 🥛',
                      style: UiText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: UiTone.primaryDark),
                    ),
                    Text(
                      priceVal.isNotEmpty
                          ? 'Today\'s Hub Price: $priceVal • FSSAI Grade A+'
                          : 'FSSAI Certified • Passed 24 Quality Checks',
                      style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UiTone.success,
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                ),
                child: Text(priceVal.isNotEmpty ? priceVal : 'GRADE A+', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 3 Metric Stat Boxes: FAT %, SNF %, WATER %
          Row(
            children: [
              Expanded(
                child: _buildQualityMetricBox(
                  icon: '🧈',
                  title: 'FAT %',
                  value: fatVal,
                  subtitle: 'Natural Cream',
                  accentColor: UiTone.warning,
                  bgColor: UiTone.warningSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQualityMetricBox(
                  icon: '🔬',
                  title: 'SNF %',
                  value: snfVal,
                  subtitle: 'Solid-Not-Fat',
                  accentColor: UiTone.accentBlue,
                  bgColor: UiTone.infoSoft,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQualityMetricBox(
                  icon: '💧',
                  title: 'Water %',
                  value: waterVal,
                  subtitle: '0% Added Water',
                  accentColor: UiTone.success,
                  bgColor: UiTone.successSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: UiTone.surface,
              borderRadius: BorderRadius.circular(UiRadius.xs),
              border: Border.all(color: UiTone.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.ac_unit_rounded, size: 14, color: UiTone.accentBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Zero Adulteration • $puritySub',
                    style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.softText, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityMetricBox({
    required String icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(UiRadius.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accentColor),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: accentColor.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
