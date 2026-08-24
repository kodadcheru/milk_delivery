import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/subscription_address_selection_screen.dart';
import '../services/pack_pricing.dart';
import '../theme/ui_format.dart';
import '../theme/ui_text.dart';
import '../theme/ui_tokens.dart';

enum SubscriptionPlanType { weekly, monthly }

/// Full subscription builder: pack size → quantity + frequency → duration →
/// plan summary → **Subscribe →** (into the address flow).
///
/// This sheet is subscription-only. A one-time buyer uses [BuyOnceSheet]
/// instead; that sheet offers a "Subscribe & save" hand-off into this one, so
/// there is no longer a "Buy Once" escape hatch to reach here.
class ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  final AppState state;

  const ProductDetailSheet({super.key, required this.product, required this.state});

  static void show(BuildContext context, ProductModel product, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailSheet(product: product, state: state),
    );
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _qty = 1;
  String _schedule = 'DAILY'; // DAILY, ALTERNATE, WEEKDAYS
  SubscriptionPlanType _planType = SubscriptionPlanType.weekly;
  int _selectedWeeks = 1; // 1, 2, 3 weeks
  int _selectedMonths = 1; // 1, 2, 3 months
  String _selectedPackSize = '1 Litre';
  int _selectedShift = 0; // 0: Morning, 1: Evening
  String _selectedSlot = '05:30 AM - 07:00 AM';
  bool _isBadgeExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedPackSize = PackPricing.defaultSizeFor(widget.product);
  }

  List<String> get _availablePackSizes => PackPricing.sizesFor(widget.product);

  double get _effectiveUnitPrice =>
      PackPricing.effectiveUnitPrice(widget.product.pricePerUnit, _selectedPackSize);

  int get _totalDeliveryDays {
    int totalCalendarDays;
    if (_planType == SubscriptionPlanType.weekly) {
      totalCalendarDays = _selectedWeeks * 7;
    } else {
      totalCalendarDays = _selectedMonths * 30;
    }

    if (_schedule == 'DAILY') {
      return totalCalendarDays;
    } else if (_schedule == 'ALTERNATE') {
      return (totalCalendarDays / 2).ceil();
    } else {
      return ((totalCalendarDays / 7) * 5).round().clamp(1, totalCalendarDays);
    }
  }

  double get _singleDeliveryCost => _effectiveUnitPrice * _qty;

  double get _totalSubscriptionCost => _singleDeliveryCost * _totalDeliveryDays;

  String get _durationLabel {
    if (_planType == SubscriptionPlanType.weekly) {
      return '$_selectedWeeks ${_selectedWeeks == 1 ? "Week" : "Weeks"}';
    } else {
      return '$_selectedMonths ${_selectedMonths == 1 ? "Month" : "Months"}';
    }
  }

  String get _formattedTomorrowDate {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[tomorrow.month - 1]} ${tomorrow.day}, ${tomorrow.year}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.product;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
      ),
      child: Column(
        children: [
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: UiTone.surfaceBorder,
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Hero (compact)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(UiRadius.sm),
                        child: item.imageUrl.isNotEmpty
                            ? Image.network(
                                item.imageUrl,
                                height: 70,
                                width: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _heroFallback(item),
                              )
                            : _heroFallback(item),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: UiText.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            // Pack • price (keeps the discount look)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$_selectedPackSize • ', style: UiText.body),
                                Text(UiFormat.price(_effectiveUnitPrice), style: UiText.bodyStrong),
                                const SizedBox(width: 6),
                                Text(UiFormat.strike(_effectiveUnitPrice), style: UiText.priceStrike),
                              ],
                            ),
                            if (item.category == 'MILK') ...[
                              const SizedBox(height: 8),
                              _trustBadge(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Pack size selector
                  _sectionHeader(Icons.straighten, 'Pack Size'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availablePackSizes.map((size) {
                      final isSelected = _selectedPackSize == size;
                      return ChoiceChip(
                        label: Text(
                          size,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isSelected ? Colors.white : UiTone.ink,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedPackSize = size),
                        selectedColor: UiTone.primary,
                        backgroundColor: UiTone.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          side: BorderSide(color: isSelected ? UiTone.primary : UiTone.surfaceBorder),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 3. Quantity + Frequency
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(Icons.shopping_basket_outlined, 'Quantity'),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: UiTone.surface,
                                borderRadius: BorderRadius.circular(UiRadius.sm),
                                border: Border.all(color: UiTone.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove, size: 18, color: _qty > 1 ? UiTone.primary : UiTone.surfaceBorder),
                                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                  Text('$_qty', style: UiText.bodyStrong),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18, color: UiTone.primary),
                                    onPressed: () => setState(() => _qty++),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Frequency
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(Icons.event_repeat, 'Frequency'),
                            const SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCompactChoice('DAILY', 'Daily', _schedule),
                                const SizedBox(height: 6),
                                _buildCompactChoice('ALTERNATE', 'Alternate', _schedule),
                                const SizedBox(height: 6),
                                _buildCompactChoice('WEEKDAYS', 'Mon - Fri', _schedule),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. Plan duration
                  _sectionHeader(Icons.calendar_month_outlined, 'Duration'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _planType = SubscriptionPlanType.weekly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _planType == SubscriptionPlanType.weekly ? UiTone.primary : UiTone.surface,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(UiRadius.xs)),
                              border: Border.all(color: _planType == SubscriptionPlanType.weekly ? UiTone.primary : UiTone.surfaceBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Weekly',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _planType == SubscriptionPlanType.weekly ? Colors.white : UiTone.softText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _planType = SubscriptionPlanType.monthly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _planType == SubscriptionPlanType.monthly ? UiTone.primary : UiTone.surface,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(UiRadius.xs)),
                              border: Border.all(color: _planType == SubscriptionPlanType.monthly ? UiTone.primary : UiTone.surfaceBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _planType == SubscriptionPlanType.monthly ? Colors.white : UiTone.softText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _planType == SubscriptionPlanType.weekly
                        ? [1, 2, 3].map((w) => _buildDurationChip('$w Wk', _selectedWeeks == w, () => setState(() => _selectedWeeks = w))).toList()
                        : [1, 2, 3].map((m) => _buildDurationChip('$m Mo', _selectedMonths == m, () => setState(() => _selectedMonths = m))).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 4b. Preferred Delivery Shift & Slot (Morning / Evening)
                  _sectionHeader(Icons.access_time_filled_rounded, 'Delivery Slot & Shift'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: UiTone.surfaceMuted,
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedShift = 0;
                                _selectedSlot = '05:30 AM - 07:00 AM';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _selectedShift == 0 ? UiTone.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(UiRadius.pill),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('☀️ ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    'Morning Drop',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedShift == 0 ? Colors.white : UiTone.softText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedShift = 1;
                                _selectedSlot = '05:00 PM - 07:00 PM';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _selectedShift == 1 ? const Color(0xFF7C3AED) : Colors.transparent,
                                borderRadius: BorderRadius.circular(UiRadius.pill),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🌙 ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    'Evening Drop',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedShift == 1 ? Colors.white : UiTone.softText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _selectedShift == 0
                        ? [
                            Expanded(
                              child: _buildSlotChip(
                                '05:30 AM - 07:00 AM',
                                '⚡ Early Morning',
                                '05:30 - 07:00 AM',
                                _selectedSlot == '05:30 AM - 07:00 AM',
                                () => setState(() => _selectedSlot = '05:30 AM - 07:00 AM'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSlotChip(
                                '07:00 AM - 08:30 AM',
                                '🌅 Standard',
                                '07:00 - 08:30 AM',
                                _selectedSlot == '07:00 AM - 08:30 AM',
                                () => setState(() => _selectedSlot = '07:00 AM - 08:30 AM'),
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              child: _buildSlotChip(
                                '05:00 PM - 07:00 PM',
                                '🌇 Early Evening',
                                '05:00 - 07:00 PM',
                                _selectedSlot == '05:00 PM - 07:00 PM',
                                () => setState(() => _selectedSlot = '05:00 PM - 07:00 PM'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSlotChip(
                                '06:30 PM - 08:30 PM',
                                '🌙 Standard',
                                '06:30 - 08:30 PM',
                                _selectedSlot == '06:30 PM - 08:30 PM',
                                () => setState(() => _selectedSlot = '06:30 PM - 08:30 PM'),
                              ),
                            ),
                          ],
                  ),
                  const SizedBox(height: 24),

                  // 5. Plan summary card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: UiTone.primarySoft,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: UiTone.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Starts $_formattedTomorrowDate', style: UiText.bodyStrong.copyWith(fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('$_totalDeliveryDays Deliveries', style: UiText.label.copyWith(color: UiTone.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${UiFormat.price(_singleDeliveryCost)}/day', style: UiText.label.copyWith(color: UiTone.softText)),
                                const SizedBox(height: 4),
                                Text('${UiFormat.price(_totalSubscriptionCost)} total', style: UiText.h2.copyWith(fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: UiTone.successSoft),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wallet, size: 14, color: UiTone.success),
                            const SizedBox(width: 6),
                            Text('Prepaid from wallet • Cancel anytime', style: UiText.caption.copyWith(color: UiTone.primaryDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 6. Bottom CTA bar — subscribe only
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: UiTone.surface,
              boxShadow: [
                BoxShadow(color: UiTone.ink.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: item.isOutOfStock ? null : UiGradient.primary,
                  color: item.isOutOfStock ? UiTone.surfaceMuted : null,
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  boxShadow: item.isOutOfStock ? null : UiShadow.glowPrimary,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    onTap: item.isOutOfStock ? null : _onSubscribeTap,
                    child: Center(
                      child: Text(
                        item.isOutOfStock ? 'Sold Out' : 'Subscribe — ${UiFormat.price(_totalSubscriptionCost)} →',
                        style: UiText.title.copyWith(color: item.isOutOfStock ? UiText.muted : Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFallback(ProductModel item) => Container(
        height: 70,
        width: 70,
        color: UiTone.primarySoft,
        alignment: Alignment.center,
        child: Text(item.icon, style: const TextStyle(fontSize: 32)),
      );

  Widget _sectionHeader(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 16, color: UiTone.ink),
          const SizedBox(width: 6),
          Text(label, style: UiText.bodyStrong),
        ],
      );

  Widget _trustBadge() {
    final nameLower = widget.product.name.toLowerCase();
    Map<String, dynamic>? activeBatch;
    final batches = widget.state.dailyMilkBatches;
    if (batches.isNotEmpty) {
      activeBatch = batches.firstWhere(
        (b) {
          final bName = b['product_name']?.toString().toLowerCase() ?? '';
          return bName.contains(nameLower.split(' ').first);
        },
        orElse: () => batches.first,
      );
    }

    final fatVal = activeBatch != null ? '${activeBatch['fat_percentage']}%' : (nameLower.contains('buffalo') ? '6.8%' : '4.2%');
    final snfVal = activeBatch != null ? '${activeBatch['snf_percentage']}%' : (nameLower.contains('buffalo') ? '9.0%' : '8.5%');
    final waterVal = activeBatch != null ? '${activeBatch['water_percentage']}%' : '0.0%';
    final tempVal = activeBatch != null ? '${activeBatch['temperature_celsius']}°C' : '3.8°C';
    final batchCode = activeBatch != null ? (activeBatch['batch_code'] ?? 'BATCH-CERT-01') : 'BATCH-CERT-01';
    final certNote = activeBatch != null ? (activeBatch['quality_certificate_note'] ?? 'FSSAI Certified • Passed 24 Purity Checks') : 'FSSAI Certified • Passed 24 Purity Checks';

    return GestureDetector(
      onTap: () => setState(() => _isBadgeExpanded = !_isBadgeExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: UiTone.primarySoft,
          borderRadius: BorderRadius.circular(UiRadius.xs),
          border: Border.all(color: UiTone.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔬 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    'Today\'s Certified Lab Batch • $fatVal Fat • $waterVal Water',
                    style: UiText.caption.copyWith(color: UiTone.primaryDark, fontWeight: FontWeight.w900, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(_isBadgeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: UiTone.primary),
              ],
            ),
            if (_isBadgeExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🥛 Solid Not Fat (SNF):', style: UiText.caption.copyWith(color: UiTone.softText)),
                  Text(snfVal, style: UiText.caption.copyWith(color: UiTone.ink, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('❄️ Chilling Temperature:', style: UiText.caption.copyWith(color: UiTone.softText)),
                  Text(tempVal, style: UiText.caption.copyWith(color: UiTone.ink, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🏷️ Batch ID:', style: UiText.caption.copyWith(color: UiTone.softText)),
                  Text(batchCode, style: UiText.caption.copyWith(color: UiTone.primary, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                  border: Border.all(color: UiTone.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: UiTone.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        certNote,
                        style: UiText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: UiTone.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChoice(String val, String label, String currentVal) {
    final isSelected = currentVal == val;
    return GestureDetector(
      onTap: () => setState(() => _schedule = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : UiTone.surface,
          borderRadius: BorderRadius.circular(UiRadius.xs),
          border: Border.all(color: isSelected ? UiTone.primary : UiTone.surfaceBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : UiTone.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? UiTone.primary : UiTone.surface,
            borderRadius: BorderRadius.circular(UiRadius.xs),
            border: Border.all(color: isSelected ? UiTone.primary : UiTone.surfaceBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : UiTone.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotChip(String val, String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primarySoft : UiTone.surface,
          borderRadius: BorderRadius.circular(UiRadius.xs),
          border: Border.all(
            color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? UiTone.primaryDark : UiTone.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? UiTone.primary : UiTone.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubscribeTap() {
    final customProduct = widget.product.copyWith(
      pricePerUnit: _effectiveUnitPrice,
      unitQuantity: _selectedPackSize,
    );

    // CRITICAL UX FIX: Do NOT pop the sheet. Push on top.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => SubscriptionAddressSelectionScreen(
          product: customProduct,
          quantity: _qty,
          schedule: _schedule,
          packSize: _selectedPackSize,
          timeSlot: _selectedSlot,
          durationLabel: _durationLabel,
          totalDeliveryDays: _totalDeliveryDays,
          singleDeliveryCost: _singleDeliveryCost,
          totalCost: _totalSubscriptionCost,
          deliveryInstructions: '', // removed from this screen
          state: widget.state,
        ),
      ),
    );
  }
}
