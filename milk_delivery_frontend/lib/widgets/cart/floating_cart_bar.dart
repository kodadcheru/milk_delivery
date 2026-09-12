import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/ui_tokens.dart';
import '../../providers/app_state.dart';

class FloatingCartBar extends StatefulWidget {
  final AppState state;
  final VoidCallback onViewCart;

  const FloatingCartBar({
    super.key,
    required this.state,
    required this.onViewCart,
  });

  @override
  State<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends State<FloatingCartBar> {
  double _priceScale = 1.0;

  @override
  void didUpdateWidget(covariant FloatingCartBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.totalCartPrice != widget.state.totalCartPrice) {
      _pulsePrice();
    }
  }

  void _pulsePrice() async {
    setState(() => _priceScale = 1.08);
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) setState(() => _priceScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.state.totalCartItemCount;
    if (count == 0) return const SizedBox.shrink();

    final total = widget.state.totalCartPrice;
    final threshold = widget.state.storefrontConfig.freeDeliveryThreshold;
    
    // Attempt to get products from cart. Assuming state has a way to get cart products.
    // If state.cartProductsList is available (from old code), or we filter state.products.
    final cartProducts = widget.state.products.where((p) => widget.state.cartQtyOf(p) > 0).toList();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: UiTone.primary.withValues(alpha: 0.3),
      child: InkWell(
        onTap: widget.onViewCart,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [UiTone.ink, Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: UiTone.secondary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Left: Stack of up to 3 overlapping circular product thumbnails
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    children: cartProducts.take(3).toList().asMap().entries.map((entry) {
                      final p = entry.value;
                      return Align(
                        widthFactor: 0.6,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: UiTone.surface,
                          child: p.imageUrl.isNotEmpty
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: p.imageUrl,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Text(p.icon, style: const TextStyle(fontSize: 18)),
                                  ),
                                )
                              : Text(p.icon, style: const TextStyle(fontSize: 18)),
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(count),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: UiTone.secondary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Center: Text details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: _priceScale,
                      duration: const Duration(milliseconds: 150),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '$count ${widget.state.isTelugu ? "వస్తువులు" : "Items"} · ₹${total.toStringAsFixed(0)}',
                          key: ValueKey('$count-$total'),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (threshold > 0 && total < threshold)
                      Text(
                        widget.state.isTelugu
                            ? 'ఉచిత డెలివరీ కోసం ఇంకో ₹${(threshold - total).toStringAsFixed(0)} జోడించండి'
                            : 'Add ₹${(threshold - total).toStringAsFixed(0)} more for FREE delivery',
                        style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                      )
                    else if (threshold > 0 && total >= threshold)
                      Text(
                        widget.state.isTelugu ? 'ఉచిత డెలివరీ లభించింది 🎉' : 'FREE Delivery Unlocked 🎉',
                        style: const TextStyle(color: UiTone.success, fontSize: 11, fontWeight: FontWeight.w600),
                      )
                    else if (widget.state.storefrontConfig.deliveryFee > 0)
                      Text(
                        widget.state.isTelugu
                            ? 'డెలివరీ ఛార్జీ: ₹${widget.state.storefrontConfig.deliveryFee.toStringAsFixed(0)}'
                            : 'Delivery Fee: ₹${widget.state.storefrontConfig.deliveryFee.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      )
                    else
                      Text(
                        widget.state.isTelugu ? 'ఉచిత డెలివరీ ✓' : 'FREE Delivery ✓',
                        style: const TextStyle(color: UiTone.success, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),

              // Right: View Cart Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: UiTone.primary,
                  borderRadius: BorderRadius.circular(16), // Pill shape
                ),
                child: Text(
                  widget.state.isTelugu ? 'కార్ట్ చూడండి >' : 'View Cart >',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
