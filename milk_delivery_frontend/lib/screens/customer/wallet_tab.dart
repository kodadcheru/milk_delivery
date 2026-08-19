import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/app_state.dart';
import '../../models/wallet_transaction_model.dart';
import '../../widgets/scratch_card_modal.dart';

class WalletTab extends StatefulWidget {
  final AppState state;

  const WalletTab({super.key, required this.state});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  String _selectedFilter = 'ALL'; // ALL, CREDIT, DEBIT

  @override
  Widget build(BuildContext context) {
    final bal = widget.state.currentUser?.walletBalance ?? 500.00;
    final allTxs = widget.state.transactions;
    int estDays = (bal / 72.0).floor();

    final filteredTxs = allTxs.where((t) {
      if (_selectedFilter == 'CREDIT') return t.transactionType == 'CREDIT';
      if (_selectedFilter == 'DEBIT') return t.transactionType == 'DEBIT';
      return true;
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFF0D7C66),
      onRefresh: () => widget.state.reloadAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ── Virtual Metallic Wallet Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D7C66)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7C66).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.credit_card_rounded, color: Colors.brown, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'MILKDROP EXPRESS WALLET',
                          style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 12),
                          SizedBox(width: 2),
                          Text('Auto-Debit 🟢', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Available Balance',
                  style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${bal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  estDays > 0
                      ? '✨ Sufficient for approx. ~$estDays days of morning deliveries'
                      : '⚠️ Low balance! Top up for uninterrupted morning deliveries.',
                  style: TextStyle(color: estDays > 0 ? Colors.white70 : Colors.amber, fontSize: 11),
                ),
                const SizedBox(height: 18),

                // Quick Top-Up Preset Chips
                Row(
                  children: [300.0, 500.0, 1000.0].map((amt) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          onPressed: () => _handleInstantRecharge(amt, 'UPI Express'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('+ ₹${amt.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Custom Amount Recharge Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCustomRechargeModal(context),
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                    label: const Text('Custom Recharge & UPI Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D7C66),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Transaction Ledger Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wallet Ledger & Invoices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                '${filteredTxs.length} items',
                style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Ledger Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Transactions'),
                const SizedBox(width: 8),
                _buildFilterChip('CREDIT', '➕ Recharges & Credits'),
                const SizedBox(width: 8),
                _buildFilterChip('DEBIT', '➖ Delivery Debits'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filteredTxs.isEmpty)
            Card(
              child: const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Text('💳', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 10),
                      Text('No Transactions Recorded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('All recharges and delivery auto-debits will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTxs.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final tx = filteredTxs[idx];
                final isCredit = tx.transactionType == 'CREDIT';

                return Card(
                  child: InkWell(
                    onTap: () => _showReceiptModal(context, tx),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCredit
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : const Color(0xFFE11D48).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isCredit ? const Color(0xFF0D7C66) : const Color(0xFFE11D48),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tx.createdAt,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isCredit ? "+" : "-"} ₹${tx.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isCredit ? const Color(0xFF0D7C66) : const Color(0xFFE11D48),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCredit ? 'CREDITED' : 'AUTO-DEBIT',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? const Color(0xFF10B981) : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0D7C66),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      side: BorderSide(color: isSelected ? const Color(0xFF0D7C66) : Colors.transparent),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filterKey);
      },
    );
  }

  void _handleInstantRecharge(double amt, String method) {
    widget.state.topUpWallet(amt, method);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0D7C66),
        content: Text('⚡ Recharged ₹${amt.toInt()} via $method! Wallet balance updated.'),
      ),
    );
    if (amt >= 300) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          ScratchCardRewardModal.show(context, widget.state, amt.toInt());
        }
      });
    }
  }

  void _showCustomRechargeModal(BuildContext context) {
    final amtCtrl = TextEditingController(text: '1000');
    String selectedMethod = 'PhonePe UPI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('⚡ Recharge Prepaid Wallet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              const Text('Add funds for seamless daily morning doorstep milk deliveries', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 16),

              // Amount Input
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D7C66)),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Enter Recharge Amount',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  hintText: '500',
                ),
              ),
              const SizedBox(height: 14),

              // Payment Methods
              const Text('Select Payment Option:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),

              _buildPaymentOption('📱 PhonePe UPI (Fastest)', selectedMethod, (val) => setSt(() => selectedMethod = val)),
              _buildPaymentOption('⚡ Google Pay (GPay)', selectedMethod, (val) => setSt(() => selectedMethod = val)),
              _buildPaymentOption('🔵 Paytm UPI / Wallet', selectedMethod, (val) => setSt(() => selectedMethod = val)),
              _buildPaymentOption('🏦 NetBanking & Debit Card', selectedMethod, (val) => setSt(() => selectedMethod = val)),

              const SizedBox(height: 14),

              // Promo Offer Strip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Text('🎁', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Recharge ₹500 or more to unlock an interactive scratch card with up to ₹100 cashback!', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.brown)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final enteredAmt = double.tryParse(amtCtrl.text.trim()) ?? 500.0;
                    widget.state.topUpWallet(enteredAmt, selectedMethod);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF0D7C66),
                        content: Text('🎉 Successfully recharged ₹${enteredAmt.toStringAsFixed(0)} via $selectedMethod!'),
                      ),
                    );
                    if (enteredAmt >= 300) {
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (context.mounted) {
                          ScratchCardRewardModal.show(context, widget.state, enteredAmt.toInt());
                        }
                      });
                    }
                  },
                  child: const Text('Proceed to Pay & Recharge ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == label;
    return InkWell(
      onTap: () => onSelect(label),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF0D7C66) : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  void _showReceiptModal(BuildContext context, WalletTransactionModel tx) {
    final isCredit = tx.transactionType == 'CREDIT';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCredit ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
              color: isCredit ? const Color(0xFF10B981) : const Color(0xFF0D7C66),
            ),
            const SizedBox(width: 8),
            const Text('Payment Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    '${isCredit ? "+" : "-"} ₹${tx.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isCredit ? const Color(0xFF0D7C66) : const Color(0xFFE11D48),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCredit ? 'Prepaid Wallet Credit' : 'Doorstep Milk Delivery Debit',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            _buildReceiptRow('Transaction ID', '#TXN-9024-${tx.id}'),
            _buildReceiptRow('Date & Time', tx.createdAt),
            _buildReceiptRow('Description', tx.description),
            _buildReceiptRow('Status', 'SUCCESSFUL (COMPLETED)'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7C66), foregroundColor: Colors.white),
            child: const Text('Close Receipt'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
