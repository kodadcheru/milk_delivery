import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/app_state.dart';
import 'home/home_location_sheet.dart';
import 'booking_detail_sheet.dart';
import '../theme/ui_tokens.dart';


class FloatingCartBar extends StatelessWidget {
  final AppState state;

  const FloatingCartBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.totalCartItemCount == 0) return const SizedBox.shrink();

    final count = state.totalCartItemCount;
    final total = state.totalCartPrice;
    final items = state.cartProductsList;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(UiRadius.lg),
      shadowColor: UiTone.primary.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => showCheckoutSheet(context, state),
        borderRadius: BorderRadius.circular(UiRadius.lg),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [UiTone.ink, Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(UiRadius.lg),
              border: Border.all(color: UiTone.secondary.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Row(
              children: [
                // Item Preview Icons & Count Badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: UiTone.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(UiRadius.sm),
                        border: Border.all(color: UiTone.primary),
                      ),
                      child: Row(
                        children: items.take(3).map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Text(entry.key.icon, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: UiTone.secondary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Subtotal Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        state.isTelugu ? 'ఉచిత 06:00 AM డెలివరీ' : 'Free 06:00 AM Delivery',
                        style: const TextStyle(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // View Cart Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: UiTone.primary,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Text(state.tr('view_cart'), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static void showCheckoutSheet(BuildContext context, AppState state) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1)); // Locked to Tomorrow for Express Schedule
    String slot = '06:00 AM - 08:00 AM';
    final slotController = TextEditingController(text: slot);
    String _deliveryMode = 'INSTANT';
    final initialWallet = state.currentUser?.walletBalance ?? 0.0;
    final isCodAllowed = state.storefrontConfig.isCodEnabled;
    final isWalletAllowed = state.storefrontConfig.isWalletEnabled;
    String _paymentMethod = (isWalletAllowed && initialWallet >= state.totalCartPrice && initialWallet > 0)
        ? 'WALLET'
        : (isCodAllowed ? 'COD' : (isWalletAllowed ? 'WALLET' : 'COD'));

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String formatDate(DateTime d) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    bool _isSubmitting = false;
    bool _hasRefreshedConfig = false;
    Timer? syncTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          syncTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
            if (ctx.mounted) {
              state.refreshStorefrontConfig().then((cfg) {
                if (ctx.mounted) {
                  setSheetState(() {
                    if (_paymentMethod == 'WALLET' && !cfg.isWalletEnabled && cfg.isCodEnabled) {
                      _paymentMethod = 'COD';
                    } else if (_paymentMethod == 'COD' && !cfg.isCodEnabled && cfg.isWalletEnabled) {
                      _paymentMethod = 'WALLET';
                    }
                  });
                }
              });
            }
          });

          if (!_hasRefreshedConfig) {
            _hasRefreshedConfig = true;
            state.refreshStorefrontConfig().then((cfg) {
              if (ctx.mounted) {
                setSheetState(() {
                  if (_paymentMethod == 'WALLET' && !cfg.isWalletEnabled) {
                    if (cfg.isCodEnabled) {
                      _paymentMethod = 'COD';
                    }
                  } else if (_paymentMethod == 'COD' && !cfg.isCodEnabled) {
                    if (cfg.isWalletEnabled) {
                      _paymentMethod = 'WALLET';
                    }
                  }
                });
              }
            });
          }
          final items = state.cartProductsList;
          final subtotal = state.totalCartPrice;
          final platformFee = state.storefrontConfig.platformFee;
          final taxPct = state.storefrontConfig.taxPercentage;
          final taxAmount = (subtotal * (taxPct / 100.0));
          final isFreeDelivery = state.storefrontConfig.freeDeliveryThreshold > 0 && subtotal >= state.storefrontConfig.freeDeliveryThreshold;
          final deliveryFee = isFreeDelivery ? 0.0 : state.storefrontConfig.deliveryFee;
          final total = subtotal + platformFee + taxAmount + deliveryFee;

          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🛍️', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            state.isTelugu
                                ? 'చెక్‌అవుట్ (${state.totalCartItemCount} వస్తువులు)'
                                : 'Checkout (${state.totalCartItemCount} items)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: UiTone.ink),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Delivery Mode Comparative Selector (Instant vs Next-Day) ──
                          Row(
                            children: [
                              // Instant Express Card
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() => _deliveryMode = 'INSTANT');
                                  },
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _deliveryMode == 'INSTANT'
                                          ? const Color(0xFFE6F5F0)
                                          : UiTone.surfaceMuted,
                                      borderRadius: BorderRadius.circular(UiRadius.md),
                                      border: Border.all(
                                        color: _deliveryMode == 'INSTANT'
                                            ? const Color(0xFF0D7C66)
                                            : UiTone.surfaceBorder,
                                        width: _deliveryMode == 'INSTANT' ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('⚡', style: TextStyle(fontSize: 20)),
                                            if (_deliveryMode == 'INSTANT')
                                              const Icon(Icons.check_circle_rounded, color: Color(0xFF0D7C66), size: 18)
                                            else
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.grey.shade400),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          state.isTelugu ? 'తక్షణ డెలివరీ' : 'Instant Express',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: _deliveryMode == 'INSTANT' ? const Color(0xFF0D7C66) : UiTone.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          state.isTelugu ? '~25 నిమిషాల్లో' : 'In ~25-30 mins',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            color: _deliveryMode == 'INSTANT' ? const Color(0xFF0D7C66) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Next-Day Drop Card
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() {
                                      _deliveryMode = 'SCHEDULED';
                                      selectedDate = DateTime.now().add(const Duration(days: 1));
                                      slot = '06:00 AM - 08:00 AM';
                                      slotController.text = slot;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _deliveryMode == 'SCHEDULED'
                                          ? const Color(0xFFE6F5F0)
                                          : UiTone.surfaceMuted,
                                      borderRadius: BorderRadius.circular(UiRadius.md),
                                      border: Border.all(
                                        color: _deliveryMode == 'SCHEDULED'
                                            ? const Color(0xFF0D7C66)
                                            : UiTone.surfaceBorder,
                                        width: _deliveryMode == 'SCHEDULED' ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('🌅', style: TextStyle(fontSize: 20)),
                                            if (_deliveryMode == 'SCHEDULED')
                                              const Icon(Icons.check_circle_rounded, color: Color(0xFF0D7C66), size: 18)
                                            else
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.grey.shade400),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          state.isTelugu ? 'రేపటి షెడ్యూల్' : 'Next-Day Drop',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: _deliveryMode == 'SCHEDULED' ? const Color(0xFF0D7C66) : UiTone.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          state.isTelugu ? 'ఉదయం 06:00 AM' : 'Tomorrow 06:00 AM',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            color: _deliveryMode == 'SCHEDULED' ? const Color(0xFF0D7C66) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Dynamic Delivery Mode Context Banner
                          if (_deliveryMode == 'INSTANT') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF044E3A), Color(0xFF0D7C66)],
                                ),
                                borderRadius: BorderRadius.circular(UiRadius.md),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x180D7C66), blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state.isTelugu ? 'ప్రాధాన్యత తక్షణ డెలివరీ' : 'Priority Instant Dispatch',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          state.isTelugu
                                              ? 'సమీప హబ్ నుండి డెలివరీ భాగస్వామి నేరుగా డెలివరీ చేస్తారు (~25 నిమిషాలు)'
                                              : 'Assigned to nearest delivery partner • Live tracking available',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Cart Items List ──
                          ...items.map((entry) {
                            final product = entry.key;
                            final qty = entry.value;
                            final itemTotal = product.pricePerUnit * qty;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: UiTone.shellBackground,
                                borderRadius: BorderRadius.circular(UiRadius.md),
                                border: Border.all(color: UiTone.surfaceBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: UiTone.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(UiRadius.sm),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(product.icon, style: const TextStyle(fontSize: 24)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(product.unitQuantity, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${itemTotal.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: UiTone.primary),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Stepper
                                  Container(
                                    decoration: BoxDecoration(
                      color: UiTone.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            state.decreaseCartQty(product);
                                            setSheetState(() {});
                                            if (state.totalCartItemCount == 0) {
                                              Navigator.pop(ctx);
                                            }
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.remove, size: 15, color: UiTone.primary),
                                          ),
                                        ),
                                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        InkWell(
                                          onTap: () {
                                            state.addToCart(product);
                                            setSheetState(() {});
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.add, size: 15, color: UiTone.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 14),

                          if (_deliveryMode == 'SCHEDULED') ...[
                            // ── 1. Scheduled Delivery Date (Locked to Tomorrow) ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  state.isTelugu ? '1. డెలివరీ తేదీ 📅:' : '1. Scheduled Delivery Date 📅:',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: UiTone.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(UiRadius.xs),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_clock_rounded, size: 13, color: UiTone.primary),
                                      const SizedBox(width: 4),
                                      Text(state.isTelugu ? 'రేపు మాత్రమే' : 'Tomorrow Only', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: UiTone.primary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Dedicated Tomorrow Card
                            Builder(
                              builder: (context) {
                                final tomorrow = DateTime.now().add(const Duration(days: 1));
                                selectedDate = tomorrow; // Enforce Tomorrow

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: UiTone.surface,
                                    borderRadius: BorderRadius.circular(UiRadius.md),
                                    border: Border.all(color: UiTone.primary, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: UiTone.primary.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: UiTone.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.event_available_rounded, color: UiTone.primary, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  state.isTelugu ? 'రేపు (${weekdayNames[tomorrow.weekday - 1]})' : 'Tomorrow (${weekdayNames[tomorrow.weekday - 1]})',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.ink),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(state.isTelugu ? '⚡ తదుపరి రోజు' : '⚡ NEXT-DAY DROP', style: const TextStyle(color: Color(0xFF0D7C66), fontSize: 9, fontWeight: FontWeight.w900)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              state.isTelugu
                                                  ? '${tomorrow.day} ${monthNames[tomorrow.month - 1]} ${tomorrow.year} • తాజా ఫారం డెలివరీ హామీ'
                                                  : '${tomorrow.day} ${monthNames[tomorrow.month - 1]} ${tomorrow.year} • Farm fresh delivery guaranteed',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.check_circle_rounded, color: UiTone.primary, size: 22),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // ── 2. Delivery Time Slot (3 Slots: Morning, Afternoon, Evening) ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  state.isTelugu ? '2. డెలివరీ సమయం ⏰:' : '2. Delivery Time Slot ⏰:',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(UiRadius.xs),
                                  ),
                                  child: Text(
                                    state.isTelugu ? '3 సమయాలు అందుబాటులో ఉన్నాయి' : '3 Slots Available',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 3 Slots Selector
                            Builder(
                              builder: (context) {
                                final expressSlots = [
                                  {
                                    'id': 'MORNING',
                                    'title': 'Morning',
                                    'time': '06:00 AM - 08:00 AM',
                                    'icon': '☀️',
                                    'tag': 'Fresh Drop',
                                    'color': const Color(0xFF0D7C66),
                                  },
                                  {
                                    'id': 'AFTERNOON',
                                    'title': 'Afternoon',
                                    'time': '12:00 PM - 02:00 PM',
                                    'icon': '🌤️',
                                    'tag': 'Midday',
                                    'color': const Color(0xFFD97706),
                                  },
                                  {
                                    'id': 'EVENING',
                                    'title': 'Evening',
                                    'time': '06:00 PM - 08:00 PM',
                                    'icon': '🌙',
                                    'tag': 'Night Batch',
                                    'color': const Color(0xFF7C3AED),
                                  },
                                ];

                                return Row(
                                  children: expressSlots.map((s) {
                                    final slotTime = s['time'] as String;
                                    final isSelected = slot == slotTime;
                                    final slotColor = s['color'] as Color;

                                    return Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setSheetState(() {
                                            slot = slotTime;
                                            slotController.text = slotTime;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          margin: EdgeInsets.only(
                                            right: s['id'] != 'EVENING' ? 8 : 0,
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? slotColor.withValues(alpha: 0.1) : UiTone.surfaceMuted,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isSelected ? slotColor : const Color(0xFFCBD5E1),
                                              width: isSelected ? 2 : 1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: slotColor.withValues(alpha: 0.15),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(s['icon'] as String, style: const TextStyle(fontSize: 22)),
                                              const SizedBox(height: 4),
                                              Text(
                                                s['title'] as String,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12.5,
                                                  color: isSelected ? slotColor : UiTone.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                slotTime.split(' - ').first,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                  color: isSelected ? slotColor : Colors.grey[700],
                                                ),
                                              ),
                                              Text(
                                                'to ${slotTime.split(" - ").last}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: isSelected ? slotColor.withValues(alpha: 0.8) : Colors.grey[500],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? slotColor : Colors.grey[300],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  s['tag'] as String,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.grey[700],
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Delivery Location Strip ──
                          AnimatedBuilder(
                            animation: state,
                            builder: (context, _) {
                              final currentAddr = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
                              final tag = state.activeAddress?.title.toUpperCase() ?? 'DOORSTEP';
                              final icon = state.activeAddress?.icon ?? '📍';
                              final savedAddrs = state.savedAddresses;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(icon, style: const TextStyle(fontSize: 20)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(state.isTelugu ? 'డెలివరీ చిరునామా:' : 'Deliver to:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF047857))),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFDCFCE7),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(tag, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                currentAddr,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: UiTone.ink),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            HomeLocationSheet.show(context, state);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            backgroundColor: UiTone.primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                                          ),
                                          icon: const Icon(Icons.edit_location_alt_rounded, size: 13, color: Colors.white),
                                          label: Text(state.isTelugu ? 'మార్చండి' : 'Change', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    if (savedAddrs.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      const Divider(height: 10, color: Color(0xFFBBF7D0)),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: savedAddrs.map((a) {
                                            final isSel = state.activeAddress?.id == a.id;
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: InkWell(
                                                onTap: () => state.selectActiveAddress(a),
                                                borderRadius: BorderRadius.circular(UiRadius.xs),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSel ? UiTone.primary : Colors.white,
                                                    borderRadius: BorderRadius.circular(UiRadius.xs),
                                                    border: Border.all(color: isSel ? UiTone.primary : const Color(0xFF86EFAC)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Text(a.icon, style: const TextStyle(fontSize: 11)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        a.title,
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: isSel ? Colors.white : UiTone.ink,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),

                          // ── Payment Method Selector (Prepaid Wallet vs Cash on Delivery) ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                state.isTelugu ? 'చెల్లింపు విధానం 💳:' : 'Payment Method 💳:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  state.isTelugu ? 'సురక్షితమైన చెల్లింపులు' : '100% Secure',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Option 1: Prepaid Wallet Card
                          Builder(
                            builder: (context) {
                              final isWalletEnabled = state.storefrontConfig.isWalletEnabled;
                              final walletBal = state.currentUser?.walletBalance ?? 0.0;
                              final isWalletSelected = _paymentMethod == 'WALLET' && isWalletEnabled;
                              final hasSufficientBal = walletBal >= total;
                              final deficit = total - walletBal;

                              return Opacity(
                                opacity: isWalletEnabled ? 1.0 : 0.45,
                                child: InkWell(
                                  onTap: isWalletEnabled
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          setSheetState(() => _paymentMethod = 'WALLET');
                                        }
                                      : () {
                                          HapticFeedback.lightImpact();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(state.isTelugu
                                                  ? 'వాలెట్ చెల్లింపు ప్రస్తుతం స్టోర్ అడ్మిన్ ద్వారా నిలిపివేయబడింది.'
                                                  : 'Pamba Wallet payment is currently disabled by store admin.'),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: const Color(0xFFDC2626),
                                            ),
                                          );
                                        },
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: !isWalletEnabled
                                          ? const Color(0xFFF1F5F9)
                                          : (isWalletSelected ? const Color(0xFFE6F5F0) : UiTone.surfaceMuted),
                                      borderRadius: BorderRadius.circular(UiRadius.md),
                                      border: Border.all(
                                        color: !isWalletEnabled
                                            ? const Color(0xFFCBD5E1)
                                            : (isWalletSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder),
                                        width: isWalletSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: !isWalletEnabled
                                                    ? Colors.grey.shade400
                                                    : (isWalletSelected ? const Color(0xFF0D7C66) : Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        state.isTelugu ? 'పాంబ వాలెట్' : 'Pamba Wallet',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 13,
                                                          color: !isWalletEnabled
                                                              ? Colors.grey.shade500
                                                              : (isWalletSelected ? const Color(0xFF0D7C66) : UiTone.ink),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (!isWalletEnabled)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFEE2E2),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Text(
                                                            'Disabled',
                                                            style: TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.w800,
                                                              color: Color(0xFFDC2626),
                                                            ),
                                                          ),
                                                        )
                                                      else
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: hasSufficientBal ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            'Bal: ₹${walletBal.toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w800,
                                                              color: hasSufficientBal ? const Color(0xFF059669) : const Color(0xFFD97706),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    !isWalletEnabled
                                                        ? (state.isTelugu ? 'స్టోర్ ద్వారా నిలిపివేయబడింది' : 'Temporarily disabled by store')
                                                        : (hasSufficientBal
                                                            ? (state.isTelugu ? 'తగినంత నిల్వ ఉంది • 1-ట్యాప్ చెల్లింపు' : 'Sufficient balance • 1-Tap auto-debit')
                                                            : (state.isTelugu ? 'నిల్వ తక్కువగా ఉంది (₹${deficit.toStringAsFixed(0)} అవసరం)' : 'Low balance (₹${deficit.toStringAsFixed(0)} short)')),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: !isWalletEnabled
                                                          ? Colors.grey.shade500
                                                          : (hasSufficientBal ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!isWalletEnabled) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.block_rounded, color: Colors.grey.shade500, size: 14),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      state.isTelugu ? 'అందుబాటులో లేదు' : 'Unavailable',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else if (!hasSufficientBal) ...[
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  _showQuickTopUpDialog(
                                                    context,
                                                    state,
                                                    deficit,
                                                    () => setSheetState(() {}),
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0D7C66),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        state.isTelugu ? 'టాప్ అప్' : 'Top Up',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ] else ...[
                                              Icon(
                                                isWalletSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                color: isWalletSelected ? const Color(0xFF0D7C66) : Colors.grey.shade400,
                                                size: 20,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Option 2: Cash on Delivery / UPI at Doorstep Card
                          Builder(
                            builder: (context) {
                              final isCodEnabled = state.storefrontConfig.isCodEnabled;
                              final isCodSelected = _paymentMethod == 'COD' && isCodEnabled;

                              return Opacity(
                                opacity: isCodEnabled ? 1.0 : 0.45,
                                child: InkWell(
                                  onTap: isCodEnabled
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          setSheetState(() => _paymentMethod = 'COD');
                                        }
                                      : () {
                                          HapticFeedback.lightImpact();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(state.isTelugu
                                                  ? 'క్యాష్ ఆన్ డెలివరీ ప్రస్తుతం స్టోర్ అడ్మిన్ ద్వారా నిలిపివేయబడింది.'
                                                  : 'Cash on Delivery is currently disabled by store admin.'),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: const Color(0xFFDC2626),
                                            ),
                                          );
                                        },
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: !isCodEnabled
                                          ? const Color(0xFFF1F5F9)
                                          : (isCodSelected ? const Color(0xFFE6F5F0) : UiTone.surfaceMuted),
                                      borderRadius: BorderRadius.circular(UiRadius.md),
                                      border: Border.all(
                                        color: !isCodEnabled
                                            ? const Color(0xFFCBD5E1)
                                            : (isCodSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder),
                                        width: isCodSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: !isCodEnabled
                                                ? Colors.grey.shade400
                                                : (isCodSelected ? const Color(0xFF0D7C66) : Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    state.isTelugu ? 'క్యాష్ / UPI ఆన్ డెలివరీ' : 'Cash / UPI on Delivery',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 13,
                                                      color: !isCodEnabled
                                                          ? Colors.grey.shade500
                                                          : (isCodSelected ? const Color(0xFF0D7C66) : UiTone.ink),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (!isCodEnabled)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEE2E2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Disabled',
                                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                                                      ),
                                                    )
                                                  else
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        state.isTelugu ? 'రుసుము లేదు' : 'No Extra Fee',
                                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                !isCodEnabled
                                                    ? (state.isTelugu ? 'స్టోర్ ద్వారా నిలిపివేయబడింది' : 'Temporarily disabled by store')
                                                    : (state.isTelugu ? 'డోర్‌స్టెప్ వద్ద నగదు లేదా QR స్కాన్ ద్వారా చెల్లించండి' : 'Pay via Cash, GPay, PhonePe or Paytm QR at doorstep'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: !isCodEnabled ? Colors.grey.shade500 : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isCodEnabled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.block_rounded, color: Colors.grey.shade500, size: 14),
                                                const SizedBox(width: 3),
                                                Text(
                                                  state.isTelugu ? 'అందుబాటులో లేదు' : 'Unavailable',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Icon(
                                            isCodSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                            color: isCodSelected ? const Color(0xFF0D7C66) : Colors.grey.shade400,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Itemized Bill Breakdown ──
                          Builder(
                            builder: (context) {
                              final walletBal = state.currentUser?.walletBalance ?? 0.0;
                              final walletDeduction = _paymentMethod == 'WALLET'
                                  ? (walletBal >= total ? total : walletBal)
                                  : 0.0;
                              final netToPay = total - walletDeduction;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: UiTone.shellBackground,
                                  borderRadius: BorderRadius.circular(UiRadius.md),
                                  border: Border.all(color: UiTone.surfaceBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.receipt_long_rounded, size: 16, color: UiTone.ink),
                                        const SizedBox(width: 8),
                                        Text(
                                          state.isTelugu ? 'బిల్లు వివరాలు' : 'Bill Breakdown',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: UiTone.ink),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildBillRow(
                                      state.isTelugu ? 'వస్తువుల మొత్తం (MRP)' : 'Item Subtotal (MRP)',
                                      '₹${subtotal.toStringAsFixed(0)}',
                                    ),
                                    _buildBillRow(
                                      state.isTelugu
                                          ? 'డెలివరీ భాగస్వామి రుసుము (${_deliveryMode == "INSTANT" ? "తక్షణ" : "షెడ్యూల్"})'
                                          : 'Delivery Partner Fee',
                                      deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(0)}' : (state.isTelugu ? 'ఉచితం' : 'FREE'),
                                      isHighlight: deliveryFee == 0,
                                    ),
                                    _buildBillRow(
                                      state.isTelugu ? 'ప్లాట్‌ఫారమ్ రుసుము' : 'Platform Fee',
                                      platformFee > 0 ? '₹${platformFee.toStringAsFixed(0)}' : (state.isTelugu ? 'ఉచితం' : 'FREE'),
                                      isHighlight: platformFee == 0,
                                    ),
                                    if (taxAmount > 0 || taxPct > 0)
                                      _buildBillRow(
                                        state.isTelugu ? 'పన్నులు & ఛార్జీలు (${taxPct.toStringAsFixed(1)}% GST)' : 'Taxes & Charges (${taxPct.toStringAsFixed(1)}% GST)',
                                        '₹${taxAmount.toStringAsFixed(1)}',
                                      ),
                                    _buildBillRow(
                                      state.isTelugu ? 'ప్యాకేజింగ్ & నాణ్యతా రుసుము' : 'Packaging & Handling',
                                      state.isTelugu ? 'రద్దు చేయబడింది' : 'Waived',
                                      isHighlight: true,
                                    ),
                                    if (_paymentMethod == 'WALLET' && walletDeduction > 0) ...[
                                      _buildBillRow(
                                        state.isTelugu ? 'వాలెట్ నుండి తగ్గింపు' : 'Paid via Pamba Wallet',
                                        '-₹${walletDeduction.toStringAsFixed(0)}',
                                        isSuccess: true,
                                        subtitle: state.isTelugu ? 'వాలెట్ బ్యాలెన్స్ ఉపయోగించబడింది' : 'Deducted from wallet balance',
                                      ),
                                    ],
                                    const Divider(height: 18),
                                    _buildBillRow(
                                      state.isTelugu ? 'మొత్తం చెల్లించాల్సింది' : 'To Pay',
                                      netToPay <= 0 ? (state.isTelugu ? '₹0 (చెల్లించబడింది)' : '₹0 (Paid)') : '₹${netToPay.toStringAsFixed(0)}',
                                      isBold: true,
                                      subtitle: _paymentMethod == 'WALLET' && walletBal >= total
                                          ? (state.isTelugu ? 'పూర్తిగా వాలెట్ ద్వారా చెల్లించబడుతుంది' : 'Fully covered by wallet')
                                          : (_paymentMethod == 'COD' ? (state.isTelugu ? 'డోర్‌స్టెప్ వద్ద చెల్లించండి' : 'Pay at doorstep') : null),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),

                  // ── Sticky Checkout Bottom Bar ──
                  Container(
                    padding: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_isSubmitting) return;

                              if (state.activeAddress == null && (state.currentDeliveryAddress == 'Select Delivery Location' || state.currentDeliveryAddress.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(state.isTelugu
                                      ? 'దయచేసి మీ ఆర్డర్‌ను ఇచ్చే ముందు డెలివరీ చిరునామాను ఎంచుకోండి'
                                      : 'Please select a delivery address before placing your order'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ));
                                return;
                              }

                              final freshConfig = await state.refreshStorefrontConfig();
                              if (!context.mounted) return;
                              var effectivePaymentMethod = _paymentMethod;
                              final walletBalance = state.currentUser?.walletBalance ?? 0.0;
                              final isCodAllowed = freshConfig.isCodEnabled;
                              final isWalletAllowed = freshConfig.isWalletEnabled;

                              if (!isCodAllowed && !isWalletAllowed) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(state.isTelugu
                                      ? 'చెల్లింపు విధానాలు ప్రస్తుతం నిర్వహణలో ఉన్నాయి. దయచేసి సహాయాన్ని సంప్రదించండి.'
                                      : 'Payment methods are currently unavailable. Please contact support.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ));
                                return;
                              }

                              if (effectivePaymentMethod == 'COD' && !isCodAllowed) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(state.isTelugu
                                      ? 'క్యాష్ ఆన్ డెలివరీ ప్రస్తుతం నిలిపివేయబడింది. దయచేసి వాలెట్ ఉపయోగించండి.'
                                      : 'Cash on Delivery (COD) is currently disabled. Please use Pamba Wallet.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ));
                                return;
                              }

                              if (effectivePaymentMethod == 'WALLET' && !isWalletAllowed) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(state.isTelugu
                                      ? 'వాలెట్ చెల్లింపు ప్రస్తుతం నిలిపివేయబడింది. దయచేసి క్యాష్ ఆన్ డెలివరీ ఎంచుకోండి.'
                                      : 'Pamba Wallet is currently disabled. Please select Cash on Delivery.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ));
                                return;
                              }

                              if (_paymentMethod == 'WALLET' && walletBalance < total) {
                                if (isCodAllowed) {
                                  effectivePaymentMethod = 'COD';
                                  setSheetState(() => _paymentMethod = 'COD');
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(state.isTelugu
                                        ? 'వాలెట్ బ్యాలెన్స్ తక్కువగా ఉంది, క్యాష్ ఆన్ డెలివరీ (COD) ఎంచుకోబడింది.'
                                        : 'Wallet balance insufficient (₹${walletBalance.toStringAsFixed(0)}). Switched to Cash on Delivery (COD).'),
                                    backgroundColor: UiTone.primary,
                                    duration: const Duration(seconds: 3),
                                  ));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(state.isTelugu
                                        ? 'వాలెట్ బ్యాలెన్స్ తక్కువగా ఉంది (₹${walletBalance.toStringAsFixed(0)}). దయచేసి టాప్ అప్ చేయండి.'
                                        : 'Insufficient wallet balance (₹${walletBalance.toStringAsFixed(0)}). Please top up your wallet.'),
                                    backgroundColor: const Color(0xFFDC2626),
                                    duration: const Duration(seconds: 3),
                                  ));
                                  return;
                                }
                              }

                              setSheetState(() => _isSubmitting = true);
                              final currentAddr = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
                              try {
                                final order = await state.placeExpressOrder(
                                  deliveryType: _deliveryMode,
                                  deliveryDate: _deliveryMode == 'INSTANT' ? formatDate(DateTime.now()) : formatDate(selectedDate),
                                  deliverySlot: _deliveryMode == 'INSTANT' ? 'Instant Delivery' : slot,
                                  deliveryAddress: currentAddr,
                                  paymentMethod: effectivePaymentMethod,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: UiTone.primary,
                                      content: Text(
                                        _deliveryMode == 'INSTANT'
                                            ? '⚡ Order #${order.id} Placed for Instant Delivery!'
                                            : '🎉 Order #${order.id} Scheduled for ${formatDate(selectedDate)} ($slot)!'
                                      ),
                                    ),
                                  );
                                  state.setTab(3); // Orders / Bookings Tab
                                  BookingDetailSheet.showForExpressOrder(context, state, order);
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  final errorMsg = e.toString().replaceFirst('Exception: ', '');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFFDC2626),
                                      content: Text('❌ $errorMsg'),
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setSheetState(() => _isSubmitting = false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D7C66),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _paymentMethod == 'COD'
                                            ? Icons.payments_rounded
                                            : (_deliveryMode == 'INSTANT' ? Icons.flash_on_rounded : Icons.event_available_rounded),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _deliveryMode == 'INSTANT'
                                            ? (_paymentMethod == 'COD'
                                                ? (state.isTelugu ? 'తక్షణ COD ఆర్డర్ — ₹${total.toStringAsFixed(0)} 💵' : 'Place COD Instant Drop — ₹${total.toStringAsFixed(0)}')
                                                : (state.isTelugu ? 'చెల్లించి తక్షణ ఆర్డర్ చేయండి — ₹${total.toStringAsFixed(0)} ⚡' : 'Pay & Place Instant Order — ₹${total.toStringAsFixed(0)}'))
                                            : (_paymentMethod == 'COD'
                                                ? (state.isTelugu ? 'రేపటికి ఆర్డర్ షెడ్యూల్ చేయండి — ₹${total.toStringAsFixed(0)} 💵' : 'Schedule COD for Tomorrow — ₹${total.toStringAsFixed(0)}')
                                                : (state.isTelugu ? 'రేపటికి చెల్లించి షెడ్యూల్ చేయండి — ₹${total.toStringAsFixed(0)} 🌅' : 'Pay & Schedule for Tomorrow — ₹${total.toStringAsFixed(0)}')),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 12, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text(
                              '100% Farm Fresh Guarantee • Contactless Doorstep Drop',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      syncTimer?.cancel();
    });
  }

  static void _showQuickTopUpDialog(BuildContext context, AppState state, double deficit, VoidCallback onRecharged) {
    final amounts = [deficit < 100 ? 100.0 : deficit, 200.0, 500.0, 1000.0];
    final selectedAmt = ValueNotifier<double>(amounts.first);
    final isProcessing = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D7C66), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isTelugu ? 'వాలెట్ తక్షణ రీఛార్జ్' : 'Quick Wallet Recharge',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        state.isTelugu ? 'ఆర్డర్ పూర్తి చేయడానికి నిల్వను జోడించండి' : 'Add funds to complete your order seamlessly',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              state.isTelugu ? 'మొత్తం ఎంచుకోండి:' : 'Select Amount:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<double>(
              valueListenable: selectedAmt,
              builder: (context, current, _) {
                return Row(
                  children: amounts.map((amt) {
                    final isSel = current == amt;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            selectedAmt.value = amt;
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '₹${amt.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSel ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: isProcessing,
              builder: (context, loading, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            isProcessing.value = true;
                            await state.topUpWallet(selectedAmt.value, 'Instant Checkout Recharge', context: context);
                            isProcessing.value = false;
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            onRecharged();
                          },
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            state.isTelugu ? 'తక్షణమే జోడించండి ⚡' : 'Recharge & Use Wallet ⚡',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildBillRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isBold = false,
    bool isSuccess = false,
    String? strikethrough,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isBold ? 13 : 11.5,
                    color: isBold ? UiTone.ink : const Color(0xFF475569),
                    fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSuccess ? const Color(0xFF059669) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (strikethrough != null) ...[
                Text(
                  strikethrough,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: isBold ? 14 : 12,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                  color: isSuccess
                      ? const Color(0xFF059669)
                      : (isHighlight
                          ? const Color(0xFF059669)
                          : (isBold ? UiTone.ink : const Color(0xFF1E293B))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
