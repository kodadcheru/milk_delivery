import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../models/storefront_config_model.dart';

class BillBreakdown extends StatelessWidget {
  final double subtotal;
  final StorefrontConfigModel config;
  final double walletDeduction;

  const BillBreakdown({
    super.key,
    required this.subtotal,
    required this.config,
    this.walletDeduction = 0.0,
  });

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor, String? strikethrough, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? UiTone.ink : UiTone.softText,
            ),
          ),
          Row(
            children: [
              if (strikethrough != null) ...[
                Text(
                  strikethrough,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: UiTone.softText,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: valueColor ?? UiTone.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryFee = config.deliveryFee;
    final threshold = config.freeDeliveryThreshold;
    final isFreeDelivery = threshold > 0 && subtotal >= threshold;
    final actualDeliveryFee = isFreeDelivery ? 0.0 : deliveryFee;
    final platformFee = config.platformFee;
    final taxAmount = subtotal * (config.taxPercentage / 100.0);
    final grandTotal = subtotal + actualDeliveryFee + platformFee + taxAmount - walletDeduction;
    final totalSavings = isFreeDelivery ? deliveryFee : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bill Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: UiTone.ink)),
            const SizedBox(height: 12),
            _buildRow('Item Total', '₹${subtotal.toStringAsFixed(0)}'),
            _buildRow(
              'Delivery Fee',
              isFreeDelivery ? 'FREE' : '₹${deliveryFee.toStringAsFixed(0)}',
              valueColor: isFreeDelivery ? UiTone.success : null,
              strikethrough: isFreeDelivery ? '₹${deliveryFee.toStringAsFixed(0)}' : null,
            ),
            _buildRow(
              'Platform Fee',
              platformFee > 0 ? '₹${platformFee.toStringAsFixed(0)}' : 'FREE',
              valueColor: platformFee == 0 ? UiTone.success : null,
            ),
            if (taxAmount > 0)
              _buildRow('GST (${config.taxPercentage}%)', '₹${taxAmount.toStringAsFixed(2)}'),
            if (walletDeduction > 0)
              _buildRow('Wallet Deduction', '-₹${walletDeduction.toStringAsFixed(0)}', valueColor: UiTone.success),
            const Divider(height: 24),
            _buildRow('To Pay', '₹${grandTotal.toStringAsFixed(0)}', isBold: true, fontSize: 16),
            if (totalSavings > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: UiTone.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🎉 You saved ₹${totalSavings.toStringAsFixed(0)} on this order!',
                  style: const TextStyle(color: UiTone.success, fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
