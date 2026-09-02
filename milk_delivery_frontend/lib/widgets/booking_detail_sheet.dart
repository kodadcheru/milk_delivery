import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/delivery_task_model.dart';
import '../models/live_order_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/live_driver_tracking_screen.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';
import '../theme/ui_format.dart';
import 'delivery_rating_dialog.dart';
import 'delivery_chat_sheet.dart';
import 'order_invoice_sheet.dart';
import 'doorstep_proof_modal.dart';

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
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingDetailSheet(state: state, liveOrder: order),
    );
  }

  static void showForLiveOrder(BuildContext context, AppState state, LiveOrderModel order) =>
      showForExpressOrder(context, state, order);

  static void showForSubscription(BuildContext context, AppState state, DeliveryTaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingDetailSheet(state: state, subscriptionTask: task),
    );
  }

  static void showForSubscriptionTask(BuildContext context, AppState state, DeliveryTaskModel task) =>
      showForSubscription(context, state, task);

  void _callPhone(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery partner phone number not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyOtp(BuildContext context, String otp) {
    Clipboard.setData(ClipboardData(text: otp));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Delivery OTP $otp copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF0D7C66),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpress = liveOrder != null;
    final orderId = isExpress ? liveOrder!.id : 'SUB-DROP-#${subscriptionTask!.id}';
    final status = isExpress ? liveOrder!.status.toUpperCase() : subscriptionTask!.status.toUpperCase();
    final isDelivered = status == 'DELIVERED' || status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED' || status == 'SKIPPED' || status == 'FAILED';
    final isActive = !isDelivered && !isCancelled;

    final activeAddr = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
    final rawAddress = isExpress ? liveOrder!.deliveryAddress : subscriptionTask!.deliveryAddress;
    final displayAddress = (rawAddress.isNotEmpty && rawAddress != 'Doorstep Delivery Location')
        ? rawAddress
        : (activeAddr.isNotEmpty ? activeAddr : 'Doorstep Delivery Location');

    final driverName = isExpress
        ? (liveOrder!.driverName.isNotEmpty ? liveOrder!.driverName : 'Assigned MilkDrop Partner')
        : (subscriptionTask!.driverDetail?.fullName.isNotEmpty == true ? subscriptionTask!.driverDetail!.fullName : 'Assigned MilkDrop Partner');
    final driverPhone = isExpress ? liveOrder!.driverPhone : (subscriptionTask!.driverDetail?.phone ?? '');
    final isDriverAssigned = driverPhone.isNotEmpty;
    final slot = isExpress ? liveOrder!.deliverySlot : subscriptionTask!.slotTime;
    final rawDate = isExpress ? liveOrder!.deliveryDate : subscriptionTask!.deliveryDate;
    final displayDate = rawDate.isNotEmpty ? rawDate : 'Today, ${DateTime.now().day}/${DateTime.now().month}';
    final otp = isExpress ? liveOrder!.deliveryOtp : (subscriptionTask?.id != null ? '${(subscriptionTask!.id * 73) % 9000 + 1000}' : '4821');
    final proofUrl = isExpress ? (liveOrder?.proofImageUrl ?? '') : (subscriptionTask?.proofImageUrl ?? '');

    // Price calculation
    double totalAmount = 0.0;
    if (isExpress) {
      totalAmount = liveOrder!.totalAmount;
    } else if (subscriptionTask != null) {
      totalAmount = (subscriptionTask!.pricePerUnit > 0 ? subscriptionTask!.pricePerUnit : 40.0) *
          (subscriptionTask!.quantity > 0 ? subscriptionTask!.quantity : 1);
    }

    final isRated = isExpress ? state.isOrderRated(liveOrder!.id) : (subscriptionTask != null && state.isTaskRated(subscriptionTask!.id));
    final ratingScore = isExpress ? state.getOrderRating(liveOrder!.id) : (subscriptionTask != null ? state.getTaskRating(subscriptionTask!.id) : 5);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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

          // ── Top Header Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              orderId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isExpress ? const Color(0xFF0D7C66).withValues(alpha: 0.15) : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(UiRadius.pill),
                            ),
                            child: Text(
                              isExpress ? '⚡ 30-MIN EXPRESS' : '🥛 DAILY MORNING DROP',
                              style: TextStyle(
                                color: isExpress ? const Color(0xFF0D7C66) : const Color(0xFF2563EB),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDelivered ? 'Delivered successfully • Cold chain intact' : 'Live Order & Real-Time Tracking',
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
                // ── 1. Hero Live Status Card ──
                _buildHeroStatusCard(context, isDelivered, isCancelled, isActive, slot, displayDate, otp, isExpress),

                const SizedBox(height: 14),

                // ── 2. Assigned Driver Partner Card ──
                _buildDriverPartnerCard(context, driverName, driverPhone, isDriverAssigned, isExpress, orderId),

                const SizedBox(height: 14),

                // ── 3. Doorstep Delivery Address ──
                _buildAddressCard(displayAddress),

                const SizedBox(height: 14),

                // ── 4. Itemized Quick-Commerce Bill Receipt ──
                _buildBillReceiptCard(isExpress, totalAmount),

                // ── 5. Doorstep Photo Proof (if available) ──
                if (proofUrl.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildPhotoProofCard(context, proofUrl),
                ],

                const SizedBox(height: 14),

                // ── 6. Live Order Stepper Timeline ──
                _buildTimelineCard(status, isDelivered, isCancelled),
              ],
            ),
          ),

          // ── Bottom Action Bar (Floating CTA) ──
          _buildBottomActionBar(context, isDelivered, isActive, isExpress, totalAmount, isRated, ratingScore, driverName, driverPhone, slot, displayAddress, orderId),
        ],
      ),
    );
  }

  // ── 1. HERO STATUS CARD ──
  Widget _buildHeroStatusCard(
    BuildContext context,
    bool isDelivered,
    bool isCancelled,
    bool isActive,
    String slot,
    String displayDate,
    String otp,
    bool isExpress,
  ) {
    Color bgGradientStart;
    Color bgGradientEnd;
    Color accentColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    if (isDelivered) {
      bgGradientStart = const Color(0xFF0D7C66);
      bgGradientEnd = const Color(0xFF10A37F);
      accentColor = const Color(0xFF6EE7B7);
      statusTitle = 'DELIVERED AT DOORSTEP';
      statusSubtitle = 'Chilled at 4°C • Verified by Driver Photo';
      statusIcon = Icons.check_circle_rounded;
    } else if (isCancelled) {
      bgGradientStart = const Color(0xFF991B1B);
      bgGradientEnd = const Color(0xFFDC2626);
      accentColor = const Color(0xFFFCA5A5);
      statusTitle = 'DELIVERY CANCELLED / SKIPPED';
      statusSubtitle = 'Wallet amount credited back to account';
      statusIcon = Icons.cancel_rounded;
    } else {
      bgGradientStart = const Color(0xFF0F172A);
      bgGradientEnd = const Color(0xFF1E293B);
      accentColor = const Color(0xFF38BDF8);
      statusTitle = 'OUT FOR DELIVERY 🛵';
      statusSubtitle = 'Partner is en-route • ETA ~12-18 mins';
      statusIcon = Icons.two_wheeler_rounded;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgGradientStart, bgGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bgGradientStart.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$displayDate • $slot',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (isActive)
                  GestureDetector(
                    onTap: () => _copyOtp(context, otp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7C66),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('OTP: ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(otp, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, color: Colors.white70, size: 12),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. ASSIGNED DRIVER PARTNER CARD ──
  Widget _buildDriverPartnerCard(
    BuildContext context,
    String driverName,
    String driverPhone,
    bool isDriverAssigned,
    bool isExpress,
    String orderId,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(Icons.delivery_dining_rounded, color: Color(0xFF0D7C66), size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        driverName,
                        style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: Color(0xFF0D7C66), size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '4.9 ★ • Electric Scooter Fleet',
                      style: UiText.caption.copyWith(color: UiTone.softText, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isDriverAssigned) ...[
            IconButton.filledTonal(
              onPressed: () => _callPhone(context, driverPhone),
              icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF0D7C66)),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.1)),
              tooltip: 'Call Driver',
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              onPressed: () {
                DeliveryChatSheet.show(
                  context,
                  taskId: subscriptionTask?.id,
                  orderId: isExpress ? liveOrder?.id : null,
                  driverName: driverName,
                  driverPhone: driverPhone,
                  customerName: state.currentUser?.name ?? 'Customer',
                  customerPhone: state.currentUser?.phone ?? '',
                  orderTitle: 'Order $orderId',
                  deliveryAddress: isExpress ? liveOrder!.deliveryAddress : subscriptionTask!.deliveryAddress,
                );
              },
              icon: const Icon(Icons.forum_rounded, size: 16, color: Color(0xFF0D7C66)),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF0D7C66).withValues(alpha: 0.1)),
              tooltip: 'Live In-App Chat',
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. ADDRESS CARD ──
  Widget _buildAddressCard(String address) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.place_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Doorstep Delivery Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 3),
                Text(address, style: UiText.bodyStrong.copyWith(fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. ITEMIZED BILL RECEIPT CARD ──
  Widget _buildBillReceiptCard(bool isExpress, double totalAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Itemized Bill Receipt', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                ),
                child: const Text('PAID ONLINE ✓', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF0D7C66))),
              ),
            ],
          ),
          const Divider(height: 20),

          // Items List
          if (isExpress && liveOrder!.items.isNotEmpty) ...[
            ...liveOrder!.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: UiTone.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(item.product.icon.isNotEmpty ? item.product.icon : '🥛', style: const TextStyle(fontSize: 16))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
                            Text(
                              'Qty: ${item.quantity}${item.product.unitQuantity.isNotEmpty ? " (${item.product.unitQuantity})" : ""} × ${UiFormat.price(item.unitPrice)}',
                              style: UiText.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(UiFormat.price(item.totalPrice), style: UiText.bodyStrong.copyWith(fontSize: 13)),
                    ],
                  ),
                )),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: UiTone.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(child: Text('🥛', style: TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subscriptionTask?.productName ?? 'Farm Fresh A2 Cow Milk', style: UiText.bodyStrong.copyWith(fontSize: 12.5)),
                      Text('Daily Subscription Drop', style: UiText.caption.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                Text(UiFormat.price(totalAmount), style: UiText.bodyStrong.copyWith(fontSize: 13)),
              ],
            ),
          ],

          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cold-Chain Delivery Fee', style: UiText.caption.copyWith(fontSize: 11.5)),
              const Text('FREE ₹0', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grand Total', style: UiText.h2.copyWith(fontSize: 14.5)),
              Text(UiFormat.price(totalAmount), style: UiText.h2.copyWith(fontSize: 16, color: const Color(0xFF0D7C66))),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. DOORSTEP PHOTO PROOF CARD ──
  Widget _buildPhotoProofCard(BuildContext context, String proofUrl) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Doorstep Delivery Proof 📸', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: () => DoorstepProofModal.show(context, imageUrl: proofUrl),
                child: const Text('View Full Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D7C66))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              proofUrl,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: UiTone.surfaceMuted,
                child: const Center(child: Icon(Icons.image_not_supported_rounded, color: UiTone.softText)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. TIMELINE CARD ──
  Widget _buildTimelineCard(String status, bool isDelivered, bool isCancelled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTone.surfaceBorder),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Delivery Progress', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _buildTimelineStep('1', 'Order Placed & Confirmed', 'Batch allocated from local Kodad depot', true),
          _buildTimelineStep('2', 'Quality Certified & Packed', 'Chilled to 4°C in insulated bag', isDelivered || status == 'OUT_FOR_DELIVERY'),
          _buildTimelineStep('3', 'Out for Delivery 🛵', 'Assigned partner carrying fresh supply', isDelivered || status == 'OUT_FOR_DELIVERY'),
          _buildTimelineStep('4', 'Delivered at Doorstep 🥛', 'Placed in doorstep bag with photo proof', isDelivered, isLast: true),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String stepNumber, String title, String subtitle, bool isCompleted, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF0D7C66) : UiTone.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? const Color(0xFF0D7C66) : UiTone.surfaceBorder),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                    : Text(stepNumber, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: UiTone.softText)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isCompleted ? const Color(0xFF0D7C66) : UiTone.surfaceBorder,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isCompleted ? UiTone.ink : UiTone.softText,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isCompleted ? const Color(0xFF64748B) : UiTone.softText,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  // ── 7. BOTTOM FLOATING ACTION BAR ──
  Widget _buildBottomActionBar(
    BuildContext context,
    bool isDelivered,
    bool isActive,
    bool isExpress,
    double totalAmount,
    bool isRated,
    int ratingScore,
    String driverName,
    String driverPhone,
    String slot,
    String displayAddress,
    String orderId,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: UiTone.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Invoice Button
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  OrderInvoiceSheet.show(
                    context,
                    order: liveOrder,
                    task: subscriptionTask,
                    orderId: orderId,
                    orderDate: isExpress ? liveOrder!.deliveryDate : (subscriptionTask?.deliveryDate ?? 'Today'),
                    slotTime: slot,
                    address: displayAddress,
                    totalAmount: totalAmount,
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0D7C66)),
                label: const Text('Invoice 🧾', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0D7C66))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0D7C66)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Primary Action Button (Live Track / Rate)
          if (isActive) ...[
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => LiveDriverTrackingScreen(
                          state: state,
                          liveOrder: liveOrder,
                          subscriptionTask: subscriptionTask,
                          orderTitle: 'Delivery $orderId',
                          deliveryAddress: displayAddress,
                          driverName: driverName,
                          driverPhone: driverPhone,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.radar_rounded, size: 18, color: Colors.white),
                  label: const Text('Live Radar Track 📍', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ] else if (isDelivered) ...[
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 46,
                child: isRated
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text('Rated $ratingScore★ ✓', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0D7C66))),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          DeliveryRatingDialog.show(
                            context,
                            state: state,
                            orderId: isExpress ? liveOrder!.id : null,
                            taskId: !isExpress ? subscriptionTask?.id : null,
                            productName: isExpress
                                ? (liveOrder!.items.isNotEmpty ? liveOrder!.items.first.product.name : 'Express Order')
                                : (subscriptionTask?.productName ?? 'Morning Milk Delivery'),
                            driverName: driverName,
                            deliveryDate: isExpress ? liveOrder!.deliveryDate : (subscriptionTask?.deliveryDate ?? 'Today'),
                          );
                        },
                        icon: const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                        label: const Text('Rate Delivery ⭐', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7C66),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
