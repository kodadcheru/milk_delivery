import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/app_state.dart';
import 'home/home_location_sheet.dart';
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
        onTap: () => _showCheckoutSheet(context),
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
                      const Text(
                        'Free 06:00 AM Delivery',
                        style: TextStyle(color: UiTone.secondary, fontSize: 10.5, fontWeight: FontWeight.bold),
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
                  child: const Row(
                    children: [
                      Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  void _showCheckoutSheet(BuildContext context) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1)); // Locked to Tomorrow for Express Schedule
    String slot = '06:00 AM - 08:00 AM';
    final slotController = TextEditingController(text: slot);
    String _deliveryMode = 'INSTANT';
    String _paymentMethod = 'WALLET'; // 'WALLET' or 'COD'

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String formatDate(DateTime d) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    bool _isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final items = state.cartProductsList;
          final total = state.totalCartPrice;

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
                            'Checkout (${state.totalCartItemCount} items)',
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
                          // ── Delivery Mode Toggle ──
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setSheetState(() => _deliveryMode = 'INSTANT'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _deliveryMode == 'INSTANT' ? const Color(0xFF0D7C66) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '⚡ Instant',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _deliveryMode == 'INSTANT' ? Colors.white : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setSheetState(() {
                                      _deliveryMode = 'SCHEDULED';
                                      selectedDate = DateTime.now().add(const Duration(days: 1));
                                      slot = '06:00 AM - 08:00 AM';
                                      slotController.text = slot;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _deliveryMode == 'SCHEDULED' ? const Color(0xFF0D7C66) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '📅 Schedule',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _deliveryMode == 'SCHEDULED' ? Colors.white : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_deliveryMode == 'INSTANT') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0D7C66), Color(0xFF10A37F)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.flash_on, color: Colors.white, size: 32),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Instant Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('Estimated arrival in ~25 minutes', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
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
                                const Text(
                                  '1. Scheduled Delivery Date 📅:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: UiTone.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(UiRadius.xs),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.lock_clock_rounded, size: 13, color: UiTone.primary),
                                      SizedBox(width: 4),
                                      Text('Tomorrow Only', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: UiTone.primary)),
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
                                                  'Tomorrow (${weekdayNames[tomorrow.weekday - 1]})',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: UiTone.ink),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('⚡ NEXT-DAY DROP', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 9, fontWeight: FontWeight.w900)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${tomorrow.day} ${monthNames[tomorrow.month - 1]} ${tomorrow.year} • Farm fresh delivery guaranteed',
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
                                const Text(
                                  '2. Delivery Time Slot ⏰:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(UiRadius.xs),
                                  ),
                                  child: Text(
                                    '3 Slots Available',
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
                                                  const Text('Deliver to:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF047857))),
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
                                          label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                          const Text(
                            'Payment Method 💳:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setSheetState(() => _paymentMethod = 'WALLET'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: _paymentMethod == 'WALLET' ? UiTone.primary.withValues(alpha: 0.1) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _paymentMethod == 'WALLET' ? UiTone.primary : Colors.grey[300]!,
                                        width: _paymentMethod == 'WALLET' ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('⚡', style: TextStyle(fontSize: 16)),
                                        const SizedBox(width: 6),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Prepaid Wallet',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: _paymentMethod == 'WALLET' ? UiTone.primary : UiTone.ink,
                                              ),
                                            ),
                                            Text(
                                              'Bal: ₹${(state.currentUser?.walletBalance ?? 0.0).toStringAsFixed(0)}',
                                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setSheetState(() => _paymentMethod = 'COD'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: _paymentMethod == 'COD' ? UiTone.primary.withValues(alpha: 0.1) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _paymentMethod == 'COD' ? UiTone.primary : Colors.grey[300]!,
                                        width: _paymentMethod == 'COD' ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('💵', style: TextStyle(fontSize: 16)),
                                        const SizedBox(width: 6),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cash on Delivery',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: _paymentMethod == 'COD' ? UiTone.primary : UiTone.ink,
                                              ),
                                            ),
                                            Text('Pay at doorstep', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Bill Breakdown ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: UiTone.shellBackground,
                              borderRadius: BorderRadius.circular(UiRadius.md),
                              border: Border.all(color: UiTone.surfaceBorder),
                            ),
                            child: Column(
                              children: [
                                _buildBillRow('Item Subtotal', '₹${total.toStringAsFixed(0)}'),
                                _buildBillRow('Doorstep Delivery (${_deliveryMode == 'INSTANT' ? "Instant" : formatDate(selectedDate)})', 'FREE', isHighlight: true),
                                _buildBillRow('Handling & Quality Assurance', '₹0 (Waived)'),
                                const Divider(height: 16),
                                _buildBillRow('To Pay', '₹${total.toStringAsFixed(0)}', isBold: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),

                  // Checkout CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_isSubmitting) return;
                        
                        final walletBalance = state.currentUser?.walletBalance ?? 0.0;
                        if (_paymentMethod == 'WALLET' && walletBalance < total) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Insufficient wallet balance (₹${walletBalance.toStringAsFixed(0)}). Please top up ₹${(total - walletBalance).toStringAsFixed(0)} or switch to Cash on Delivery (COD).'),
                            backgroundColor: Colors.red,
                          ));
                          return;
                        }
                        
                        setSheetState(() => _isSubmitting = true);
                        final currentAddr = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
                        try {
                          final order = await state.placeExpressOrder(
                            deliveryType: _deliveryMode,
                            deliveryDate: _deliveryMode == 'INSTANT' ? formatDate(DateTime.now()) : formatDate(selectedDate),
                            deliverySlot: _deliveryMode == 'INSTANT' ? 'Instant Delivery' : slot,
                            deliveryAddress: currentAddr,
                            paymentMethod: _paymentMethod,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: UiTone.primary,
                                content: Text(
                                  _deliveryMode == 'INSTANT'
                                      ? '⚡ Order ${order.id} Placed for Instant Delivery!'
                                      : '🎉 Order ${order.id} Scheduled for ${formatDate(selectedDate)} ($slot)!'
                                ),
                              ),
                            );
                            state.setTab(3); // Bookings Tab
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
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_paymentMethod == 'COD' ? Icons.payments_rounded : (_deliveryMode == 'INSTANT' ? Icons.flash_on : Icons.event_available_rounded), color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _paymentMethod == 'COD'
                                ? (_deliveryMode == 'INSTANT' ? 'Place COD Instant Drop — ₹${total.toStringAsFixed(0)} 💵' : 'Place COD Order — ₹${total.toStringAsFixed(0)} 💵')
                                : (_deliveryMode == 'INSTANT' ? 'Pay & Order Now — ₹${total.toStringAsFixed(0)} ⚡' : 'Schedule Order — ₹${total.toStringAsFixed(0)} 📅'),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: isBold ? UiTone.ink : Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isHighlight ? UiTone.secondary : (isBold ? UiTone.primary : UiTone.ink),
            ),
          ),
        ],
      ),
    );
  }
}
