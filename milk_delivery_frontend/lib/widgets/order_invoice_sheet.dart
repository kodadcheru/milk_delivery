import 'package:flutter/material.dart';
import '../models/live_order_model.dart';
import '../models/delivery_task_model.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_text.dart';

class OrderInvoiceSheet extends StatelessWidget {
  final LiveOrderModel? order;
  final DeliveryTaskModel? task;
  final String orderId;
  final String orderDate;
  final String slotTime;
  final String address;
  final double totalAmount;
  final String customerName;
  final String paymentMethod;

  const OrderInvoiceSheet({
    super.key,
    this.order,
    this.task,
    required this.orderId,
    required this.orderDate,
    required this.slotTime,
    required this.address,
    required this.totalAmount,
    this.customerName = 'Valued Customer',
    this.paymentMethod = 'Pamba Pre-paid Wallet',
  });

  static void show(
    BuildContext context, {
    LiveOrderModel? order,
    DeliveryTaskModel? task,
    required String orderId,
    required String orderDate,
    required String slotTime,
    required String address,
    required double totalAmount,
    String customerName = 'Valued Customer',
    String paymentMethod = 'Pamba Pre-paid Wallet',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderInvoiceSheet(
        order: order,
        task: task,
        orderId: orderId,
        orderDate: orderDate,
        slotTime: slotTime,
        address: address,
        totalAmount: totalAmount,
        customerName: customerName,
        paymentMethod: paymentMethod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: UiTone.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: UiTone.surfaceBorder,
              borderRadius: BorderRadius.circular(UiRadius.pill),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Header Branding
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: UiTone.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('🥛', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pamba Fresh', style: UiText.h2.copyWith(fontSize: 18, color: UiTone.primaryDark)),
                          Text('Official Delivery Receipt & Tax Invoice', style: UiText.caption.copyWith(color: UiTone.softText)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: UiTone.successSoft,
                        borderRadius: BorderRadius.circular(UiRadius.xs),
                      ),
                      child: Text('PAID', style: UiText.caption.copyWith(color: UiTone.success, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: UiTone.surfaceBorder),
                const SizedBox(height: 14),

                // Order Meta Grid
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: UiTone.surfaceMuted,
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    border: Border.all(color: UiTone.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      _buildMetaRow('Invoice ID', orderId),
                      const SizedBox(height: 8),
                      _buildMetaRow('Delivery Date', orderDate),
                      const SizedBox(height: 8),
                      _buildMetaRow('Drop Window', slotTime),
                      const SizedBox(height: 8),
                      _buildMetaRow('Payment Mode', paymentMethod),
                      const SizedBox(height: 8),
                      _buildMetaRow('Doorstep Address', address, isAddress: true),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Items Section
                Text('Items Ordered', style: UiText.h2.copyWith(fontSize: 14)),
                const SizedBox(height: 10),

                if (order != null && order!.items.isNotEmpty) ...[
                  ...order!.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: UiTone.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(child: Text('📦', style: TextStyle(fontSize: 16))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: UiText.bodyStrong.copyWith(fontSize: 13)),
                                  Text('${item.quantity}x • ${item.product.unitQuantity}', style: UiText.caption.copyWith(color: UiTone.softText)),
                                ],
                              ),
                            ),
                            Text('₹${(item.unitPrice * item.quantity).toStringAsFixed(0)}', style: UiText.bodyStrong.copyWith(fontSize: 14)),
                          ],
                        ),
                      )),
                ] else ...[
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: UiTone.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('🥛', style: TextStyle(fontSize: 16))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task?.subscriptionDetail?.productDetail?.name ?? 'Fresh A2 Cow Milk', style: UiText.bodyStrong.copyWith(fontSize: 13)),
                            Text('1x Daily Drop • 1 Litre', style: UiText.caption.copyWith(color: UiTone.softText)),
                          ],
                        ),
                      ),
                      Text('₹${totalAmount.toStringAsFixed(0)}', style: UiText.bodyStrong.copyWith(fontSize: 14)),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: UiTone.surfaceBorder),
                const SizedBox(height: 14),

                // Financial Breakdown
                _buildPriceRow('Items Subtotal', '₹${totalAmount.toStringAsFixed(0)}'),
                const SizedBox(height: 6),
                _buildPriceRow('4°C Cold-Chain Handling', 'FREE', isHighlight: true),
                const SizedBox(height: 6),
                _buildPriceRow('Doorstep Drop Packaging', 'FREE', isHighlight: true),
                const SizedBox(height: 6),
                _buildPriceRow('Taxes & GST (Included)', '₹0'),
                const SizedBox(height: 10),
                const Divider(height: 1, color: UiTone.surfaceBorder),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Amount Paid', style: UiText.h2.copyWith(fontSize: 16)),
                    Text('₹${totalAmount.toStringAsFixed(0)}', style: UiText.h2.copyWith(fontSize: 20, color: UiTone.primaryDark)),
                  ],
                ),
                const SizedBox(height: 20),

                // Compliance & FSSAI seal
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(UiRadius.md),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Color(0xFF0D7C66), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'FSSAI Certified: 13621014000342 • 100% Organically Certified Batches.',
                          style: UiText.caption.copyWith(fontSize: 10.5, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Close Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7C66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                  ),
                  child: const Text('Close Invoice', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isAddress = false}) {
    return Row(
      crossAxisAlignment: isAddress ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: UiText.caption.copyWith(color: UiTone.softText, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: isAddress ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: UiText.caption.copyWith(fontWeight: FontWeight.w800, color: UiTone.ink),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: UiText.caption.copyWith(color: UiTone.softText, fontWeight: FontWeight.w600)),
        Text(
          value,
          style: UiText.caption.copyWith(
            fontWeight: FontWeight.w800,
            color: isHighlight ? const Color(0xFF10B981) : UiTone.ink,
          ),
        ),
      ],
    );
  }
}
