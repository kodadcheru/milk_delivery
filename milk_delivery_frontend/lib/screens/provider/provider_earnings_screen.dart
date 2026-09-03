import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/delivery_task_model.dart';
import '../../models/provider_earnings_summary_model.dart';
import '../../models/provider_payout_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../theme/ui_format.dart';

class ProviderEarningsScreen extends StatefulWidget {
  final AppState state;

  const ProviderEarningsScreen({super.key, required this.state});

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'TODAY'; // TODAY, YESTERDAY, 7DAYS, MONTH, CUSTOM
  bool _isLoading = false;
  List<DeliveryTaskModel> _periodTasks = [];
  ProviderEarningsSummaryModel? _earningsSummary;

  @override
  void initState() {
    super.initState();
    _fetchRealTimeEarnings();
  }

  String get _formattedDateStr {
    final y = _selectedDate.year;
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDisplayDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[dt.weekday - 1];
    return '$dayName, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _fetchRealTimeEarnings() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ApiService.fetchProviderEarningsSummary(
        period: _selectedPeriod,
        startDate: _selectedPeriod == 'CUSTOM' ? _formattedDateStr : null,
        endDate: _selectedPeriod == 'CUSTOM' ? _formattedDateStr : null,
      );

      final tasks = await ApiService.fetchDeliveries(
        date: (_selectedPeriod == 'TODAY' || _selectedPeriod == 'YESTERDAY' || _selectedPeriod == 'CUSTOM')
            ? _formattedDateStr
            : null,
      );

