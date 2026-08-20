import 'package:flutter/material.dart';
import '../../models/customer_address_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_state.dart';
import 'address_book_screen.dart';
import 'map_location_picker_screen.dart';

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

  @override
  void initState() {
    super.initState();
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

    setState(() => _isSubmitting = true);

    widget.state.selectActiveAddress(_selectedAddress!);

    await widget.state.createNewSubscription(
      widget.product,
      widget.quantity,
      widget.schedule,
      deliveryAddress: _selectedAddress!.summaryAddress,
      deliverySlot: widget.timeSlot,
      deliveryLatitude: _selectedAddress!.latitude,
      deliveryLongitude: _selectedAddress!.longitude,
      deliveryInstructions: widget.deliveryInstructions,
      packSize: widget.packSize,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pop(context); // Close Address Selection Screen

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D7C66),
        duration: const Duration(seconds: 4),
        content: Text(
          '🎉 Subscription Confirmed!\nDelivering to "${_selectedAddress!.title}" (${widget.timeSlot}).',
        ),
      ),
    );
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
              'Select Delivery Address 📍',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              'Step 2 of 2 • Address & Confirmation',
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
            // ── 1. Plan Summary Header Card ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                          '${widget.quantity}x ${widget.packSize} • ${widget.schedule} • ${widget.durationLabel} (${widget.totalDeliveryDays} Deliveries)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D7C66),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Slot: ${widget.timeSlot}',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL COST',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '₹${widget.totalCost.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D7C66),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 2. Mandatory Address Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text(
                      'DELIVERY ADDRESS ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '*MANDATORY',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
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
                  icon: const Icon(Icons.add_location_alt_rounded, size: 14, color: Color(0xFF10B981)),
                  label: const Text(
                    '+ Add New',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── 3. Saved Address Cards List ──
            if (savedAddrs.isEmpty) ...[
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
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: savedAddrs.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (c, i) {
                  final addr = savedAddrs[i];
                  final isSelected = _selectedAddress?.id == addr.id;

                  return InkWell(
                    onTap: () => setState(() => _selectedAddress = addr),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: addr.id,
                            groupValue: _selectedAddress?.id,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) => setState(() => _selectedAddress = addr),
                          ),
                          const SizedBox(width: 4),
                          Text(addr.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
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
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'DEFAULT',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  addr.summaryAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
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
                },
              ),
            ],
            const SizedBox(height: 20),

            // ── Quick Map Pin Button ──
            OutlinedButton.icon(
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: Color(0xFF10B981)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.map_rounded, color: Color(0xFF10B981), size: 18),
              label: const Text(
                'Pin Doorstep on Google Map 🗺️',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
              ),
            ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedAddress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Delivering to: ${_selectedAddress!.title} (${_selectedAddress!.summaryAddress})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_selectedAddress == null || _isSubmitting)
                      ? null
                      : _confirmSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _selectedAddress == null
                              ? '⚠️ Select Address Above to Confirm'
                              : 'Confirm Subscription & Pay (₹${widget.totalCost.toStringAsFixed(0)}) 🚀',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
}
}
