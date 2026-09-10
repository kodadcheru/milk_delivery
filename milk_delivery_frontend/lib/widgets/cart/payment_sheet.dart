import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../services/api_service.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class PaymentResult {
  final String paymentMethod; 
  final String? razorpayOrderId;
  PaymentResult({required this.paymentMethod, this.razorpayOrderId});
}

class PaymentSheet extends StatefulWidget {
  final AppState state;
  final double totalAmount;
  final String deliveryMode;
  final String? deliveryDate;
  final String? deliverySlot;

  const PaymentSheet({
    super.key,
    required this.state,
    required this.totalAmount,
    required this.deliveryMode,
    this.deliveryDate,
    this.deliverySlot,
  });

  static Future<PaymentResult?> show(
    BuildContext context, {
    required AppState state,
    required double totalAmount,
    required String deliveryMode,
    String? deliveryDate,
    String? deliverySlot,
  }) {
    return showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTone.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => PaymentSheet(
        state: state,
        totalAmount: totalAmount,
        deliveryMode: deliveryMode,
        deliveryDate: deliveryDate,
        deliverySlot: deliverySlot,
      ),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late String _paymentMethod;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialWallet = widget.state.currentUser?.walletBalance ?? 0.0;
    final isCodAllowed = widget.state.storefrontConfig.isCodEnabled;
    final isWalletAllowed = widget.state.storefrontConfig.isWalletEnabled;
    final isOnlineAllowed = widget.state.storefrontConfig.isOnlinePaymentEnabled;
    
    _paymentMethod = (isWalletAllowed && initialWallet >= widget.totalAmount && initialWallet > 0)
        ? 'WALLET'
        : (isOnlineAllowed ? 'RAZORPAY' : (isCodAllowed ? 'COD' : (isWalletAllowed ? 'WALLET' : 'COD')));
  }

