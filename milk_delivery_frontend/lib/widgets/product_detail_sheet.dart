import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/subscription_address_selection_screen.dart';
import '../services/api_service.dart';
import '../theme/ui_tokens.dart';

enum SubscriptionPlanType { weekly, monthly }

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
  String _selectedSlot = '05:30 AM - 07:00 AM';
  List<Map<String, dynamic>>? _slotsData;
  bool _isBadgeExpanded = false;

  @override
  void initState() {
    super.initState();
    _initDefaultPackSize();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    final slots = await ApiService.fetchSlotAvailability();
    if (mounted) setState(() => _slotsData = slots);
  }

  void _initDefaultPackSize() {
    final name = widget.product.name.toLowerCase();
    final cat = widget.product.category.toUpperCase();
    final uq = widget.product.unitQuantity.toLowerCase();

    if (cat == 'MILK' || name.contains('milk')) {
      _selectedPackSize = uq.contains('500') ? '500 ml' : '1 Litre';
    } else if (cat == 'EGGS' || name.contains('egg')) {
      _selectedPackSize = '6 Eggs';
    } else if (cat == 'WATER_CAN' || name.contains('water')) {
      _selectedPackSize = '20 Litres';
    } else if (uq.contains('500')) {
      _selectedPackSize = '500g';
    } else {
      _selectedPackSize = '1 Litre';
    }
  }

  List<String> get _availablePackSizes {
    final name = widget.product.name.toLowerCase();
    final cat = widget.product.category.toUpperCase();

    if (cat == 'MILK' || name.contains('milk')) {
      return ['500 ml', '1 Litre', '2 Litres'];
    } else if (cat == 'EGGS' || name.contains('egg')) {
      return ['6 Eggs', '12 Eggs', '30 Tray'];
    } else if (cat == 'WATER_CAN' || name.contains('water')) {
      return ['10 Litres', '20 Litres'];
    } else if (cat == 'MEAT' || name.contains('chicken') || name.contains('curd') || name.contains('dahi')) {
      return ['500g', '1 kg'];
    } else {
      return ['500 ml', '1 Litre'];
    }
  }

  double get _effectiveUnitPrice {
    final basePrice = widget.product.pricePerUnit;
    if (_selectedPackSize == '500 ml' || _selectedPackSize == '500g') {
      return (basePrice * 0.55).roundToDouble();
    } else if (_selectedPackSize == '2 Litres' || _selectedPackSize == '1 kg') {
      return (basePrice * 1.95).roundToDouble();
    } else if (_selectedPackSize == '12 Eggs') {
      return (basePrice * 1.9).roundToDouble();
    } else if (_selectedPackSize == '30 Tray') {
      return (basePrice * 4.5).roundToDouble();
    } else if (_selectedPackSize == '10 Litres') {
      return (basePrice * 0.6).roundToDouble();
    }
    return basePrice;
  }

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
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[tomorrow.month - 1]} ${tomorrow.day}, ${tomorrow.year}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final primaryGreen = const Color(0xFF0D7C66);
    final headerStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Hero (compact)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.imageUrl.isNotEmpty
                            ? Image.network(
                                item.imageUrl,
                                height: 70,
                                width: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 70, width: 70, color: Colors.grey[100],
                                  alignment: Alignment.center,
                                  child: Text(item.icon, style: const TextStyle(fontSize: 32)),
                                ),
                              )
                            : Container(
                                height: 70, width: 70, color: Colors.grey[100],
                                alignment: Alignment.center,
                                child: Text(item.icon, style: const TextStyle(fontSize: 32)),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Text('$_selectedPackSize • ₹${_effectiveUnitPrice.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            // Trust badge
                            GestureDetector(
                              onTap: () => setState(() => _isBadgeExpanded = !_isBadgeExpanded),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('✅ ', style: TextStyle(fontSize: 10)),
                                        Expanded(
                                          child: Text(
                                            '6.8% Fat • 0% Water • FSSAI Grade A+',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(_isBadgeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: const Color(0xFF059669)),
                                      ],
                                    ),
                                    if (_isBadgeExpanded) ...[
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      const Text('🔬 9.0% SNF', style: TextStyle(fontSize: 10, color: Color(0xFF065F46))),
                                      const Text('❄️ Chilled at 3.8°C', style: TextStyle(fontSize: 10, color: Color(0xFF065F46))),
                                      const Text('🧪 24 Purity Checks Passed', style: TextStyle(fontSize: 10, color: Color(0xFF065F46))),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Pack Size Selector
                  Row(
                    children: [
                      const Icon(Icons.straighten, size: 16, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Text('Pack Size', style: headerStyle),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availablePackSizes.map((size) {
                      final isSelected = _selectedPackSize == size;
                      return ChoiceChip(
                        label: Text(size, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF0F172A))),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedPackSize = size),
                        selectedColor: primaryGreen,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? primaryGreen : const Color(0xFFE2E8F0)),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 3. Quantity + Frequency (Row)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_basket_outlined, size: 16, color: Color(0xFF0F172A)),
                                const SizedBox(width: 6),
                                Text('Quantity', style: headerStyle),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove, size: 18, color: _qty > 1 ? primaryGreen : Colors.grey),
                                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                  Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                  IconButton(
                                    icon: Icon(Icons.add, size: 18, color: primaryGreen),
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
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_repeat, size: 16, color: Color(0xFF0F172A)),
                                const SizedBox(width: 6),
                                Text('Frequency', style: headerStyle),
                              ],
                            ),
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

                  // 4. Plan Duration
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Text('Duration', style: headerStyle),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _planType = SubscriptionPlanType.weekly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _planType == SubscriptionPlanType.weekly ? primaryGreen : Colors.white,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              border: Border.all(color: _planType == SubscriptionPlanType.weekly ? primaryGreen : const Color(0xFFE2E8F0)),
                            ),
                            alignment: Alignment.center,
                            child: Text('Weekly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _planType == SubscriptionPlanType.weekly ? Colors.white : Colors.grey[700])),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _planType = SubscriptionPlanType.monthly),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _planType == SubscriptionPlanType.monthly ? primaryGreen : Colors.white,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              border: Border.all(color: _planType == SubscriptionPlanType.monthly ? primaryGreen : const Color(0xFFE2E8F0)),
                            ),
                            alignment: Alignment.center,
                            child: Text('Monthly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _planType == SubscriptionPlanType.monthly ? Colors.white : Colors.grey[700])),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _planType == SubscriptionPlanType.weekly
                        ? [1, 2, 3].map((w) => _buildDurationChip(w, '$w Wk', _selectedWeeks == w, () => setState(() => _selectedWeeks = w))).toList()
                        : [1, 2, 3].map((m) => _buildDurationChip(m, '$m Mo', _selectedMonths == m, () => setState(() => _selectedMonths = m))).toList(),
                  ),
                  const SizedBox(height: 24),

                  // 5. Plan Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Starts $_formattedTomorrowDate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Text('$_totalDeliveryDays Deliveries', style: const TextStyle(fontSize: 12, color: Color(0xFF0D7C66), fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${_singleDeliveryCost.toStringAsFixed(0)}/day', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                const SizedBox(height: 4),
                                Text('₹${_totalSubscriptionCost.toStringAsFixed(0)} total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFD1FAE5)),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wallet, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text('Prepaid from wallet • Cancel anytime', style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
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
          
          // 6. Bottom CTA Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: item.isOutOfStock ? null : _onSubscribeTap,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: item.isOutOfStock 
                          ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[400]!])
                          : const LinearGradient(colors: [Color(0xFF0D7C66), Color(0xFF14A38B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          item.isOutOfStock ? 'Sold Out' : 'Subscribe — ₹${_totalSubscriptionCost.toStringAsFixed(0)} →',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[200])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ),
                    Expanded(child: Divider(color: Colors.grey[200])),
                  ],
                ),
                const SizedBox(height: 12),
                // Secondary
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: item.isOutOfStock ? null : _onBuyOnceTap,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: item.isOutOfStock ? Colors.grey[300]! : const Color(0xFF0D7C66)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Buy Once — Add to Cart',
                      style: TextStyle(color: item.isOutOfStock ? Colors.grey : const Color(0xFF0D7C66), fontSize: 14, fontWeight: FontWeight.bold),
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

  Widget _buildCompactChoice(String val, String label, String currentVal) {
    final isSelected = currentVal == val;
    return GestureDetector(
      onTap: () => setState(() => _schedule = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int value, String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D7C66) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  void _onSubscribeTap() {
    final item = widget.product;
    final customProduct = ProductModel(
      id: item.id,
      name: item.name,
      category: item.category,
      description: item.description,
      pricePerUnit: _effectiveUnitPrice,
      unit: item.unit,
      unitQuantity: _selectedPackSize,
      imageUrl: item.imageUrl,
      badgeText: item.badgeText,
      nutritionInfo: item.nutritionInfo,
      farmOrigin: item.farmOrigin,
      isAvailable: item.isAvailable,
      rating: item.rating,
      icon: item.icon,
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

  void _onBuyOnceTap() {
    final item = widget.product;
    final customProduct = ProductModel(
      id: item.id,
      name: item.name,
      category: item.category,
      description: item.description,
      pricePerUnit: _effectiveUnitPrice,
      unit: item.unit,
      unitQuantity: _selectedPackSize,
      imageUrl: item.imageUrl,
      badgeText: item.badgeText,
      nutritionInfo: item.nutritionInfo,
      farmOrigin: item.farmOrigin,
      isAvailable: item.isAvailable,
      rating: item.rating,
      icon: item.icon,
    );
    
    widget.state.addToCart(customProduct);
    Navigator.pop(context); // pop is fine for adding to cart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF0F172A),
        content: Text('🛒 Added 1x ${item.name} ($_selectedPackSize) to Cart!'),
      ),
    );
  }
}
