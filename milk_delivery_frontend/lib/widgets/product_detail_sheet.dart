import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/subscription_address_selection_screen.dart';

enum SubscriptionPlanType { weekly, monthly }

class ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  final AppState state;

  const ProductDetailSheet({super.key, required this.product, required this.state});

  static void show(BuildContext context, ProductModel product, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
  final _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initDefaultPackSize();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
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
      // Weekdays ~ 5/7 of days
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

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final singleDeliveryCost = _singleDeliveryCost;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.90,
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
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Icon Container with Badges
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF0D7C66).withValues(alpha: 0.1), const Color(0xFF10B981).withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D7C66),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.badgeText,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text('${item.rating} ★ (1.2k Reviews)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.brown)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (item.imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                item.imageUrl,
                                height: 110,
                                width: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Text(item.icon, style: const TextStyle(fontSize: 56)),
                              ),
                            )
                          else
                            Text(item.icon, style: const TextStyle(fontSize: 56)),
                          const SizedBox(height: 8),
                          Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('$_selectedPackSize • ₹${_effectiveUnitPrice.toStringAsFixed(0)} / unit', style: TextStyle(color: Colors.grey[700], fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Lab Quality & Purity Assurance Certificate ──
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPurityMetric('🧪 0% Adulterants', 'Chemical Free'),
                          Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
                          _buildPurityMetric('❄️ < 4°C Chilled', 'Direct Cold Chain'),
                          Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
                          _buildPurityMetric('🔬 24 Tests Passed', 'FSSAI Certified'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 1. Plan Type Selector (Weekly vs Monthly) ──
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1. Choose Subscription Plan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('Flexible Duration ⚡', style: TextStyle(fontSize: 10.5, color: Color(0xFF0D7C66), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPlanTypeCard(
                            type: SubscriptionPlanType.weekly,
                            title: '🗓️ Weekly Plan',
                            subtitle: 'Choose 1, 2, or 3 Weeks',
                            badge: '1 - 3 WEEKS',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPlanTypeCard(
                            type: SubscriptionPlanType.monthly,
                            title: '📅 Monthly Plan',
                            subtitle: 'Choose 1, 2, or 3 Months',
                            badge: 'BEST VALUE',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 2. Duration Configurator (1, 2, 3 Weeks / Months) ──
                    if (_planType == SubscriptionPlanType.weekly) ...[
                      const Text('2. Select Week Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDurationOption(
                            weeks: 1,
                            title: '1 Week',
                            daysLabel: '7 Days',
                            isSelected: _selectedWeeks == 1,
                            onTap: () => setState(() => _selectedWeeks = 1),
                          ),
                          const SizedBox(width: 8),
                          _buildDurationOption(
                            weeks: 2,
                            title: '2 Weeks',
                            daysLabel: '14 Days',
                            isSelected: _selectedWeeks == 2,
                            onTap: () => setState(() => _selectedWeeks = 2),
                          ),
                          const SizedBox(width: 8),
                          _buildDurationOption(
                            weeks: 3,
                            title: '3 Weeks',
                            daysLabel: '21 Days',
                            isSelected: _selectedWeeks == 3,
                            onTap: () => setState(() => _selectedWeeks = 3),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text('2. Select Month Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDurationOption(
                            weeks: 1,
                            title: '1 Month',
                            daysLabel: '30 Days',
                            isSelected: _selectedMonths == 1,
                            onTap: () => setState(() => _selectedMonths = 1),
                          ),
                          const SizedBox(width: 8),
                          _buildDurationOption(
                            weeks: 2,
                            title: '2 Months',
                            daysLabel: '60 Days',
                            isSelected: _selectedMonths == 2,
                            onTap: () => setState(() => _selectedMonths = 2),
                          ),
                          const SizedBox(width: 8),
                          _buildDurationOption(
                            weeks: 3,
                            title: '3 Months',
                            daysLabel: '90 Days',
                            isSelected: _selectedMonths == 3,
                            onTap: () => setState(() => _selectedMonths = 3),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── 3. Pack Size / Volume Selection Chips (500ml & 1 Litre) ──
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('3. Select Pack Size / Volume:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        Text('Portion Size 🥛', style: TextStyle(fontSize: 10.5, color: Color(0xFF0D7C66), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _availablePackSizes.map((size) {
                        final isSelected = _selectedPackSize == size;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () => setState(() => _selectedPackSize = size),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: const Color(0xFF0D7C66).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Text(
                                      size,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5,
                                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isSelected ? 'Selected' : 'Tap to pick',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white70 : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // ── 4. Quantity per Morning ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '4. Quantity per Delivery:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_qty × $_selectedPackSize (₹${singleDeliveryCost.toStringAsFixed(0)} / day)',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF0D7C66), fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.remove, size: 18, color: _qty > 1 ? const Color(0xFF0D7C66) : Colors.grey[400]),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    '$_qty',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => setState(() => _qty++),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.add, size: 18, color: Color(0xFF0D7C66)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 5. Delivery Schedule ──
                    const Text('5. Delivery Frequency:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildScheduleChoice('DAILY', 'Everyday 🥛', _schedule, (val) => setState(() => _schedule = val)),
                        const SizedBox(width: 6),
                        _buildScheduleChoice('ALTERNATE', 'Alternate 🟡', _schedule, (val) => setState(() => _schedule = val)),
                        const SizedBox(width: 6),
                        _buildScheduleChoice('WEEKDAYS', 'Mon - Fri 💼', _schedule, (val) => setState(() => _schedule = val)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 5. Plan Summary Breakdown Card ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Plan Duration: $_durationLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              Text('$_totalDeliveryDays Deliveries', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0D7C66))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Per Morning (${_qty}x): ₹${singleDeliveryCost.toStringAsFixed(0)}', style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                              Text(
                                'Total: ₹${_totalSubscriptionCost.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0D7C66)),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          const Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Prepaid from wallet • Pause or cancel anytime with zero cancellation fees',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Delivery Time Slot Preference ──
                    const Text(
                      'Delivery Time Slot Preference ⏰',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSlotOptionTile('05:30 AM - 07:00 AM', '⚡ Peak Morning'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSlotOptionTile('07:00 AM - 08:30 AM', '🌅 Std Morning'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSlotOptionTile('05:00 PM - 07:00 PM', '🌇 Evening'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),



                    // ── Doorstep Delivery Instructions (Optional) ──
                    TextField(
                      controller: _instructionsController,
                      decoration: InputDecoration(
                        hintText: 'Doorstep instructions (e.g. Ring bell, leave in bag)',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11.5),
                        prefixIcon: const Icon(Icons.doorbell_outlined, size: 16, color: Color(0xFF0D7C66)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Dual CTA Buttons
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
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
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF0F172A),
                                content: Text('🛒 Added 1x ${item.name} ($_selectedPackSize) to Cart!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0D7C66), size: 16),
                          label: const Text('Add 1x Cart', style: TextStyle(color: Color(0xFF0D7C66), fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0D7C66), width: 1.5),
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
                            Navigator.pop(context);
                            Navigator.push(
                              context,
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
                                  deliveryInstructions: _instructionsController.text.trim(),
                                  state: widget.state,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                          label: Text('Next: Select Address 📍 (₹${_totalSubscriptionCost.toStringAsFixed(0)})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTypeCard({
    required SubscriptionPlanType type,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final isSelected = _planType == type;

    return InkWell(
      onTap: () => setState(() => _planType = type),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF0D7C66).withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFF0F172A),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF0D7C66), size: 16),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption({
    required int weeks,
    required String title,
    required String daysLabel,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                daysLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurityMetric(String title, String subtitle) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0D7C66))),
        const SizedBox(height: 1),
        Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildScheduleChoice(String val, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == val;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotOptionTile(String slotVal, String label) {
    final isSelected = _selectedSlot == slotVal;
    return InkWell(
      onTap: () => setState(() => _selectedSlot = slotVal),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D7C66).withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Text(
              slotVal,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9.5,
                color: isSelected ? const Color(0xFF0D7C66) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF0D7C66) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