      if (mounted) {
        setState(() {
          _earningsSummary = summary;
          _periodTasks = tasks.isNotEmpty ? tasks : widget.state.deliveries;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _periodTasks = widget.state.deliveries;
          _isLoading = false;
        });
      }
    }
  }

  void _selectPeriod(String period) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedPeriod = period;
      if (period == 'TODAY') {
        _selectedDate = DateTime.now();
      } else if (period == 'YESTERDAY') {
        _selectedDate = DateTime.now().subtract(const Duration(days: 1));
      }
    });
    _fetchRealTimeEarnings();
  }

  Future<void> _pickCustomDate() async {
    HapticFeedback.mediumImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00F59B),
              onPrimary: Color(0xFF0A192F),
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        final now = DateTime.now();
        if (picked.year == now.year && picked.month == now.month && picked.day == now.day) {
          _selectedPeriod = 'TODAY';
        } else if (picked.year == now.year && picked.month == now.month && picked.day == (now.day - 1)) {
          _selectedPeriod = 'YESTERDAY';
        } else {
          _selectedPeriod = 'CUSTOM';
        }
      });
      _fetchRealTimeEarnings();
    }
  }

  void _shiftDate(int days) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      final now = DateTime.now();
      if (_selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day) {
        _selectedPeriod = 'TODAY';
      } else if (_selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == (now.day - 1)) {
        _selectedPeriod = 'YESTERDAY';
      } else {
        _selectedPeriod = 'CUSTOM';
      }
    });
    _fetchRealTimeEarnings();
  }

  void _showWithdrawModal(BuildContext context, double amount) {
    HapticFeedback.heavyImpact();
    final hubBank = _earningsSummary?.hub;
    final bName = hubBank?.bankName.isNotEmpty == true ? hubBank!.bankName : 'State Bank of India';
    final bMasked = hubBank?.bankAccountMasked.isNotEmpty == true ? hubBank!.bankAccountMasked : '•••• 4892';
    final bIfsc = hubBank?.bankIfsc.isNotEmpty == true ? hubBank!.bankIfsc : 'SBIN0004892';
    final upiId = hubBank?.upiId.isNotEmpty == true ? hubBank!.upiId : '8885199878@upi';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F59B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFF00F59B), size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.state.isTelugu ? 'తక్షణ బ్యాంక్ ఉపసంహరణ' : 'Instant Bank Payout',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      widget.state.isTelugu ? 'నమోదిత బ్యాంక్ ఖాతాకు నేరుగా బదిలీ' : 'Direct transfer to registered bank account',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.state.isTelugu ? 'ఉపసంహరణకు సిద్ధంగా ఉన్న మొత్తం' : 'AVAILABLE WITHDRAWABLE AMOUNT',
                    style: const TextStyle(color: Color(0xFF00F59B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    UiFormat.price(amount),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🏛️ $bName (A/C $bMasked) • IFSC: $bIfsc',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (upiId.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '📱 UPI: $upiId',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E293B),
                      content: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F59B)),
                          ),
                          const SizedBox(width: 12),
                          Text(widget.state.isTelugu ? 'బదిలీ ప్రాసెస్ చేయబడుతోంది...' : 'Processing instant payout transfer...'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  final payout = await ApiService.requestInstantPayout(amount: amount);
                  if (!context.mounted) return;

                  if (payout != null) {
                    _fetchRealTimeEarnings();
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF00F59B)),
                            const SizedBox(width: 8),
                            Text(
                              widget.state.isTelugu ? 'పేఅవుట్ విజయవంతమైంది!' : 'Payout Settled! ✅',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.state.isTelugu
                                  ? '₹${payout.amount.toStringAsFixed(2)} మీ రిజిస్టర్డ్ బ్యాంక్ ఖాతాకు బదిలీ చేయబడింది.'
                                  : '₹${payout.amount.toStringAsFixed(2)} has been transferred via IMPS to your registered bank account.',
                              style: TextStyle(color: Colors.grey.shade300, fontSize: 13.5),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🏛️ ${payout.bankName} (${payout.bankAccountMasked})',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ref: #${payout.paymentReference}',
                                    style: const TextStyle(color: Color(0xFF00F59B), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  if (payout.upiId.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('UPI: ${payout.upiId}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('OK', style: TextStyle(color: Color(0xFF00F59B), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.red.shade700,
                        content: Text(
                          ApiService.lastError != null && ApiService.lastError!.isNotEmpty
                              ? ApiService.lastError!
                              : 'Failed to process instant payout transfer.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.account_balance_rounded, size: 18),
                label: Text(
                  widget.state.isTelugu ? 'ఇప్పుడే బదిలీ చేయండి' : 'Initiate Instant Transfer',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F59B),
                  foregroundColor: const Color(0xFF0A192F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isTelugu = state.isTelugu;

    // ── 1. Calculate Real-Time Dynamic Metrics from Live Backend Summary & Tasks ──
    final summary = _earningsSummary;
    final activeTasks = _periodTasks.isNotEmpty ? _periodTasks : state.deliveries;

    double computedLitres = 0.0;
    double computedEarnings = 0.0;

    double morningLitres = 0.0;
    double morningEarnings = 0.0;
    int morningDrops = 0;

    double eveningLitres = 0.0;
    double eveningEarnings = 0.0;
    int eveningDrops = 0;

    final Map<String, Map<String, dynamic>> productStatsMap = {};

    for (final task in activeTasks) {
      final sub = task.subscriptionDetail;
      final prod = sub?.productDetail;
      final pName = prod?.name ?? (task.productName.isNotEmpty ? task.productName : 'Farm Fresh Milk');
      final pPrice = (prod?.pricePerUnit ?? (sub?.displayPrice ?? task.pricePerUnit)).toDouble();
      final qty = (sub?.quantity ?? task.quantity).toDouble();
      final itemRev = pPrice * qty;

      computedEarnings += itemRev;

      // Real Litres Calculation
      double itemLitres = 0.0;
      final packStr = (task.packSize.isNotEmpty ? task.packSize : (sub?.packSize ?? prod?.unitQuantity ?? '1 Litre')).toLowerCase();
      if (packStr.contains('500') || packStr.contains('half')) {
        itemLitres = 0.5 * qty;
      } else if (packStr.contains('2') || packStr.contains('2l')) {
        itemLitres = 2.0 * qty;
      } else {
        itemLitres = 1.0 * qty;
      }

      final isLiquid = pName.toLowerCase().contains('milk') ||
          pName.toLowerCase().contains('buttermilk') ||
          pName.toLowerCase().contains('water') ||
          pName.toLowerCase().contains('curd');

      if (isLiquid) {
        computedLitres += itemLitres;
      }

      // Shift Split from task slot time
      final slotLower = task.slotTime.toLowerCase();
      final isMorning = slotLower.contains('am') || slotLower.contains('morning') || slotLower.contains('05:');

      if (isMorning) {
        morningEarnings += itemRev;
        morningDrops++;
        if (isLiquid) morningLitres += itemLitres;
      } else {
        eveningEarnings += itemRev;
        eveningDrops++;
        if (isLiquid) eveningLitres += itemLitres;
      }

      // Product Ledger Aggregation
      if (!productStatsMap.containsKey(pName)) {
        productStatsMap[pName] = {
          'name': pName,
          'qty': 0,
          'litres': 0.0,
          'revenue': 0.0,
          'icon': prod?.icon ?? '🥛',
          'isLiquid': isLiquid,
          'unitPrice': pPrice,
        };
      }
      productStatsMap[pName]!['qty'] = (productStatsMap[pName]!['qty'] as int) + qty.toInt();
      productStatsMap[pName]!['litres'] = (productStatsMap[pName]!['litres'] as double) + itemLitres;
      productStatsMap[pName]!['revenue'] = (productStatsMap[pName]!['revenue'] as double) + itemRev;
    }

    final totalEarnings = summary != null ? summary.grossRevenue : computedEarnings;
    final totalLitres = summary != null ? summary.totalLitres : computedLitres;
    final cashCod = summary?.cashCollected ?? 0.0;
    final prepaidRev = summary?.prepaidRevenue ?? (totalEarnings - cashCod);
    final commission = summary?.platformCommission ?? (totalEarnings * 0.05);
    final withdrawable = summary != null
        ? summary.netWithdrawableAmount
        : ((prepaidRev - commission) > 0 ? (prepaidRev - commission) : 0.0);

    final totalDrops = summary != null ? summary.totalDeliveries : activeTasks.length;
    final deliveredDrops = summary != null
        ? summary.completedDeliveries
        : activeTasks.where((d) => d.isDelivered || d.status == 'DELIVERED').length;

    final productStatsList = productStatsMap.values.toList();
    final avgPerLitre = totalLitres > 0 ? (totalEarnings / totalLitres) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F59B), Color(0xFF0D7C66)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0A192F), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTelugu ? 'హబ్ ఆదాయం & విక్రయాలు' : 'Hub Real-Time Earnings',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Text(
                  isTelugu ? 'రియల్-టైమ్ లైవ్ సేల్స్ & లీటర్ల లెడ్జర్' : 'Live Volume & Revenue Analytics',
                  style: const TextStyle(color: Color(0xFF00F59B), fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF00F59B)),
            tooltip: 'Pick Date',
            onPressed: _pickCustomDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Live API',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await _fetchRealTimeEarnings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0D7C66),
                    content: Text(isTelugu ? 'లైవ్ డేటా నవీకరించబడింది!' : 'Live API earnings refreshed!'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00F59B)),
            )
          : RefreshIndicator(
              color: const Color(0xFF00F59B),
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: _fetchRealTimeEarnings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Period Selector Filter Chips (Sliding Pills) ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _periodChip('TODAY', isTelugu ? 'ఈరోజు (Today)' : 'Today'),
                          const SizedBox(width: 8),
                          _periodChip('YESTERDAY', isTelugu ? 'నిన్న (Yesterday)' : 'Yesterday'),
                          const SizedBox(width: 8),
                          _periodChip('7DAYS', isTelugu ? 'గత 7 రోజులు' : 'Last 7 Days'),
                          const SizedBox(width: 8),
                          _periodChip('MONTH', isTelugu ? 'ఈ నెల' : 'This Month'),
                          const SizedBox(width: 8),
                          _periodChip('CUSTOM', isTelugu ? 'తేదీ ఎంచుకోండి' : 'Custom Date', isCustom: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 2. Active Date Navigation & Banner Bar ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _shiftDate(-1),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickCustomDate,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.event_available_rounded, color: Color(0xFF00F59B), size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _formatDisplayDate(_selectedDate),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _selectedDate.isBefore(DateTime.now()) ? () => _shiftDate(1) : null,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _selectedDate.isBefore(DateTime.now()) ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: _selectedDate.isBefore(DateTime.now()) ? Colors.white : Colors.white24,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── 3. Ultra-Premium Holographic Master Earnings Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A3A2A), Color(0xFF0D5A42), Color(0xFF0F7655)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF00F59B).withValues(alpha: 0.3), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F59B).withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A192F).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF00F59B).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00F59B),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isTelugu ? 'లైవ్ స్థూల ఆదాయం' : 'GROSS REALIZED REVENUE',
                                      style: const TextStyle(
                                        color: Color(0xFF00F59B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _selectedPeriod == 'TODAY'
                                      ? (isTelugu ? 'ఈరోజు బ్యాచ్' : 'Today Batch')
                                      : _selectedPeriod,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            UiFormat.price(totalEarnings),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF00F59B), size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isTelugu
                                      ? '$deliveredDrops/$totalDrops డ్రాప్‌లు పూర్తయ్యాయి • ₹${avgPerLitre.toStringAsFixed(1)}/లీటరు సగటు'
                                      : '$deliveredDrops/$totalDrops drops completed • ₹${avgPerLitre.toStringAsFixed(1)} avg/L',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('💵', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'COD In Hand: ${UiFormat.price(cashCod)}',
                                      style: const TextStyle(color: Color(0xFFFDE047), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 14, color: Colors.white24),
                                Row(
                                  children: [
                                    const Text('💳', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Online: ${UiFormat.price(prepaidRev)}',
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () => _showWithdrawModal(context, withdrawable > 0 ? withdrawable : totalEarnings),
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: Text(
                                isTelugu
                                    ? 'తక్షణ బ్యాంక్ బదిలీ: ${UiFormat.price(withdrawable > 0 ? withdrawable : totalEarnings)} ⚡'
                                    : 'Instant Hub Payout: ${UiFormat.price(withdrawable > 0 ? withdrawable : totalEarnings)} ⚡',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00F59B),
                                foregroundColor: const Color(0xFF0A192F),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── 4. Operational 2x2 Metric Grid ──
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                            icon: '🥛',
                            title: isTelugu ? 'మొత్తం పాలు విక్రయం' : 'Total Milk Sold',
                            value: '${totalLitres.toStringAsFixed(1)} L',
                            subtitle: isTelugu ? 'డిస్పాచ్ వాల్యూమ్' : 'Dispatched volume',
                            color: const Color(0xFF38BDF8),
                            accentGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricTile(
                            icon: '💵',
                            title: isTelugu ? 'చేతిలో ఉన్న COD నగదు' : 'COD Cash in Hand',
                            value: UiFormat.price(cashCod),
                            subtitle: isTelugu ? 'డోర్‌స్టెప్ వసూలు' : 'Collected Doorstep',
                            color: const Color(0xFFF59E0B),
                            accentGradient: const [Color(0xFFD97706), Color(0xFFF59E0B)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                            icon: '💳',
                            title: isTelugu ? 'ఆన్‌లైన్ ప్రీపెయిడ్' : 'Online Prepaid',
                            value: UiFormat.price(prepaidRev),
                            subtitle: isTelugu ? 'ప్లాట్‌ఫారమ్ ఎస్క్రో' : 'In Platform Escrow',
                            color: const Color(0xFF38BDF8),
                            accentGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricTile(
                            icon: '⚙️',
                            title: isTelugu ? 'కమీషన్ (5%)' : 'Platform Fee (5%)',
                            value: UiFormat.price(commission),
                            subtitle: isTelugu ? 'సర్వీస్ ఫీజు' : 'Platform Commission',
                            color: const Color(0xFFA855F7),
                            accentGradient: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ── 5. Shift Earnings Split (Morning vs Evening) ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTelugu ? 'షిఫ్ట్ వారీ ఆదాయ విభజన' : 'Shift-Wise Earnings Breakdown',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'AM / PM Shifts',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        children: [
                          _shiftRow(
                            icon: '🌅',
                            title: isTelugu ? 'ఉదయం బ్యాచ్ (Morning 05:30 AM)' : 'Morning Batch (05:30 AM)',
                            litres: morningLitres,
                            earnings: morningEarnings,
                            drops: morningDrops,
                            accent: const Color(0xFF00F59B),
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          _shiftRow(
                            icon: '🌙',
                            title: isTelugu ? 'సాయంత్రం బ్యాచ్ (Evening 06:00 PM)' : 'Evening Batch (06:00 PM)',
                            litres: eveningLitres,
                            earnings: eveningEarnings,
                            drops: eveningDrops,
                            accent: const Color(0xFF38BDF8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── 6. Product-by-Product Sales & Volume Breakdown ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTelugu ? 'ఉత్పత్తి వారీ అమ్మకాలు' : 'Product Sales & Litre Volume',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${productStatsList.length} Items Sold',
                          style: const TextStyle(color: Color(0xFF00F59B), fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (productStatsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 32)),
                            const SizedBox(height: 8),
                            Text(
                              isTelugu ? 'ఈ తేదీకి ఆర్డర్లు / డెలివరీలు నమోదు కాలేదు' : 'No deliveries recorded for this date',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      ...productStatsList.map((p) => _buildProductItemRow(p, totalEarnings, isTelugu)),

                    const SizedBox(height: 20),

                    // ── 7. Direct Daily Bank Settlement Card ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1424),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF00F59B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F59B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF00F59B), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTelugu ? 'నేరుగా బ్యాంక్ ఖాతాకు జమ రక్షణ' : 'Direct Daily Bank Settlement',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isTelugu
                                      ? 'ఈ తేదీకి సంబంధించిన మొత్తం రికన్సిల్ చేయబడింది మరియు నేరుగా మీ నమోదిత బ్యాంక్ ఖాతాకు జమ అవుతుంది.'
                                      : 'Earnings for this date reconciled and settled directly to your registered bank account.',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 8. Settlement Receipts & Payout Ledger ──
                    _buildSettlementReceiptsSection(_earningsSummary, isTelugu),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _periodChip(String key, String label, {bool isCustom = false}) {
    final isSelected = _selectedPeriod == key;
    return GestureDetector(
      onTap: () {
        if (isCustom) {
          _pickCustomDate();
        } else {
          _selectPeriod(key);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00F59B) : const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00F59B) : Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00F59B).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom) ...[
              Icon(Icons.calendar_today_rounded, size: 12, color: isSelected ? const Color(0xFF0A192F) : Colors.white70),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0A192F) : Colors.grey.shade300,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile({
    required String icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required List<Color> accentGradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: accentGradient),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _shiftRow({
    required String icon,
    required String title,
    required double litres,
    required double earnings,
    required int drops,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '${litres.toStringAsFixed(1)} Litres • $drops Drops Dispatched',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          UiFormat.price(earnings),
          style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildProductItemRow(Map<String, dynamic> p, double totalRev, bool isTelugu) {
    final name = p['name']?.toString() ?? 'Fresh Milk';
    final icon = p['icon']?.toString() ?? '🥛';
    final qty = (p['qty'] as num?)?.toInt() ?? 1;
    final litres = (p['litres'] as num?)?.toDouble() ?? 1.0;
    final rev = (p['revenue'] as num?)?.toDouble() ?? 65.0;
    final isLiquid = p['isLiquid'] == true;
    final percent = totalRev > 0 ? (rev / totalRev).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.state.translateProduct(name),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLiquid
                          ? '$qty Packs ($litres Litres)'
                          : '$qty Units Sold',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    UiFormat.price(rev),
                    style: const TextStyle(color: Color(0xFF00F59B), fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  Text(
                    '${(percent * 100).toStringAsFixed(0)}% of total',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F59B)),
              minHeight: 4.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementReceiptsSection(ProviderEarningsSummaryModel? summary, bool isTelugu) {
    final recentPayouts = summary?.recentPayouts ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF00F59B), size: 18),
                const SizedBox(width: 8),
                Text(
                  isTelugu ? 'పేఅవుట్ & సెటిల్‌మెంట్ రసీదులు' : 'Payout & Settlement Receipts',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${recentPayouts.length} Settled',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentPayouts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white38, size: 30),
                const SizedBox(height: 8),
                Text(
                  isTelugu ? 'ఇంకా సెటిల్‌మెంట్ రసీదులు లేవు' : 'No payout settlement receipts yet',
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  isTelugu ? 'తక్షణ బదిలీని ప్రారంభించడానికి పై బటన్ క్లిక్ చేయండి' : 'Click the instant payout button above to transfer earnings',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ],
            ),
          )
        else
          ...recentPayouts.map((p) => _buildReceiptCard(p, isTelugu)),
      ],
    );
  }

  Widget _buildReceiptCard(ProviderPayoutModel p, bool isTelugu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F59B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00F59B), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#${p.paymentReference}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F59B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.status,
                  style: const TextStyle(color: Color(0xFF00F59B), fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏛️ ${p.bankName} (${p.bankAccountMasked})',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  if (p.date.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.date,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
              Text(
                UiFormat.price(p.amount),
                style: const TextStyle(color: Color(0xFF00F59B), fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (p.totalRevenue > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gross: ${UiFormat.price(p.totalRevenue)}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  Text('COD: ${UiFormat.price(p.cashCollected)}', style: const TextStyle(color: Color(0xFFFDE047), fontSize: 10)),
                  Text('Fee: ${UiFormat.price(p.platformCommission)}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
