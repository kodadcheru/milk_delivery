import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/scratch_card_modal.dart';

class WalletTab extends StatefulWidget {
  final AppState state;

  const WalletTab({super.key, required this.state});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  String _selectedFilter = 'ALL'; // ALL, CREDIT, DEBIT

  void _showRechargeModal(BuildContext context, {double defaultAmount = 500.0}) {
    AppTheme.hapticLight();
    final ctrl = TextEditingController(text: defaultAmount.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.darkSlate,
            borderRadius: BorderRadius.vertical(top: Radius.circular(UiRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '💳 Top Up Milk Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Prepaid wallet balance is auto-debited only after daily doorstep drop',
                style: TextStyle(color: UiTone.softText, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Preset Quick Chips with Cashback
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _rechargeChip('₹500', 500, '+₹25 Bonus', ctrl),
                    const SizedBox(width: 8),
                    _rechargeChip('₹1,000', 1000, '+₹75 Bonus 🔥', ctrl),
                    const SizedBox(width: 8),
                    _rechargeChip('₹2,000', 2000, '+₹200 Bonus 👑', ctrl),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Custom Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: AppTheme.primaryMint, fontSize: 22, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    hintText: 'Enter amount',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    AppTheme.hapticLight();
                    final amt = double.tryParse(ctrl.text.trim()) ?? 500.0;
                    Navigator.pop(ctx);
                    await widget.state.topUpWallet(amt, 'UPI / Instant Pay');
                    if (context.mounted) {
                      AppTheme.hapticSuccess();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ ₹${amt.toStringAsFixed(0)} credited to your Pamba wallet!'),
                          backgroundColor: AppTheme.primaryMint,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryMint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, size: 20),
                      SizedBox(width: 6),
                      Text('Proceed via UPI / Instant Pay', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rechargeChip(String label, double amount, String bonus, TextEditingController ctrl) {
    return InkWell(
      onTap: () {
        AppTheme.hapticLight();
        ctrl.text = amount.toStringAsFixed(0);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(UiRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(UiRadius.sm),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(bonus, style: const TextStyle(color: AppTheme.accentAmber, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bal = widget.state.currentUser?.walletBalance ?? 0.0;
    final allTxs = widget.state.transactions;
    // Assuming a base price of 68.0 for 1L of milk as a fallback
    int estDays = (bal / 68.0).floor();

    final filteredTxs = allTxs.where((t) {
      if (_selectedFilter == 'CREDIT') return t.transactionType == 'CREDIT';
      if (_selectedFilter == 'DEBIT') return t.transactionType == 'DEBIT';
      return true;
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        color: AppTheme.primaryTeal,
        onRefresh: () => widget.state.reloadAllData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 💳 Holographic Platinum Milk Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppTheme.holographicCardGradient,
                borderRadius: BorderRadius.circular(UiRadius.xl),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
                boxShadow: UiShadow.elevated,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(UiRadius.xs),
                              border: Border.all(color: AppTheme.accentAmber),
                            ),
                            child: const Row(
                              children: [
                                Text('⭐', style: TextStyle(fontSize: 10)),
                                SizedBox(width: 4),
                                Text(
                                  'Platinum Farm Club',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryMint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                          border: Border.all(color: AppTheme.primaryMint),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppTheme.primaryMint, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'Auto-Debit 🟢',
                              style: TextStyle(color: AppTheme.primaryMint, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.state.isTelugu
                        ? 'అందుబాటులో ఉన్న ప్రీపెయిడ్ బ్యాలెన్స్'
                        : 'AVAILABLE PREPAID MILK BALANCE',
                    style: const TextStyle(color: UiTone.softText, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${bal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiRadius.sm),
                        ),
                        child: Text(
                          estDays > 0 ? '🗓️ ~$estDays Days Milk Covered' : '⚠️ Top Up Needed',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRechargeModal(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Money / Top Up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryMint,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: () {
                          AppTheme.hapticLight();
                          ScratchCardRewardModal.show(context, widget.state, 500);
                        },
                        icon: const Text('🎁', style: TextStyle(fontSize: 18)),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Monthly Farm Savings Metric (Removed) ──

            const SizedBox(height: 20),

            // ── Transaction Ledger Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Ledger',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    _filterChip('ALL', 'All'),
                    const SizedBox(width: 4),
                    _filterChip('CREDIT', 'Credits'),
                    const SizedBox(width: 4),
                    _filterChip('DEBIT', 'Debits'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (filteredTxs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: UiTone.surface,
                  borderRadius: BorderRadius.circular(UiRadius.lg),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Column(
                  children: [
                    Text('🧾', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 8),
                    Text(
                      'No transactions yet',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTxs.length,
                separatorBuilder: (_, index) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final t = filteredTxs[idx];
                  final isCredit = t.transactionType == 'CREDIT';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: UiTone.surface,
                      borderRadius: BorderRadius.circular(UiRadius.lg),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCredit
                                ? AppTheme.primaryMint.withValues(alpha: 0.12)
                                : UiTone.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(UiRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: isCredit ? AppTheme.primaryMint : UiTone.error,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.description,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.createdAt,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isCredit ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isCredit ? AppTheme.primaryMint : UiTone.error,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () {
        AppTheme.hapticLight();
        setState(() => _selectedFilter = filterKey);
      },
      borderRadius: BorderRadius.circular(UiRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal : AppTheme.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(UiRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
