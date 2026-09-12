import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../models/storefront_config_model.dart';

class BillBreakdown extends StatelessWidget {
  final double subtotal;
  final StorefrontConfigModel config;
  final double walletDeduction;
  final bool isTelugu;

  const BillBreakdown({
    super.key,
    required this.subtotal,
    required this.config,
    this.walletDeduction = 0.0,
    this.isTelugu = false,
  });

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    String? strikethrough,
    double fontSize = 12.5,
    Widget? trailingSubtext,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold ? UiTone.ink : UiTone.softText,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (strikethrough != null) ...[
                Text(
                  strikethrough,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: UiTone.softText.withValues(alpha: 0.7),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                  color: valueColor ?? (isBold ? UiTone.ink : UiTone.ink),
                ),
              ),
              if (trailingSubtext != null) ...[
                const SizedBox(width: 4),
                trailingSubtext,
              ],
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
    final freeLabel = isTelugu ? 'ఉచితం' : 'FREE';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(color: UiTone.surfaceBorder, width: 0.8),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: UiTone.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: UiTone.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isTelugu ? 'బిల్లు వివరాలు' : 'Bill Summary',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: UiTone.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: UiTone.surfaceBorder),
          const SizedBox(height: 8),
          _buildRow(isTelugu ? 'వస్తువుల మొత్తం' : 'Item Total', '₹${subtotal.toStringAsFixed(0)}'),
          _buildRow(
            isTelugu ? 'డెలివరీ ఛార్జీ' : 'Delivery Fee',
            isFreeDelivery ? freeLabel : (deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(0)}' : freeLabel),
            valueColor: isFreeDelivery || deliveryFee == 0 ? UiTone.success : null,
            strikethrough: isFreeDelivery && deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(0)}' : null,
          ),
          _buildRow(
            isTelugu ? 'ప్లాట్‌ఫామ్ ఫీజు' : 'Platform Fee',
            platformFee > 0 ? '₹${platformFee.toStringAsFixed(0)}' : freeLabel,
            valueColor: platformFee == 0 ? UiTone.success : null,
          ),
          if (taxAmount > 0)
            _buildRow(
              isTelugu ? 'జీఎస్టీ & పన్నులు (${config.taxPercentage}%)' : 'Taxes & Charges (${config.taxPercentage}%)',
              '₹${taxAmount.toStringAsFixed(1)}',
            ),
          if (walletDeduction > 0)
            _buildRow(isTelugu ? 'వాలెట్ తగ్గింపు' : 'Wallet Applied', '-₹${walletDeduction.toStringAsFixed(0)}', valueColor: UiTone.success),
          const SizedBox(height: 6),
          const Divider(height: 1, color: UiTone.surfaceBorder),
          const SizedBox(height: 6),
          _buildRow(
            isTelugu ? 'చెల్లించాల్సిన మొత్తం' : 'Grand Total',
            '₹${grandTotal.toStringAsFixed(0)}',
            isBold: true,
            fontSize: 15.5,
          ),
          if (totalSavings > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    isTelugu
                        ? 'ఈ ఆర్డర్‌పై మీరు ₹${totalSavings.toStringAsFixed(0)} ఆదా చేశారు!'
                        : 'You saved ₹${totalSavings.toStringAsFixed(0)} on this order!',
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
