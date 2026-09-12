import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

class OrderSuccessSheet extends StatefulWidget {
  final String orderId;
  final String? deliveryEta;
  final bool isTelugu;

  const OrderSuccessSheet({
    super.key,
    required this.orderId,
    this.deliveryEta,
    this.isTelugu = false,
  });

  static Future<void> show(BuildContext context, {required String orderId, String? deliveryEta, bool isTelugu = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: OrderSuccessSheet(orderId: orderId, deliveryEta: deliveryEta, isTelugu: isTelugu),
      ),
    );
  }

  @override
  State<OrderSuccessSheet> createState() => _OrderSuccessSheetState();
}

class _OrderSuccessSheetState extends State<OrderSuccessSheet> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: UiTone.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            widget.isTelugu ? 'ఆర్డర్ విజయవంతంగా నమోదయింది! 🎉' : 'Order Placed! 🎉',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: UiTone.ink),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isTelugu ? 'ఆర్డర్ సంఖ్య #${widget.orderId}' : 'Order #${widget.orderId}',
            style: const TextStyle(fontSize: 14, color: UiTone.softText),
          ),
          if (widget.deliveryEta != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.isTelugu ? 'చేరుకునే సమయం: ${widget.deliveryEta}' : 'Arriving ${widget.deliveryEta}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UiTone.ink),
            ),
          ],
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTone.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                widget.isTelugu ? 'ఆర్డర్ ట్రాక్ చేయండి' : 'Track Order',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.isTelugu ? 'షాపింగ్ కొనసాగించండి' : 'Continue Shopping',
              style: const TextStyle(color: UiTone.softText, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
