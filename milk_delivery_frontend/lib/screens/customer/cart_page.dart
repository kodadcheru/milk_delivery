import 'package:flutter/material.dart';

import '../../widgets/cart/cart_item_card.dart';
import '../../widgets/cart/free_delivery_bar.dart';
import '../../widgets/cart/cross_sell_carousel.dart';
import '../../widgets/cart/delivery_instructions.dart';
import '../../widgets/cart/bill_breakdown.dart';
import '../../widgets/cart/cart_empty_state.dart';
import '../../widgets/cart/order_success_sheet.dart';
import '../../widgets/cart/payment_sheet.dart';

import '../../providers/app_state.dart';
import '../../models/storefront_config_model.dart';
import '../../models/product_model.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/home/home_location_sheet.dart';
import '../../services/api_service.dart';
import '../../widgets/booking_detail_sheet.dart';

class CartPage extends StatefulWidget {
  final AppState state;
  const CartPage({super.key, required this.state});
  
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String _deliveryMode = 'SCHEDULED';
  String _selectedSlot = '06:00 AM - 08:00 AM';
  List<String> _deliveryInstructions = [];
  List<ProductModel> _crossSellProducts = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCrossSell();
  }

  Future<void> _loadCrossSell() async {
    final cartIds = widget.state.cartProductsList.map((e) => e.key.id).toList();
    final suggestions = widget.state.products
        .where((p) => !cartIds.contains(p.id) && p.isAvailable)
        .take(8)
        .toList();
    if (mounted) setState(() => _crossSellProducts = suggestions);
  }

  Future<void> _proceedToPayment() async {
    final addr = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;
    if (addr == 'Select Delivery Location' || addr.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid delivery location')),
      );
      return;
    }
    
    final grandTotal = widget.state.totalCartPrice; // simplified, exact depends on config

    final result = await PaymentSheet.show(
      context,
      state: widget.state,
      totalAmount: grandTotal,
      deliveryMode: _deliveryMode,
      deliveryDate: _deliveryMode == 'SCHEDULED' ? 'Tomorrow' : null,
      deliverySlot: _deliveryMode == 'SCHEDULED' ? _selectedSlot : null,
    );
    
    if (result != null) {
      setState(() => _isSubmitting = true);
      try {
        final order = await widget.state.placeExpressOrder(
          deliveryDate: _deliveryMode == 'SCHEDULED' ? 'Tomorrow' : null,
          deliverySlot: _deliveryMode == 'SCHEDULED' ? _selectedSlot : null,
          deliveryAddress: addr,
          deliveryType: _deliveryMode == 'INSTANT' ? 'INSTANT' : 'SCHEDULED',
          paymentMethod: result.paymentMethod,
          razorpayOrderId: result.razorpayOrderId,
        );
        
        if (mounted) {
          await OrderSuccessSheet.show(context, orderId: order.id.toString());
          widget.state.setTab(3);
          if (mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, child) {
        final subtotal = widget.state.totalCartPrice;
        final config = widget.state.storefrontConfig;

        return Scaffold(
          backgroundColor: UiTone.shellBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: UiTone.ink),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Cart (${widget.state.totalCartItemCount} items)',
                  style: const TextStyle(
                    color: UiTone.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _deliveryMode == 'SCHEDULED' ? 'Arriving Tomorrow' : 'Arriving in 25 mins',
                  style: const TextStyle(
                    color: UiTone.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          body: widget.state.totalCartItemCount == 0
              ? CartEmptyState(onBrowse: () => Navigator.pop(context))
              : Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                FreeDeliveryBar(
                                  cartTotal: subtotal,
                                  threshold: config.freeDeliveryThreshold,
                                ),
                                _buildAddressStrip(),
                                _buildDeliveryModeSelector(),
                                if (_deliveryMode == 'SCHEDULED') _buildSlotSelector(),
                                _buildCartItems(),
                                CrossSellCarousel(
                                  products: _crossSellProducts,
                                  state: widget.state,
                                ),
                                DeliveryInstructions(
                                  onChanged: (instructions) {
                                    setState(() => _deliveryInstructions = instructions);
                                  },
                                ),
                                BillBreakdown(
                                  subtotal: subtotal,
                                  config: config,
                                ),
                                _buildPolicyNote(),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildStickyBottomBar(subtotal, config),
                    ),
                    if (_isSubmitting)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAddressStrip() {
    final addr = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: UiTone.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery to',
                  style: TextStyle(
                    fontSize: 11,
                    color: UiTone.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  addr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => HomeLocationSheet.show(context, widget.state),
            style: TextButton.styleFrom(
              foregroundColor: UiTone.primary,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryModeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _ModeCard(
              title: '⚡ Instant Express',
              subtitle: '~25 mins',
              isSelected: _deliveryMode == 'INSTANT',
              onTap: () => setState(() => _deliveryMode = 'INSTANT'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ModeCard(
              title: '🌅 Next-Day Drop',
              subtitle: 'Tomorrow 06:00 AM',
              isSelected: _deliveryMode == 'SCHEDULED',
              onTap: () => setState(() => _deliveryMode = 'SCHEDULED'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSelector() {
    final slots = [
      '06:00 AM - 08:00 AM',
      '08:00 AM - 10:00 AM',
      '06:00 PM - 08:00 PM',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Delivery Slot',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isSelected = _selectedSlot == slot;
              return ChoiceChip(
                label: Text(slot),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedSlot = slot);
                },
                selectedColor: UiTone.primary.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? UiTone.primary : UiTone.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UiRadius.sm),
                  side: BorderSide(
                    color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: widget.state.cartProductsList.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CartItemCard(
              item: entry.key,
              quantity: entry.value,
              state: widget.state,
              onRemoved: () {
                widget.state.removeFromCart(entry.key);
                _loadCrossSell();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPolicyNote() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Orders cannot be cancelled once placed. Items are non-refundable unless damaged.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: UiTone.textMuted,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(double subtotal, StorefrontConfigModel config) {
    double total = subtotal;
    if (subtotal < config.freeDeliveryThreshold) {
      total += config.deliveryFee;
    }
    total += config.platformFee;
    final taxAmount = (subtotal * config.taxPercentage) / 100;
    total += taxAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        color: UiTone.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: UiTone.ink,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _proceedToPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTone.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UiRadius.md),
                    ),
                  ),
                  child: Text(
                    'Proceed to Pay ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(UiRadius.md),
          border: BorderSide(
            color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? UiTone.primary : UiTone.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? UiTone.primary : UiTone.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
