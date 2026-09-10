import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class CartPage extends StatefulWidget {
  final AppState state;
  const CartPage({super.key, required this.state});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final ScrollController _scrollController = ScrollController();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCrossSell() async {
    final cartIds = widget.state.cartProductsList.map((e) => e.key.id).toList();
    final suggestions = widget.state.products
        .where((p) => !cartIds.contains(p.id) && p.isAvailable)
        .take(8)
        .toList();
    if (mounted) setState(() => _crossSellProducts = suggestions);
  }

  double _calculateGrandTotal(double subtotal, StorefrontConfigModel config) {
    double total = subtotal;
    if (config.freeDeliveryThreshold <= 0 || subtotal < config.freeDeliveryThreshold) {
      total += config.deliveryFee;
    }
    total += config.platformFee;
    final taxAmount = (subtotal * config.taxPercentage) / 100.0;
    total += taxAmount;
    return total;
  }

  Future<void> _proceedToPayment() async {
    final addr = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;
    if (addr == 'Select Delivery Location' || addr.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid delivery location')),
      );
      return;
    }

    final config = widget.state.storefrontConfig;
    final grandTotal = _calculateGrandTotal(widget.state.totalCartPrice, config);

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

  void _scrollToBill() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, child) {
        final subtotal = widget.state.totalCartPrice;
        final config = widget.state.storefrontConfig;
        final grandTotal = _calculateGrandTotal(subtotal, config);

        return Scaffold(
          backgroundColor: UiTone.shellBackground,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: UiTone.ink, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Cart (${widget.state.totalCartItemCount} items)',
                  style: const TextStyle(
                    color: UiTone.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _deliveryMode == 'SCHEDULED' ? 'Arriving Tomorrow by 06:00 AM' : 'Arriving in ~25 mins',
                  style: const TextStyle(
                    color: UiTone.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: UiTone.surfaceBorder, height: 1),
            ),
          ),
          body: widget.state.totalCartItemCount == 0
              ? CartEmptyState(onBrowse: () => Navigator.pop(context))
              : Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FreeDeliveryBar(
                            cartTotal: subtotal,
                            threshold: config.freeDeliveryThreshold,
                          ),
                          _buildAddressStrip(),
                          _buildDeliveryModeSelector(),
                          if (_deliveryMode == 'SCHEDULED') _buildSlotSelector(),
                          _buildCartItems(subtotal),
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
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildStickyBottomBar(grandTotal),
                    ),
                    if (_isSubmitting)
                      Container(
                        color: Colors.black.withOpacity(0.35),
                        child: const Center(
                          child: CircularProgressIndicator(color: UiTone.primary),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
        boxShadow: UiShadow.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: UiTone.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: UiTone.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivering to',
                  style: TextStyle(
                    fontSize: 11,
                    color: UiTone.softText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  addr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: UiTone.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              HomeLocationSheet.show(context, widget.state);
            },
            borderRadius: BorderRadius.circular(UiRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: UiTone.primarySoft,
                borderRadius: BorderRadius.circular(UiRadius.pill),
                border: Border.all(color: UiTone.primary.withValues(alpha: 0.3), width: 0.8),
              ),
              child: const Text(
                'Change',
                style: TextStyle(
                  color: UiTone.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
              subtitle: '~25 mins delivery',
              isSelected: _deliveryMode == 'INSTANT',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _deliveryMode = 'INSTANT');
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeCard(
              title: '🌅 Morning Drop',
              subtitle: 'Tomorrow by 06:00 AM',
              isSelected: _deliveryMode == 'SCHEDULED',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _deliveryMode = 'SCHEDULED');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSelector() {
    final slots = [
      {'label': '06:00 AM - 08:00 AM', 'icon': '🌅'},
      {'label': '08:00 AM - 10:00 AM', 'icon': '☀️'},
      {'label': '06:00 PM - 08:00 PM', 'icon': '🌇'},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: UiTone.primary),
              SizedBox(width: 6),
              Text(
                'Select Delivery Slot',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: UiTone.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((item) {
              final slot = item['label']!;
              final icon = item['icon']!;
              final isSelected = _selectedSlot == slot;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSlot = slot);
                },
                borderRadius: BorderRadius.circular(UiRadius.pill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? UiTone.primarySoft : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(UiRadius.pill),
                    border: Border.all(
                      color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        slot,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? UiTone.primaryDark : UiTone.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(double subtotal) {
    final items = widget.state.cartProductsList;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: UiTone.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Items in Cart (${widget.state.totalCartItemCount})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: UiTone.ink,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: UiTone.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: UiTone.surfaceBorder),

          // Items list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: UiTone.surfaceBorder),
            itemBuilder: (context, index) {
              final entry = items[index];
              return CartItemCard(
                product: entry.key,
                quantity: entry.value,
                state: widget.state,
                onRemoved: () {
                  widget.state.removeFromCart(entry.key);
                  _loadCrossSell();
                },
              );
            },
          ),

          // Bottom "+ Add more items" CTA button
          const Divider(height: 1, color: UiTone.surfaceBorder),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(UiRadius.md)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: UiTone.primary),
                  SizedBox(width: 6),
                  Text(
                    'Add more items',
                    style: TextStyle(
                      color: UiTone.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: UiTone.softText),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Orders cannot be cancelled once packed. Farm-fresh items are non-refundable unless damaged upon arrival.',
              style: TextStyle(
                color: UiTone.softText,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(double grandTotal) {
    final addr = widget.state.activeAddress?.summaryAddress ?? widget.state.currentDeliveryAddress;
    final shortAddr = addr.length > 28 ? '${addr.substring(0, 26)}...' : addr;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -3),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top delivery preview pill
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                HomeLocationSheet.show(context, widget.state);
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: UiTone.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Delivering to: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: UiTone.softText.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        shortAddr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: UiTone.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_right_rounded, size: 14, color: UiTone.softText),
                  ],
                ),
              ),
            ),

            // Main High-Contrast Checkout Bar
            InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _proceedToPayment();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [UiTone.primary, Color(0xFF0F9B7E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: UiTone.primary.withValues(alpha: 0.35),
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Amount & View Bill
                    GestureDetector(
                      onTap: _scrollToBill,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Row(
                            children: const [
                              Text(
                                'TOTAL • VIEW BILL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: Colors.white70),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Right: Proceed to Pay CTA
                    Row(
                      children: const [
                        Text(
                          'Proceed to Pay',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                      ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? UiTone.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(UiRadius.md),
          border: Border.all(
            color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
            width: isSelected ? 1.6 : 0.8,
          ),
          boxShadow: isSelected ? null : UiShadow.card,
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
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: isSelected ? UiTone.primaryDark : UiTone.ink,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 14, color: UiTone.primary)
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: UiTone.surfaceBorder, width: 1.2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? UiTone.primaryDark : UiTone.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