  void _showQuickTopUpDialog(BuildContext context, AppState state, double deficit, VoidCallback onRecharged) {
    final amounts = [deficit < 100 ? 100.0 : deficit, 200.0, 500.0, 1000.0];
    final selectedAmt = ValueNotifier<double>(amounts.first);
    final isProcessing = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D7C66), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isTelugu ? 'వాలెట్ తక్షణ రీఛార్జ్' : 'Quick Wallet Recharge',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        state.isTelugu ? 'ఆర్డర్ పూర్తి చేయడానికి నిల్వను జోడించండి' : 'Add funds to complete your order seamlessly',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              state.isTelugu ? 'మొత్తం ఎంచుకోండి:' : 'Select Amount:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<double>(
              valueListenable: selectedAmt,
              builder: (context, current, _) {
                return Row(
                  children: amounts.map((amt) {
                    final isSel = current == amt;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            selectedAmt.value = amt;
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF0D7C66) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? const Color(0xFF0D7C66) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '₹${amt.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSel ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: isProcessing,
              builder: (context, loading, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            isProcessing.value = true;
                            // Need to make sure topUpWallet exists on AppState
                            await state.topUpWallet(selectedAmt.value, 'Instant Checkout Recharge', context: context);
                            isProcessing.value = false;
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            onRecharged();
                          },
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            state.isTelugu ? 'తక్షణమే జోడించండి ⚡' : 'Recharge & Use Wallet ⚡',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handlePay() async {
    if (_isSubmitting) return;

    final state = widget.state;
    final total = widget.totalAmount;
    final walletBalance = state.currentUser?.walletBalance ?? 0.0;
    
    if (_paymentMethod == 'WALLET' && walletBalance < total) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.isTelugu
            ? 'వాలెట్ బ్యాలెన్స్ తక్కువగా ఉంది (₹${walletBalance.toStringAsFixed(0)}). దయచేసి టాప్ అప్ చేయండి.'
            : 'Insufficient wallet balance (₹${walletBalance.toStringAsFixed(0)}). Please top up your wallet.'),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    if (_paymentMethod == 'RAZORPAY') {
      setState(() => _isSubmitting = true);
      try {
        final orderResult = await ApiService.createRazorpayOrder(
          total,
          purpose: 'ORDER_PAYMENT',
        );
        if (orderResult['success'] != true) {
          throw Exception(orderResult['error'] ?? 'Failed to initiate Razorpay online payment');
        }

        final rzpOrderId = orderResult['razorpay_order_id'] ?? '';
        final keyId = orderResult['key_id'] ?? '';
        final amountPaise = orderResult['amount_paise'] ?? (total * 100).toInt();

        final razorpay = Razorpay();

        razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) async {
          try {
            final verifyResult = await ApiService.verifyRazorpayPayment(
              response.orderId ?? rzpOrderId,
              response.paymentId ?? '',
              response.signature ?? '',
            );
            if (verifyResult['success'] != true) {
              throw Exception(verifyResult['detail'] ?? 'Razorpay signature verification failed');
            }

            if (mounted) {
              Navigator.pop(context, PaymentResult(paymentMethod: 'RAZORPAY', razorpayOrderId: response.orderId ?? rzpOrderId));
            }
          } catch (e) {
            if (mounted) {
              final errorMsg = e.toString().replaceFirst('Exception: ', '');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('❌ $errorMsg')));
            }
          } finally {
            razorpay.clear();
            if (mounted) setState(() => _isSubmitting = false);
          }
        });

        razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
          razorpay.clear();
          if (mounted) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text(state.isTelugu
                  ? 'చెల్లింపు రద్దు చేయబడింది లేదా విఫలమైంది: ${response.message ?? ''}'
                  : 'Payment cancelled or failed: ${response.message ?? 'User dismissed'}'),
            ));
          }
        });

        razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
          razorpay.clear();
          if (mounted) setState(() => _isSubmitting = false);
        });

        final options = <String, dynamic>{
          'key': keyId.isNotEmpty ? keyId : 'rzp_test_TZqYcaKAOxoDP7',
          'amount': amountPaise,
          'name': 'Pamba Fresh',
          'description': 'Express Order (₹${total.toStringAsFixed(0)})',
          'prefill': {
            'contact': state.currentUser?.phone ?? '',
            'email': state.currentUser?.email ?? '',
          },
          'theme': {'color': '#0D7C66'},
        };
        if (rzpOrderId.isNotEmpty && !rzpOrderId.startsWith('order_test_')) {
          options['order_id'] = rzpOrderId;
        }

        razorpay.open(options);
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          final errorMsg = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFFDC2626), content: Text('❌ $errorMsg')));
        }
      }
      return;
    }

    Navigator.pop(context, PaymentResult(paymentMethod: _paymentMethod));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final total = widget.totalAmount;
    
    final isWalletEnabled = state.storefrontConfig.isWalletEnabled;
    final walletBal = state.currentUser?.walletBalance ?? 0.0;
    final isWalletSelected = _paymentMethod == 'WALLET' && isWalletEnabled;
    final hasSufficientBal = walletBal >= total;
    final deficit = total - walletBal;

    final isCodEnabled = state.storefrontConfig.isCodEnabled;
    final isCodSelected = _paymentMethod == 'COD' && isCodEnabled;

    final isOnlineEnabled = state.storefrontConfig.isOnlinePaymentEnabled;
    final isOnlineSelected = _paymentMethod == 'RAZORPAY' && isOnlineEnabled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('💳', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    state.isTelugu ? 'చెల్లింపు విధానం' : 'Select Payment Method',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: UiTone.ink),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 16),
          
          // Wallet
          Opacity(
            opacity: isWalletEnabled ? 1.0 : 0.45,
            child: InkWell(
              onTap: isWalletEnabled ? () {
                HapticFeedback.selectionClick();
                setState(() => _paymentMethod = 'WALLET');
              } : null,
              borderRadius: BorderRadius.circular(UiRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !isWalletEnabled
                      ? const Color(0xFFF1F5F9)
                      : (isWalletSelected ? const Color(0xFFE6F5F0) : UiTone.surfaceMuted),
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(
                    color: !isWalletEnabled
                        ? const Color(0xFFCBD5E1)
                        : (isWalletSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder),
                    width: isWalletSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: !isWalletEnabled
                            ? Colors.grey.shade400
                            : (isWalletSelected ? const Color(0xFF0D7C66) : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isTelugu ? 'పాంబ వాలెట్' : 'Pamba Wallet',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: !isWalletEnabled
                                  ? Colors.grey.shade500
                                  : (isWalletSelected ? const Color(0xFF0D7C66) : UiTone.ink),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bal: ₹${walletBal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasSufficientBal ? const Color(0xFF059669) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isWalletEnabled && !hasSufficientBal) ...[
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showQuickTopUpDialog(context, state, deficit, () => setState(() {}));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D7C66),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Top Up',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ] else if (isWalletEnabled) ...[
                      Icon(
                        isWalletSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isWalletSelected ? const Color(0xFF0D7C66) : Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          // COD
          Opacity(
            opacity: isCodEnabled ? 1.0 : 0.45,
            child: InkWell(
              onTap: isCodEnabled ? () {
                HapticFeedback.selectionClick();
                setState(() => _paymentMethod = 'COD');
              } : null,
              borderRadius: BorderRadius.circular(UiRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !isCodEnabled
                      ? const Color(0xFFF1F5F9)
                      : (isCodSelected ? const Color(0xFFE6F5F0) : UiTone.surfaceMuted),
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(
                    color: !isCodEnabled
                        ? const Color(0xFFCBD5E1)
                        : (isCodSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder),
                    width: isCodSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: !isCodEnabled
                            ? Colors.grey.shade400
                            : (isCodSelected ? const Color(0xFF0D7C66) : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.isTelugu ? 'క్యాష్ / UPI ఆన్ డెలివరీ' : 'Cash / UPI on Delivery',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: !isCodEnabled
                              ? Colors.grey.shade500
                              : (isCodSelected ? const Color(0xFF0D7C66) : UiTone.ink),
                        ),
                      ),
                    ),
                    if (isCodEnabled)
                      Icon(
                        isCodSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isCodSelected ? const Color(0xFF0D7C66) : Colors.grey.shade400,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          // Razorpay
          Opacity(
            opacity: isOnlineEnabled ? 1.0 : 0.45,
            child: InkWell(
              onTap: isOnlineEnabled ? () {
                HapticFeedback.selectionClick();
                setState(() => _paymentMethod = 'RAZORPAY');
              } : null,
              borderRadius: BorderRadius.circular(UiRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: !isOnlineEnabled
                      ? const Color(0xFFF1F5F9)
                      : (isOnlineSelected ? const Color(0xFFE6F5F0) : UiTone.surfaceMuted),
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(
                    color: !isOnlineEnabled
                        ? const Color(0xFFCBD5E1)
                        : (isOnlineSelected ? const Color(0xFF0D7C66) : UiTone.surfaceBorder),
                    width: isOnlineSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: !isOnlineEnabled
                            ? Colors.grey.shade400
                            : (isOnlineSelected ? const Color(0xFF0D7C66) : const Color(0xFF0284C7)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.isTelugu ? 'ఆన్‌లైన్ చెల్లింపు (UPI / కార్డ్స్)' : 'Online Pay (UPI / Cards)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: !isOnlineEnabled
                              ? Colors.grey.shade500
                              : (isOnlineSelected ? const Color(0xFF0D7C66) : UiTone.ink),
                        ),
                      ),
                    ),
                    if (isOnlineEnabled)
                      Icon(
                        isOnlineSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isOnlineSelected ? const Color(0xFF0D7C66) : Colors.grey.shade400,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Pay Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handlePay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Pay ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
