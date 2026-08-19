import 'package:flutter/material.dart';
import '../providers/app_state.dart';

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
      borderRadius: BorderRadius.circular(20),
      shadowColor: const Color(0xFF0D7C66).withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => _showCheckoutSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
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
                        color: const Color(0xFF0D7C66).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0D7C66)),
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
                          color: Color(0xFF10B981),
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
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // View Cart Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7C66),
                    borderRadius: BorderRadius.circular(12),
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
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1)); // Default Tomorrow
    String slot = '05:30 AM - 07:00 AM';

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String formatDate(DateTime d) {
      return '${d.day} ${monthNames[d.month - 1]} ${d.year}';
    }

    String formatDateBadge(DateTime d) {
      final now = DateTime.now();
      final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff == 2) return 'Day After';
      return weekdayNames[d.weekday - 1];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                            'Schedule Delivery (${state.totalCartItemCount} items)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                          // ── Cart Items List ──
                          ...items.map((entry) {
                            final product = entry.key;
                            final qty = entry.value;
                            final itemTotal = product.pricePerUnit * qty;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
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
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Color(0xFF0D7C66)),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Stepper
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            state.decreaseCartQty(product.id);
                                            setSheetState(() {});
                                            if (state.totalCartItemCount == 0) {
                                              Navigator.pop(ctx);
                                            }
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.remove, size: 15, color: Color(0xFF0D7C66)),
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
                                            child: Icon(Icons.add, size: 15, color: Color(0xFF0D7C66)),
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

                          // ── 1. Select Scheduled Delivery Date ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '1. Select Delivery Date 📅:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 14)),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF0D7C66),
                                            onPrimary: Colors.white,
                                            onSurface: Color(0xFF0F172A),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setSheetState(() => selectedDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF0D7C66)),
                                      SizedBox(width: 4),
                                      Text('Custom Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Horizontal Date Selection Cards
                          SizedBox(
                            height: 62,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 5,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final date = DateTime.now().add(Duration(days: idx + 1));
                                final isSelected = selectedDate.year == date.year && selectedDate.month == date.month && selectedDate.day == date.day;

                                return InkWell(
                                  onTap: () => setSheetState(() => selectedDate = date),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 82,
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: const Color(0xFF0D7C66).withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
                                          : [],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          formatDateBadge(date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${date.day} ${monthNames[date.month - 1]}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── 2. Delivery Slot Preference ──
                          const Text('2. Delivery Time Slot ⏰:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSlotTile('05:30 AM - 07:00 AM', '⚡ Morning Peak', slot, (val) => setSheetState(() => slot = val)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSlotTile('07:00 AM - 08:30 AM', '🌅 Morning Std', slot, (val) => setSheetState(() => slot = val)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSlotTile('05:00 PM - 07:00 PM', '🌇 Evening', slot, (val) => setSheetState(() => slot = val)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Delivery Location Strip ──
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: Color(0xFF0D7C66), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Deliver to Doorstep', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(
                                        state.currentDeliveryAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => state.setTab(4),
                                  child: const Text('Change', style: TextStyle(color: Color(0xFF0D7C66), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── Bill Breakdown ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildBillRow('Item Subtotal', '₹${total.toStringAsFixed(0)}'),
                                _buildBillRow('Doorstep Delivery (${formatDate(selectedDate)})', 'FREE', isHighlight: true),
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

                  // Scheduled Checkout CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final order = await state.placeExpressOrder(
                          deliveryDate: formatDate(selectedDate),
                          deliverySlot: slot,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF0D7C66),
                              content: Text('🎉 Order ${order.id} Scheduled for ${formatDate(selectedDate)} ($slot)!'),
                            ),
                          );
                          state.setTab(3); // Bookings Tab
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7C66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_available_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Schedule Order (${formatDateBadge(selectedDate)}) • ₹${total.toStringAsFixed(0)}',
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

  Widget _buildSlotTile(String slotTime, String subtitle, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == slotTime;
    return InkWell(
      onTap: () => onSelect(slotTime),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66).withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slotTime, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: isSelected ? const Color(0xFF0D7C66) : Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 9.5, color: isSelected ? const Color(0xFF0D7C66) : Colors.grey[600], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: isBold ? const Color(0xFF0F172A) : Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isHighlight ? const Color(0xFF10B981) : (isBold ? const Color(0xFF0D7C66) : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
