import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/app_state.dart';
import '../screens/customer/subscription_success_screen.dart';
import '../services/pack_pricing.dart';
import '../theme/ui_format.dart';
import '../theme/ui_tokens.dart';
import 'home/home_location_sheet.dart';

/// Clean 3-Step Subscription Builder Micro-Flow:
/// Step 1: Pack Size & Quantity (What & How Much)
/// Step 2: Schedule & Delivery Shift (When)
/// Step 3: Duration, Address & Review (Where & Confirmation)
class ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  final AppState state;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.state,
  });

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
  int _currentStep = 0; // 0, 1, 2
  late final PageController _pageController;

  // ── Step 1: Pack & Quantity ──
  int _qty = 1;
  String _selectedPackSize = '1 Litre';
  bool _isBadgeExpanded = false;

  // ── Step 2: Frequency & Slot ──
  String _schedule = 'DAILY'; // DAILY, ALTERNATE, CUSTOM
  final Set<int> _customDays = {1, 2, 3, 4, 5, 6, 7}; // 1=Mon, 7=Sun
  int _selectedShift = 0; // 0: Morning, 1: Evening
  String _selectedSlot = '05:30 AM - 07:00 AM';

  // ── Step 3: Duration, Start Date, Address & Drop Note ──
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  int _durationDays = 30; // 15, 30, 60
  String _dropPreference = 'Ring Bell 🔔';
  final TextEditingController _instructionsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedPackSize = PackPricing.defaultSizeFor(widget.product);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  List<String> get _availablePackSizes => PackPricing.sizesFor(widget.product);

  double get _effectiveUnitPrice =>
      PackPricing.effectiveUnitPrice(widget.product.pricePerUnit, _selectedPackSize);

  int get _totalDeliveryDays {
    if (_schedule == 'DAILY') {
      return _durationDays;
    } else if (_schedule == 'ALTERNATE') {
      return (_durationDays / 2).ceil();
    } else {
      int count = 0;
      for (int i = 0; i < _durationDays; i++) {
        final d = _startDate.add(Duration(days: i));
        if (_customDays.contains(d.weekday)) {
          count++;
        }
      }
      return count.clamp(1, _durationDays);
    }
  }

  double get _singleDeliveryCost => _effectiveUnitPrice * _qty;
  double get _totalSubscriptionCost => _singleDeliveryCost * _totalDeliveryDays;

  String get _formattedStartDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[_startDate.month - 1]} ${_startDate.day}, ${_startDate.year}';
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Top Header & Step Progress Indicator ──
              _buildTopHeader(),

              // ── 3-Step Swipeable/Navigable PageView ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Controlled via buttons
                  children: [
                    _buildStep1PackAndQty(),
                    _buildStep2ScheduleAndSlot(),
                    _buildStep3DurationAndAddress(),
                  ],
                ),
              ),

              // ── Bottom Fixed Action Bar ──
              _buildBottomBar(),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── HEADER & STEPPER ──
  // ─────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(UiRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title row with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentStep == 0
                        ? '1. Select Pack & Quantity'
                        : _currentStep == 1
                            ? '2. Choose Delivery Schedule'
                            : '3. Duration & Confirm',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Step ${_currentStep + 1} of 3 • Dairy Subscription',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(UiRadius.pill),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Step Indicators
          Row(
            children: [
              _stepPill(0, 'Pack & Qty', Icons.shopping_basket_rounded),
              _stepConnector(0),
              _stepPill(1, 'Schedule', Icons.calendar_today_rounded),
              _stepConnector(1),
              _stepPill(2, 'Confirm', Icons.check_circle_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepPill(int index, String label, IconData icon) {
    final isActive = _currentStep >= index;
    final isCurrent = _currentStep == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Allow going backwards to completed steps
          if (_currentStep > index) {
            _goToStep(index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent
                ? UiTone.primary.withValues(alpha: 0.12)
                : isActive
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(UiRadius.sm),
            border: Border.all(
              color: isCurrent
                  ? UiTone.primary
                  : isActive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFE2E8F0),
              width: isCurrent ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isCurrent
                    ? UiTone.primary
                    : isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: isCurrent
                      ? UiTone.primary
                      : isActive
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepConnector(int index) {
    final isDone = _currentStep > index;
    return Container(
      width: 10,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── STEP 1: PACK & QUANTITY (WHAT) ──
  // ─────────────────────────────────────────────────────────
  Widget _buildStep1PackAndQty() {
    final item = widget.product;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Compact Product Hero
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, stackTrace) => _heroFallback(item),
                        )
                      : _heroFallback(item),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.localizedName(widget.state.currentLanguage),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '$_selectedPackSize • ',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          Text(
                            UiFormat.price(_effectiveUnitPrice),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: UiTone.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isMeat
                              ? const Color(0xFFFEF2F2)
                              : (item.isWater
                                  ? const Color(0xFFF0F9FF)
                                  : (item.isEggs ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5))),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isMeat
                                ? const Color(0xFFFECACA)
                                : (item.isWater
                                    ? const Color(0xFFBAE6FD)
                                    : (item.isEggs ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0))),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isMeat
                                  ? Icons.health_and_safety_outlined
                                  : (item.isWater ? Icons.water_drop_outlined : (item.isEggs ? Icons.egg_outlined : Icons.verified_rounded)),
                              size: 11,
                              color: item.isMeat
                                  ? const Color(0xFFDC2626)
                                  : (item.isWater ? const Color(0xFF0284C7) : (item.isEggs ? const Color(0xFFD97706) : const Color(0xFF10B981))),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item.displaySubtitle,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: item.isMeat
                                    ? const Color(0xFF991B1B)
                                    : (item.isWater ? const Color(0xFF075985) : (item.isEggs ? const Color(0xFF92400E) : const Color(0xFF065F46))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _trustBadge(),

          const SizedBox(height: 20),

          // 2. Select Pack Size
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text('Choose Pack Size', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _availablePackSizes.map((size) {
              final isSelected = _selectedPackSize == size;
              final priceForSize = PackPricing.effectiveUnitPrice(item.pricePerUnit, size);
              final isRecommended = size.contains('1');

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPackSize = size),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? UiTone.primarySoft : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? UiTone.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: UiTone.primary.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        if (isRecommended)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: UiTone.primary,
                              borderRadius: BorderRadius.circular(UiRadius.pill),
                            ),
                            child: const Text(
                              'POPULAR ⭐',
                              style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        Text(
                          size,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? UiTone.primaryDark : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          UiFormat.price(priceForSize),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? UiTone.primary : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // 3. Daily Quantity Stepper
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Delivery Quantity',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_qty * (double.tryParse(_selectedPackSize.split(' ').first) ?? 1.0)} Litres each delivery',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18, color: _qty > 1 ? UiTone.primary : const Color(0xFFCBD5E1)),
                        onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_qty',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18, color: UiTone.primary),
                        onPressed: () => setState(() => _qty++),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Daily Rate Snapshot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Estimated Daily Cost:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                    ),
                  ],
                ),
                Text(
                  '${UiFormat.price(_singleDeliveryCost)} / day',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── STEP 2: SCHEDULE & TIME SLOT (WHEN) ──
  // ─────────────────────────────────────────────────────────
  Widget _buildStep2ScheduleAndSlot() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frequency Section
          const Row(
            children: [
              Icon(Icons.event_repeat_rounded, size: 16, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text('How Often Do You Need It?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),

          // Frequency Options (Cards)
          _frequencyOptionCard(
            key: 'DAILY',
            title: 'Everyday (Daily)',
            subtitle: 'Fresh milk delivered 7 days a week',
            badge: 'MOST POPULAR 🌟',
          ),
          const SizedBox(height: 8),
          _frequencyOptionCard(
            key: 'ALTERNATE',
            title: 'Alternate Days',
            subtitle: 'Delivered every 2nd day (Mon, Wed, Fri...)',
          ),
          const SizedBox(height: 8),
          _frequencyOptionCard(
            key: 'CUSTOM',
            title: 'Custom Days of Week',
            subtitle: 'Choose specific days (e.g. Weekends only)',
          ),

          // Custom Days Selector (Revealed if CUSTOM selected)
          if (_schedule == 'CUSTOM') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select delivery days:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _dayBubble(1, 'M'),
                      _dayBubble(2, 'T'),
                      _dayBubble(3, 'W'),
                      _dayBubble(4, 'T'),
                      _dayBubble(5, 'F'),
                      _dayBubble(6, 'S'),
                      _dayBubble(7, 'S'),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Shift & Slot Section
          const Row(
            children: [
              Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text('Preferred Delivery Shift & Slot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 10),

          // Shift Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedShift == 0 ? Colors.white : const Color(0xFF64748B),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedShift == 1 ? Colors.white : const Color(0xFF64748B),
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

          const SizedBox(height: 12),

          // Slots Available
          Row(
            children: _selectedShift == 0
                ? [
                    Expanded(
                      child: _slotSelectionChip(
                        '05:30 AM - 07:00 AM',
                        '⚡ Early Morning',
                        '05:30 - 07:00 AM',
                        _selectedSlot == '05:30 AM - 07:00 AM',
                        () => setState(() => _selectedSlot = '05:30 AM - 07:00 AM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _slotSelectionChip(
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
                      child: _slotSelectionChip(
                        '05:00 PM - 07:00 PM',
                        '🌇 Early Evening',
                        '05:00 - 07:00 PM',
                        _selectedSlot == '05:00 PM - 07:00 PM',
                        () => setState(() => _selectedSlot = '05:00 PM - 07:00 PM'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _slotSelectionChip(
                        '06:30 PM - 08:30 PM',
                        '🌙 Standard',
                        '06:30 - 08:30 PM',
                        _selectedSlot == '06:30 PM - 08:30 PM',
                        () => setState(() => _selectedSlot = '06:30 PM - 08:30 PM'),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _frequencyOptionCard({
    required String key,
    required String title,
    required String subtitle,
    String? badge,
  }) {
    final isSelected = _schedule == key;

    return GestureDetector(
      onTap: () => setState(() => _schedule = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? UiTone.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: isSelected ? UiTone.primary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? UiTone.primaryDark : const Color(0xFF0F172A),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: UiTone.primary,
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayBubble(int dayNum, String label) {
    final isSelected = _customDays.contains(dayNum);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_customDays.length > 1) {
              _customDays.remove(dayNum);
            }
          } else {
            _customDays.add(dayNum);
          }
        });
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? UiTone.primary : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: UiTone.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _slotSelectionChip(String val, String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? UiTone.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? UiTone.primaryDark : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? UiTone.primary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── STEP 3: DURATION, ADDRESS & CONFIRM (WHERE & REVIEW) ──
  // ─────────────────────────────────────────────────────────
  Widget _buildStep3DurationAndAddress() {
    final activeAddr = widget.state.activeAddress;
    final displayAddr = activeAddr?.summaryAddress ?? widget.state.currentDeliveryAddress;
    final currentUser = widget.state.currentUser;
    final walletBal = currentUser?.walletBalance ?? 0.0;
    final hasEnoughBalance = walletBal >= _singleDeliveryCost * 3; // At least 3 days buffer

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Start Date & Plan Duration
          Row(
            children: [
              // Start Date Pill
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Starts On', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF10B981)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _formattedStartDate,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Duration Dropdown Chips
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Duration', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 13, color: UiTone.primary),
                          const SizedBox(width: 3),
                          Text(
                            '$_durationDays Days Plan',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Duration Pills (15, 30, 60 days)
          Row(
            children: [15, 30, 60].map((d) {
              final isSel = _durationDays == d;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _durationDays = d),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel ? UiTone.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$d Days',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSel ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // 2. Delivery Doorstep Address
          const Row(
            children: [
              Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text('Delivery Address', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: Text(activeAddr?.icon ?? '🏠', style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeAddr?.title ?? 'Doorstep Address',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayAddr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HomeLocationSheet.show(context, widget.state);
                  },
                  child: const Text(
                    'Change ▾',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: UiTone.primary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Doorstep Instructions (1-tap chips)
          const Text('Doorstep Preference:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          Row(
            children: [
              _dropPrefChip('🔔 Ring Bell'),
              const SizedBox(width: 6),
              _dropPrefChip('🔕 Don\'t Ring'),
              const SizedBox(width: 6),
              _dropPrefChip('🛍️ In Milk Bag'),
            ],
          ),

          const SizedBox(height: 18),

          // 4. Payment & Wallet Summary Card
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
                    Text(
                      '$_totalDeliveryDays deliveries × ${UiFormat.price(_singleDeliveryCost)}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    Text(
                      UiFormat.price(_totalSubscriptionCost),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 5),
                        Text(
                          'Wallet: ${UiFormat.price(walletBal)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    if (hasEnoughBalance)
                      const Text('Ready for Drop ✅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)))
                    else
                      Text(
                        'Recharge ${UiFormat.price((_singleDeliveryCost * 3) - walletBal)} recommended',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropPrefChip(String label) {
    final isSelected = _dropPreference == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _dropPreference = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? UiTone.primary.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? UiTone.primary : const Color(0xFFCBD5E1),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? UiTone.primaryDark : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── BOTTOM ACTION BAR ──
  // ─────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button (Only visible on Steps 2 and 3)
          if (_currentStep > 0) ...[
            InkWell(
              onTap: () => _goToStep(_currentStep - 1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                alignment: Alignment.center,
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF475569)),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Primary Forward / Confirm Button
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onPrimaryActionTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTone.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 0
                                ? 'Next: Choose Schedule →'
                                : _currentStep == 1
                                    ? 'Next: Review & Address →'
                                    : 'CONFIRM • ${UiFormat.price(_singleDeliveryCost)}/day',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPrimaryActionTap() {
    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
    } else {
      _submitSubscription();
    }
  }

  Future<void> _submitSubscription() async {
    setState(() => _isSubmitting = true);

    try {
      final customProduct = widget.product.copyWith(
        pricePerUnit: _effectiveUnitPrice,
        unitQuantity: _selectedPackSize,
      );

      final targetAddress = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;

      await widget.state.createNewSubscription(
        customProduct,
        _qty,
        _schedule,
        deliverySlot: _selectedSlot,
        deliveryAddress: targetAddress,
        deliveryInstructions: _dropPreference,
        packSize: _selectedPackSize,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Dismiss the bottom sheet
      Navigator.of(context).pop();

      // Show the celebration success screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (c) => SubscriptionSuccessScreen(
            productName: widget.product.name,
            packSize: _selectedPackSize,
            quantity: _qty,
            schedule: _schedule,
            slot: _selectedSlot,
            address: targetAddress,
            totalCost: _totalSubscriptionCost,
            state: widget.state,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('❌ Subscription failed: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    }
  }

  Widget _heroFallback(ProductModel item) => Container(
        height: 64,
        width: 64,
        color: UiTone.primarySoft,
        alignment: Alignment.center,
        child: Text(item.icon, style: const TextStyle(fontSize: 28)),
      );

  Widget _trustBadge() {
    final p = widget.product;
    final nameLower = p.name.toLowerCase();

    // ── 1. Meat & Poultry Quality Card ──
    if (p.isMeat) {
      final badgeTitle = p.qualityBadgeTitle.isNotEmpty ? p.qualityBadgeTitle : 'FSSAI Certified • 100% Antibiotic-Free • <4°C Chilled';
      final specs = p.qualitySpecs.isNotEmpty
          ? p.qualitySpecs
          : {
              'Transit Safety': 'Chilled 0–4°C Vacuum Packed',
              'Chemicals & Growth Promoters': 'Zero (100% Lab Tested)',
            };

      return GestureDetector(
        onTap: () => setState(() => _isBadgeExpanded = !_isBadgeExpanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('🥩 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      badgeTitle,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(_isBadgeExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: const Color(0xFF991B1B)),
                ],
              ),
              if (_isBadgeExpanded) ...[
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFFECACA)),
                const SizedBox(height: 6),
                ...specs.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${entry.key}:', style: const TextStyle(fontSize: 10.5, color: Color(0xFF991B1B))),
                          Flexible(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      );
    }

    // ── 2. Eggs Quality Card ──
    if (p.isEggs) {
      final badgeTitle = p.qualityBadgeTitle.isNotEmpty ? p.qualityBadgeTitle : 'Farm Fresh • Daily Graded • 0% Broken Guarantee';
      final specs = p.qualitySpecs.isNotEmpty
          ? p.qualitySpecs
          : {
              'Farm Standards': 'Bio-Secure Hen Farms',
              'Hen Diet & Feed': '100% Vegetarian Natural Grain',
            };

      return GestureDetector(
        onTap: () => setState(() => _isBadgeExpanded = !_isBadgeExpanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('🥚 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      badgeTitle,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(_isBadgeExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: const Color(0xFF92400E)),
                ],
              ),
              if (_isBadgeExpanded) ...[
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFFDE68A)),
                const SizedBox(height: 6),
                ...specs.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${entry.key}:', style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E))),
                          Flexible(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      );
    }

    // ── 3. Water Cans Quality Card ──
    if (p.isWater) {
      final badgeTitle = p.qualityBadgeTitle.isNotEmpty ? p.qualityBadgeTitle : 'Multi-Stage Purified • Tested Balanced TDS • Sealed Can';
      final specs = p.qualitySpecs.isNotEmpty
          ? p.qualitySpecs
          : {
              'Purification Method': 'RO + UV + Ozonation Treated',
              'Packaging & Safety': 'Food-Grade BPA-Free Sanitized Can',
            };

      return GestureDetector(
        onTap: () => setState(() => _isBadgeExpanded = !_isBadgeExpanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('💧 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      badgeTitle,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF075985)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(_isBadgeExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: const Color(0xFF075985)),
                ],
              ),
              if (_isBadgeExpanded) ...[
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFBAE6FD)),
                const SizedBox(height: 6),
                ...specs.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${entry.key}:', style: const TextStyle(fontSize: 10.5, color: Color(0xFF075985))),
                          Flexible(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      );
    }

    // ── 4. Dairy / Milk Products (Default) ──
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

    return GestureDetector(
      onTap: () => setState(() => _isBadgeExpanded = !_isBadgeExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text('🔬 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    'Certified Daily Batch • $fatVal Fat • $waterVal Water • $tempVal',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(_isBadgeExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: const Color(0xFF166534)),
              ],
            ),
            if (_isBadgeExpanded) ...[
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFBBF7D0)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solid Not Fat (SNF):', style: TextStyle(fontSize: 10.5, color: Color(0xFF166534))),
                  Text(snfVal, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chilling Temp:', style: TextStyle(fontSize: 10.5, color: Color(0xFF166534))),
                  Text(tempVal, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
