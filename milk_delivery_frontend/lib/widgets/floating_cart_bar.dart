import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import 'home/home_location_sheet.dart';
import '../theme/ui_tokens.dart';
import '../services/api_service.dart';


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
    DateTime selectedDate = DateTime.now(); // Default Today
    String slot = '05:30 AM - 07:00 AM';
    final slotController = TextEditingController(text: slot);
    String _deliveryMode = 'INSTANT';

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String formatDate(DateTime d) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    String formatDateBadge(DateTime d) {
      final now = DateTime.now();
      final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      if (diff == 2) return 'Day After';
      return weekdayNames[d.weekday - 1];
    }

    List<Map<String, dynamic>>? slotsData;
    bool hasFetchedSlots = false;
    bool _isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (!hasFetchedSlots) {
            hasFetchedSlots = true;
            Future<void> fetchSlots() async {
              final slots = await ApiService.fetchSlotAvailability();
              if (ctx.mounted) setSheetState(() => slotsData = slots);
            }
            fetchSlots();
          }

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
                                    onTap: () => setSheetState(() => _deliveryMode = 'SCHEDULED'),
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
                            // ── 1. Select Scheduled Delivery Date ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '1. Select Delivery Date 📅:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink),
                                ),
                                InkWell(
                                  onTap: () async {
                                    final today = DateTime.now();
                                    final initDate = selectedDate.isBefore(today) ? today : selectedDate;
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: initDate,
                                      firstDate: today,
                                      lastDate: DateTime.now().add(const Duration(days: 14)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.light(
                                              primary: UiTone.primary,
                                              onPrimary: Colors.white,
                                              onSurface: UiTone.ink,
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
                                      color: UiTone.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(UiRadius.xs),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.calendar_month_rounded, size: 14, color: UiTone.primary),
                                        SizedBox(width: 4),
                                        Text('Custom Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTone.primary)),
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
                                  final date = DateTime.now().add(Duration(days: idx));
                                  final isSelected = selectedDate.year == date.year && selectedDate.month == date.month && selectedDate.day == date.day;

                                  return InkWell(
                                    onTap: () => setSheetState(() => selectedDate = date),
                                    borderRadius: BorderRadius.circular(UiRadius.sm),
                                    child: Container(
                                      width: 82,
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
                                        borderRadius: BorderRadius.circular(UiRadius.sm),
                                        border: Border.all(
                                          color: isSelected ? UiTone.primary : const Color(0xFFCBD5E1),
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [BoxShadow(color: UiTone.primary.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
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
                                              color: isSelected ? Colors.white : UiTone.ink,
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

                            // ── 2. Delivery Slot Preference (Typable + Presets) ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('2. Delivery Time Slot ⏰:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: UiTone.ink)),
                                Text('Typable & Customizable', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.teal[700])),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (slotsData == null)
                              const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: slotsData!.map((slotMap) {
                                  final slotName = slotMap['name']?.toString() ?? slotMap['time_range']?.toString() ?? '';
                                  final isEvening = slotName.toUpperCase().contains('PM') || slotName.toUpperCase().contains('EVENING');
                                  final icon = isEvening ? '🌙 ' : '☀️ ';
                                  final available = slotMap['available_capacity'] ?? slotMap['available'] ?? 0;
                                  final max = slotMap['max_capacity'] ?? 0;
                                  final isFull = slotMap['is_full'] == true;
                                  final isCutoff = slotMap['is_cutoff_passed'] == true;
                                  
                                  return ChoiceChip(
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(icon + slotName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                        if (isFull)
                                          const Text('FULL', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold))
                                        else if (isCutoff)
                                          const Text('CLOSED', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))
                                        else
                                          Text('$available/$max left', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      ],
                                    ),
                                    selected: slot == slotName,
                                    selectedColor: isEvening ? const Color(0xFFEDE9FE) : UiTone.primarySoft,
                                    onSelected: (isFull || isCutoff) ? null : (val) {
                                      setSheetState(() {
                                        slot = slotName;
                                        slotController.text = slotName;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 8),
                            // Typable Slot Input
                            TextField(
                              controller: slotController,
                              onChanged: (val) {
                                setSheetState(() {
                                  slot = val.trim().isNotEmpty ? val.trim() : '05:30 AM - 07:00 AM';
                                });
                              },
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: UiTone.ink),
                              decoration: InputDecoration(
                                labelText: 'Or type custom slot (e.g. 06:00 AM - 07:30 AM)',
                                labelStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                                prefixIcon: const Icon(Icons.edit_calendar_rounded, size: 16, color: UiTone.primary),
                                filled: true,
                                fillColor: UiTone.shellBackground,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: UiTone.surfaceBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: UiTone.surfaceBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: UiTone.primary, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 14),
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
                        if (walletBalance < total) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Insufficient wallet balance (₹${walletBalance.toStringAsFixed(0)}). Please top up ₹${(total - walletBalance).toStringAsFixed(0)} to continue.'),
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
                          Icon(_deliveryMode == 'INSTANT' ? Icons.flash_on : Icons.event_available_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _deliveryMode == 'INSTANT'
                                ? 'Order Now — ₹${total.toStringAsFixed(0)} ⚡'
                                : 'Schedule Order — ₹${total.toStringAsFixed(0)} 📅',
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
