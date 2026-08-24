import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../models/live_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_format.dart';
import '../../widgets/doorstep_camera_dialog.dart';

class DayWiseOrdersScreen extends StatefulWidget {
  final AppState state;
  final String role; // 'DRIVER' or 'PROVIDER' / 'HUB_MANAGER'

  const DayWiseOrdersScreen({
    super.key,
    required this.state,
    this.role = 'DRIVER',
  });

  @override
  State<DayWiseOrdersScreen> createState() => _DayWiseOrdersScreenState();
}

class _DayWiseOrdersScreenState extends State<DayWiseOrdersScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<DeliveryTaskModel> _dayDeliveries = [];
  List<LiveOrderModel> _dayLiveOrders = [];

  // Filters
  String _statusFilter = 'ALL'; // ALL, PENDING, DELIVERED, SKIPPED
  String _typeFilter = 'ALL'; // ALL, SUBSCRIPTION, EXPRESS
  String _slotFilter = DateTime.now().hour >= 12 ? 'EVENING' : 'MORNING'; // Auto-switches after 12:00 PM to EVENING, after 12:00 AM to MORNING
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDayOrders();
  }

  String get _formattedDateStr {
    final year = _selectedDate.year;
    final month = _selectedDate.month.toString().padLeft(2, '0');
    final day = _selectedDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _loadDayOrders() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _formattedDateStr;
      final tasks = await ApiService.fetchDeliveries(date: dateStr);
      final orders = await ApiService.fetchLiveOrders();

      // Filter live orders by date if matching
      final filteredOrders = orders.where((o) {
        if (o.deliveryDate.isNotEmpty) {
          return o.deliveryDate.startsWith(dateStr);
        }
        return _isToday;
      }).toList();

      if (mounted) {
        setState(() {
          _dayDeliveries = tasks;
          _dayLiveOrders = filteredOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectPresetDate(int offsetDays) {
    setState(() {
      _selectedDate = DateTime.now().add(Duration(days: offsetDays));
    });
    _loadDayOrders();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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
      setState(() => _selectedDate = picked);
      _loadDayOrders();
    }
  }

  void _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📞 Dialing $phone...')),
        );
      }
    }
  }

  void _sendWhatsApp(String name, String phone, String msg) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMsg = Uri.encodeComponent(msg);
    final whatsappUrl = Uri.parse('https://wa.me/91$clean?text=$encodedMsg');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('💬 WhatsApp message queued for $name')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter tasks
    final filteredTasks = _dayDeliveries.where((t) {
      // Status filter
      if ((_statusFilter == 'PENDING' || _statusFilter == 'ACTIVE') && t.status != 'PENDING') return false;
      if ((_statusFilter == 'DELIVERED' || _statusFilter == 'COMPLETED') && t.status != 'DELIVERED') return false;
      if (_statusFilter == 'SKIPPED' && t.status != 'SKIPPED') return false;

      // Type filter
      if (_typeFilter == 'EXPRESS') return false;

      // Slot filter
      if (_slotFilter == 'MORNING' && !t.slotTime.contains('05:30') && !t.slotTime.contains('07:00') && !t.slotTime.contains('AM')) return false;
      if (_slotFilter == 'EVENING' && !t.slotTime.contains('PM') && !t.slotTime.contains('17:') && !t.slotTime.contains('18:')) return false;

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = t.customerName.toLowerCase().contains(q);
        final matchAddr = t.deliveryAddress.toLowerCase().contains(q);
        final matchPhone = t.customerPhone.contains(q);
        final matchId = t.id.toString().contains(q);
        return matchCust || matchAddr || matchPhone || matchId;
      }
      return true;
    }).toList();

    final filteredExpress = _dayLiveOrders.where((o) {
      if (_typeFilter == 'SUBSCRIPTION') return false;
      if ((_statusFilter == 'PENDING' || _statusFilter == 'ACTIVE') && o.status == 'DELIVERED') return false;
      if ((_statusFilter == 'DELIVERED' || _statusFilter == 'COMPLETED') && o.status != 'DELIVERED') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCust = o.customerName.toLowerCase().contains(q);
        final matchAddr = o.deliveryAddress.toLowerCase().contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        return matchCust || matchAddr || matchId;
      }
      return true;
    }).toList();

    final totalCount = filteredTasks.length + filteredExpress.length;
    final pendingCount = filteredTasks.where((t) => t.status == 'PENDING').length +
        filteredExpress.where((o) => o.status != 'DELIVERED').length;
    final deliveredCount = filteredTasks.where((t) => t.status == 'DELIVERED').length +
        filteredExpress.where((o) => o.status == 'DELIVERED').length;

    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      body: RefreshIndicator(
        onRefresh: _loadDayOrders,
        color: UiTone.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Date Selector Header Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: UiGradient.primary,
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  boxShadow: UiShadow.card,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(UiRadius.xs),
                              ),
                              child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isToday ? 'Today\'s Roster 📅' : 'Day-wise Delivery Roster',
                                  style: UiText.label.copyWith(color: Colors.white70, fontSize: 11),
                                ),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: UiText.h2.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickCustomDate,
                          icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                          label: Text('Pick Date', style: UiText.label.copyWith(fontSize: 11, color: UiTone.primary)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: UiTone.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick Date Chips
                    Row(
                      children: [
                        _buildQuickDateChip('Yesterday', -1),
                        const SizedBox(width: 6),
                        _buildQuickDateChip('Today', 0),
                        const SizedBox(width: 6),
                        _buildQuickDateChip('Tomorrow', 1),
                        const SizedBox(width: 6),
                        _buildQuickDateChip('+2 Days', 2),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── 2. Stat Overview Row ──
              Row(
                children: [
                  _buildSummaryBadge('📦 Total Orders', '$totalCount', UiTone.primary),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('⚡ Active', '$pendingCount', UiTone.warning),
                  const SizedBox(width: 8),
                  _buildSummaryBadge('✅ Completed', '$deliveredCount', UiTone.success),
                ],
              ),
              const SizedBox(height: 14),

              // ── 3. Search Bar ──
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by customer, address, or order ID...',
                  hintStyle: UiText.body.copyWith(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: UiTone.softText, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: UiTone.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    borderSide: const BorderSide(color: UiTone.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    borderSide: const BorderSide(color: UiTone.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    borderSide: const BorderSide(color: UiTone.primary, width: 1.5),
                  ),
                ),
              ),
              // ── 3b. Shift Selector Bar (Morning vs Evening) ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: UiTone.surfaceMuted,
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                  border: Border.all(color: UiTone.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _slotFilter = 'ALL'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _slotFilter == 'ALL' ? UiTone.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'All Shifts',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _slotFilter == 'ALL' ? Colors.white : UiTone.softText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _slotFilter = 'MORNING'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _slotFilter == 'MORNING' ? UiTone.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('☀️ ', style: TextStyle(fontSize: 11)),
                              Text(
                                'Morning',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _slotFilter == 'MORNING' ? Colors.white : UiTone.softText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _slotFilter = 'EVENING'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _slotFilter == 'EVENING' ? const Color(0xFF7C3AED) : Colors.transparent,
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🌙 ', style: TextStyle(fontSize: 11)),
                              Text(
                                'Evening',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _slotFilter == 'EVENING' ? Colors.white : UiTone.softText,
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

              // ── 4. Filter Chips (Active / Completed / Pending / Delivered / Type) ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', '👥 All', _statusFilter == 'ALL', (v) => setState(() => _statusFilter = 'ALL')),
                    const SizedBox(width: 6),
                    _buildFilterChip('ACTIVE', '⚡ Active ($pendingCount)', _statusFilter == 'ACTIVE', (v) => setState(() => _statusFilter = 'ACTIVE')),
                    const SizedBox(width: 6),
                    _buildFilterChip('COMPLETED', '✅ Completed ($deliveredCount)', _statusFilter == 'COMPLETED', (v) => setState(() => _statusFilter = 'COMPLETED')),
                    const SizedBox(width: 6),
                    _buildFilterChip('PENDING', '⏳ Pending', _statusFilter == 'PENDING', (v) => setState(() => _statusFilter = 'PENDING')),
                    const SizedBox(width: 6),
                    _buildFilterChip('DELIVERED', '📦 Delivered', _statusFilter == 'DELIVERED', (v) => setState(() => _statusFilter = 'DELIVERED')),
                    const SizedBox(width: 6),
                    _buildFilterChip('SKIPPED', '⏭️ Skipped', _statusFilter == 'SKIPPED', (v) => setState(() => _statusFilter = 'SKIPPED')),
                    const SizedBox(width: 12),
                    Container(height: 18, width: 1, color: UiTone.surfaceBorder),
                    const SizedBox(width: 12),
                    _buildFilterChip('ALL_TYPE', '🥛 Subscriptions', _typeFilter == 'SUBSCRIPTION', (v) => setState(() => _typeFilter = _typeFilter == 'SUBSCRIPTION' ? 'ALL' : 'SUBSCRIPTION')),
                    const SizedBox(width: 6),
                    _buildFilterChip('EXPRESS_TYPE', '⚡ Express', _typeFilter == 'EXPRESS', (v) => setState(() => _typeFilter = _typeFilter == 'EXPRESS' ? 'ALL' : 'EXPRESS')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 5. Orders List ──
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: UiTone.primary),
                  ),
                )
              else if (filteredTasks.isEmpty && filteredExpress.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: UiTone.surface,
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    border: Border.all(color: UiTone.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_rounded, size: 48, color: UiTone.softText),
                      const SizedBox(height: 12),
                      Text(
                        'No deliveries found for $_formattedDateStr',
                        style: UiText.bodyStrong.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text('Try selecting a different date or clearing filters.', style: UiText.body.copyWith(fontSize: 11)),
                    ],
                  ),
                )
              else ...[
                // Express Orders Card List
                ...filteredExpress.map((ord) => _buildExpressCard(ord)),

                // Delivery Tasks Card List
                ...filteredTasks.map((task) => _buildDeliveryTaskCard(task)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDateChip(String label, int offsetDays) {
    final date = DateTime.now().add(Duration(days: offsetDays));
    final isSelected = _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectPresetDate(offsetDays),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? UiTone.primary : UiTone.surfaceMuted,
            borderRadius: BorderRadius.circular(UiRadius.xs),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: UiText.label.copyWith(
              fontSize: 11,
              color: isSelected ? UiTone.surface : UiTone.softText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(UiRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(count, style: UiText.h2.copyWith(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: UiText.caption.copyWith(fontSize: 10, color: UiTone.softText), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isSelected, Function(bool) onSelected) {
    return InkWell(
      onTap: () => onSelected(!isSelected),
      borderRadius: BorderRadius.circular(UiRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary : UiTone.surface,
          borderRadius: BorderRadius.circular(UiRadius.lg),
          border: Border.all(color: isSelected ? UiTone.primary : UiTone.surfaceBorder),
        ),
        child: Text(
          label,
          style: UiText.label.copyWith(
            fontSize: 11,
            color: isSelected ? UiTone.surface : UiTone.softText,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTaskCard(DeliveryTaskModel task) {
    final product = task.subscriptionDetail?.productDetail;
    final phone = task.customerPhone.isNotEmpty ? task.customerPhone : '+91 9876543210';
    final isDelivered = task.status == 'DELIVERED';
    final isSkipped = task.status == 'SKIPPED';
    final driverDisplay = task.driverDetail?.fullName ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(
          color: isDelivered
              ? UiTone.success.withValues(alpha: 0.3)
              : (isSkipped ? UiTone.warning.withValues(alpha: 0.3) : UiTone.surfaceBorder),
          width: isDelivered || isSkipped ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Customer + Status
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: UiTone.primarySoft,
                    borderRadius: BorderRadius.circular(UiRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      product?.icon ?? '🥛',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.customerName,
                        style: UiText.bodyStrong.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product?.name ?? 'Milk Subscription'} • ${task.subscriptionDetail?.quantity ?? 1}x ${task.subscriptionDetail?.packSize ?? "Unit"}',
                        style: UiText.body.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? UiTone.successSoft
                        : (isSkipped ? UiTone.warningSoft : UiTone.primarySoft),
                    borderRadius: BorderRadius.circular(UiRadius.xs),
                  ),
                  child: Text(
                    task.status,
                    style: UiText.caption.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isDelivered
                          ? UiTone.success
                          : (isSkipped ? UiTone.warning : UiTone.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Address & Slot
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: UiTone.surfaceMuted,
                borderRadius: BorderRadius.circular(UiRadius.xs),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: UiTone.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.deliveryAddress,
                          style: UiText.body.copyWith(fontSize: 11, color: UiTone.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: UiTone.softText),
                      const SizedBox(width: 6),
                      Text(
                        '📅 ${task.deliveryDate} • Slot: ${task.slotTime}',
                        style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.ink, fontWeight: FontWeight.bold),
                      ),
                      if (driverDisplay.isNotEmpty) ...[
                        Text(' • ', style: UiText.caption.copyWith(color: UiTone.softText)),
                        Text('🛵 $driverDisplay', style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.primary, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Action Row
            Row(
              children: [
                IconButton(
                  onPressed: () => _callPhone(phone),
                  icon: const Icon(Icons.phone_rounded, color: UiTone.primary, size: 20),
                  tooltip: 'Call Customer',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 12),
                ),
                IconButton(
                  onPressed: () => _sendWhatsApp(task.customerName, phone, 'Hello ${task.customerName}, your milk delivery is scheduled for today!'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: UiTone.success, size: 19),
                  tooltip: 'WhatsApp Customer',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 12),
                ),
                const Spacer(),
                if (!isDelivered && !isSkipped) ...[
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await ApiService.skipDelivery(task.id);
                      if (ok) {
                        _loadDayOrders();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('⏭️ Delivery skipped')),
                          );
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      foregroundColor: UiTone.warning,
                      side: const BorderSide(color: UiTone.warning),
                    ),
                    child: Text('Skip ⏭️', style: UiText.caption.copyWith(fontSize: 10.5, color: UiTone.warning)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      DoorstepCameraDialog.show(
                        context,
                        customerName: task.customerName,
                        deliveryAddress: task.deliveryAddress,
                        latitude: task.customerLatitude,
                        longitude: task.customerLongitude,
                        onConfirmProof: (proofUrl) async {
                          final ok = await ApiService.completeDelivery(task.id, proofUrl);
                          if (ok) {
                            _loadDayOrders();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: UiTone.primary,
                                  content: Text('✅ Delivery completed!'),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 14),
                    label: Text('Deliver 📸', style: UiText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.bold, color: UiTone.surface)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      backgroundColor: UiTone.primary,
                      foregroundColor: UiTone.surface,
                    ),
                  ),
                ] else if (isDelivered) ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: UiTone.success, size: 16),
                      const SizedBox(width: 4),
                      Text('Delivered', style: UiText.bodyStrong.copyWith(fontSize: 11, color: UiTone.success)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpressCard(LiveOrderModel ord) {
    final isDelivered = ord.status == 'DELIVERED';
    final isEvening = ord.deliverySlot.toUpperCase().contains('PM') || ord.deliverySlot.toUpperCase().contains('17:') || ord.deliverySlot.toUpperCase().contains('18:');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiRadius.md),
        side: const BorderSide(color: UiTone.error, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: UiTone.errorSoft, borderRadius: BorderRadius.circular(UiRadius.sm)),
                  child: const Icon(Icons.flash_on_rounded, color: UiTone.error, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ord.customerName, style: UiText.bodyStrong.copyWith(fontSize: 13.5)),
                      Text('${ord.id} • ${UiFormat.price(ord.totalAmount)}', style: UiText.caption.copyWith(fontSize: 11, color: UiTone.error, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        '${isEvening ? "🌙" : "☀️"} 📅 ${ord.deliveryDate.isNotEmpty ? ord.deliveryDate : "Today"} • ${ord.deliverySlot}',
                        style: UiText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: isEvening ? const Color(0xFF7C3AED) : const Color(0xFF0D7C66)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isDelivered ? UiTone.successSoft : UiTone.errorSoft, borderRadius: BorderRadius.circular(UiRadius.xs)),
                  child: Text(ord.status, style: UiText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w800, color: isDelivered ? UiTone.success : UiTone.error)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('📍 ${ord.deliveryAddress}', style: UiText.body.copyWith(fontSize: 11, color: UiTone.ink)),
            if (!isDelivered && widget.role == 'DRIVER') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final otpController = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                          title: Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, color: UiTone.error),
                              const SizedBox(width: 8),
                              Text('Complete ${ord.id}', style: UiText.h2.copyWith(fontSize: 16)),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer: ${ord.customerName.isNotEmpty ? ord.customerName : "Customer"}', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Address: ${ord.deliveryAddress}', style: UiText.body.copyWith(fontSize: 12)),
                              const SizedBox(height: 14),
                              Text('Enter 4-Digit Customer OTP:', style: UiText.bodyStrong.copyWith(fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                decoration: InputDecoration(
                                  hintText: 'e.g. ${ord.deliveryOtp}',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                if (otpController.text.trim() == ord.deliveryOtp) {
                                  Navigator.pop(ctx);
                                  widget.state.updateOrderStatus(ord.id, 'DELIVERED');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: UiTone.primary,
                                        content: Text('🎉 Express Order ${ord.id} Delivered Successfully!'),
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: UiTone.error,
                                      content: Text('❌ Invalid OTP.'),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: UiTone.primary, foregroundColor: Colors.white),
                              child: const Text('Verify & Complete'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                    label: Text('Complete Delivery', style: UiText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.bold, color: UiTone.surface)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      backgroundColor: UiTone.primary,
                      foregroundColor: UiTone.surface,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
