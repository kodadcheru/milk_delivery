import 'package:flutter/material.dart';
import '../../models/customer_address_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import 'address_book_screen.dart';
import 'map_location_picker_screen.dart';
import 'subscription_success_screen.dart';

class SubscriptionAddressSelectionScreen extends StatefulWidget {
  final ProductModel product;
  final int quantity;
  final String schedule; // DAILY, ALTERNATE, WEEKDAYS
  final String packSize;
  final String timeSlot;
  final String durationLabel;
  final int totalDeliveryDays;
  final double singleDeliveryCost;
  final double totalCost;
  final String deliveryInstructions;
  final AppState state;

  const SubscriptionAddressSelectionScreen({
    super.key,
    required this.product,
    required this.quantity,
    required this.schedule,
    required this.packSize,
    required this.timeSlot,
    required this.durationLabel,
    required this.totalDeliveryDays,
    required this.singleDeliveryCost,
    required this.totalCost,
    required this.deliveryInstructions,
    required this.state,
  });

  @override
  State<SubscriptionAddressSelectionScreen> createState() =>
      _SubscriptionAddressSelectionScreenState();
}

class _SubscriptionAddressSelectionScreenState
    extends State<SubscriptionAddressSelectionScreen> {
  CustomerAddressModel? _selectedAddress;
  bool _isSubmitting = false;
  
  late String _selectedSlot;
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>>? _slotsData;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.timeSlot;
    if (widget.deliveryInstructions.isNotEmpty) {
      _notesController.text = widget.deliveryInstructions;
    }
    _fetchSlots();

    // Default selection to activeAddress or default saved address
    _selectedAddress = widget.state.activeAddress;
    if (_selectedAddress == null && widget.state.savedAddresses.isNotEmpty) {
      _selectedAddress = widget.state.savedAddresses.firstWhere(
        (a) => a.isDefault,
        orElse: () => widget.state.savedAddresses.first,
      );
    }
    // Fetch saved addresses if list is empty
    if (widget.state.savedAddresses.isEmpty) {
      widget.state.fetchSavedAddresses().then((_) {
        if (mounted && _selectedAddress == null && widget.state.savedAddresses.isNotEmpty) {
          setState(() {
            _selectedAddress = widget.state.savedAddresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => widget.state.savedAddresses.first,
            );
          });
        }
      });
    }
  }

  Future<void> _fetchSlots() async {
    final slots = await ApiService.fetchSlotAvailability();
    if (mounted) setState(() => _slotsData = slots);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _confirmSubscription() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Mandatory: Please select a delivery address to proceed!'),
        ),
      );
      return;
    }

    final currentUser = widget.state.currentUser;
    final balance = currentUser?.walletBalance ?? 0.0;
    if (balance < widget.totalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Insufficient wallet balance!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    widget.state.selectActiveAddress(_selectedAddress!);

    try {
      await widget.state.createNewSubscription(
        widget.product,
        widget.quantity,
        widget.schedule,
        deliveryAddress: _selectedAddress!.summaryAddress,
        deliverySlot: _selectedSlot,
        deliveryLatitude: _selectedAddress!.latitude,
        deliveryLongitude: _selectedAddress!.longitude,
        deliveryInstructions: _notesController.text.trim(),
        packSize: widget.packSize,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('❌ $errorMsg'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (c) => SubscriptionSuccessScreen(
          productName: widget.product.name,
          packSize: widget.packSize,
          quantity: widget.quantity,
          schedule: widget.schedule,
          slot: _selectedSlot,
          address: _selectedAddress!.summaryAddress,
          totalCost: widget.totalCost,
          state: widget.state,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  String _getSlotIcon(String slotName, int index) {
    final upper = slotName.toUpperCase();
    if (upper.contains('PM') || upper.contains('EVENING')) return '🌙';
    if (upper.contains('05:30')) return '⚡';
    if (upper.contains('07:00')) return '🌅';
    return '☀️';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final savedAddrs = widget.state.savedAddresses;
        if (_selectedAddress == null && savedAddrs.isNotEmpty) {
          _selectedAddress = widget.state.activeAddress ?? savedAddrs.first;
        }

        final currentUser = widget.state.currentUser;
        final balance = currentUser?.walletBalance ?? 0.0;
        final hasEnoughBalance = balance >= widget.totalCost;
        final amountNeeded = widget.totalCost - balance;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule & Checkout',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Step 2 of 2',
                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Plan Recap Card (compact) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.product.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.quantity}x ${widget.packSize} • ${widget.schedule} • ${widget.durationLabel}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0D7C66),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Slot: $_selectedSlot',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── 2. Delivery Slot Selection ──
                const Text(
                  'Delivery Slot ⏰',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                if (_slotsData == null)
                  const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_slotsData!.length, (index) {
                        final slotMap = _slotsData![index];
                        final slotName = slotMap['name']?.toString() ?? slotMap['time_range']?.toString() ?? '';
                        final timeRange = slotMap['time_range']?.toString() ?? '';
                        final available = slotMap['available_capacity'] ?? slotMap['available'] ?? 0;
                        final max = slotMap['max_capacity'] ?? 0;
                        final isFull = slotMap['is_full'] == true;
                        final isCutoff = slotMap['is_cutoff_passed'] == true;
                        
                        final isSelected = _selectedSlot == slotName;
                        final isDisabled = isFull || isCutoff;
                        
                        return GestureDetector(
                          onTap: isDisabled ? null : () => setState(() => _selectedSlot = slotName),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDisabled
                                  ? Colors.grey[200]
                                  : isSelected
                                      ? const Color(0xFFF0FDF4)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected && !isDisabled ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                width: isSelected && !isDisabled ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(_getSlotIcon(slotName, index), style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      slotName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDisabled ? Colors.grey[600] : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeRange,
                                  style: TextStyle(fontSize: 11, color: isDisabled ? Colors.grey[500] : Colors.grey[700]),
                                ),
                                const SizedBox(height: 4),
                                if (isFull)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('FULL', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                                  )
                                else if (isCutoff)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('CLOSED', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  )
                                else
                                  Text('$available/$max slots available', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981))),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 18),

                // ── 3. Delivery Address Selection ──
                const Text(
                  'Delivery Address 📍',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                if (savedAddrs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off_rounded, size: 36, color: Colors.redAccent),
                        const SizedBox(height: 8),
                        const Text(
                          'No Saved Address Found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please add your doorstep delivery address to complete subscription.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => MapLocationPickerScreen(state: widget.state),
                              ),
                            ).then((_) {
                              setState(() {
                                if (widget.state.savedAddresses.isNotEmpty) {
                                  _selectedAddress = widget.state.activeAddress ?? widget.state.savedAddresses.first;
                                }
                              });
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.pin_drop_rounded, size: 16),
                          label: const Text('Pin Address on Map', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      ...savedAddrs.map((addr) {
                        final isSelected = _selectedAddress?.id == addr.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAddress = addr),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(addr.icon, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            addr.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (addr.isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'DEFAULT',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFD97706),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        addr.summaryAddress,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => AddressBookScreen(state: widget.state),
                            ),
                          ).then((_) {
                            setState(() {
                              if (widget.state.savedAddresses.isNotEmpty) {
                                _selectedAddress = widget.state.activeAddress ?? widget.state.savedAddresses.first;
                              }
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF10B981)),
                        label: const Text(
                          '+ Add New Address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),

                // ── 4. Doorstep Notes ──
                const Text(
                  'Delivery Instructions (Optional) 📝',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g., Ring doorbell, leave at gate...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── 5. Payment Summary Card ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.totalDeliveryDays} deliveries × ₹${widget.singleDeliveryCost.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                          Text(
                            '₹${widget.totalCost.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Wallet Balance: ₹${balance.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          if (hasEnoughBalance)
                            const Text(
                              'Sufficient Balance ✅',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            )
                          else
                            Row(
                              children: [
                                Text(
                                  'Recharge ₹${amountNeeded.toStringAsFixed(0)} Required',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                    widget.state.currentTabIndex = 2; // Wallet tab
                                    widget.state.notifyListeners();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red[200]!),
                                    ),
                                    child: const Text(
                                      'Top Up',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_selectedAddress == null || _isSubmitting || !hasEnoughBalance)
                      ? null
                      : _confirmSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Text(
                          !hasEnoughBalance
                              ? '⚠️ Recharge to Continue'
                              : _selectedAddress == null
                                  ? '⚠️ Select Address'
                                  : 'Confirm & Start Subscription 🚀',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
