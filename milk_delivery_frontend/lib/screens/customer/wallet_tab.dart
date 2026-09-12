import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_tokens.dart';
import '../../widgets/ui_kit/ui_empty_state.dart';
import '../../widgets/ui_kit/pamba_refresh_indicator.dart';

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
              Text(
                widget.state.isTelugu ? '💳 వాలెట్ టాప్ అప్' : '💳 Top Up Milk Wallet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.state.isTelugu
                    ? 'రోజూ డోర్‌స్టెప్ డెలివరీ పూర్తయిన తర్వాత మాత్రమే వాలెట్ నుండి మొత్తం డెబిట్ అవుతుంది'
                    : 'Prepaid wallet balance is auto-debited only after daily doorstep drop',
                style: const TextStyle(color: UiTone.softText, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Preset Quick Chips with Cashback
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _rechargeChip('₹500', 500, widget.state.isTelugu ? '+₹25 బోనస్' : '+₹25 Bonus', ctrl),
                    const SizedBox(width: 8),
                    _rechargeChip('₹1,000', 1000, widget.state.isTelugu ? '+₹75 బోనస్ 🔥' : '+₹75 Bonus 🔥', ctrl),
                    const SizedBox(width: 8),
                    _rechargeChip('₹2,000', 2000, widget.state.isTelugu ? '+₹200 బోనస్ 👑' : '+₹200 Bonus 👑', ctrl),
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
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: AppTheme.primaryMint, fontSize: 22, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    hintText: widget.state.isTelugu ? 'మొత్తం నమోదు చేయండి' : 'Enter amount',
                    hintStyle: const TextStyle(color: Colors.white38),
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
                    await widget.state.topUpWallet(amt, 'Razorpay');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryMint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.md)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        widget.state.isTelugu ? 'రేజర్‌పే ద్వారా చెల్లించండి' : 'Pay with Razorpay',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
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

  Widget _quickRechargeChip(String label, double amount) {
    return GestureDetector(
      onTap: () => _showRechargeModal(context, defaultAmount: amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryMint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(UiRadius.pill),
          border: Border.all(color: AppTheme.primaryMint.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryMint,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bal = widget.state.currentUser?.walletBalance ?? 0.0;
    final allTxs = widget.state.transactions;

    final filteredTxs = allTxs.where((t) {
      if (_selectedFilter == 'CREDIT') return t.transactionType == 'CREDIT';
      if (_selectedFilter == 'DEBIT') return t.transactionType == 'DEBIT';
      return true;
    }).toList();

    return SafeArea(
      child: PambaRefreshIndicator(
        onRefresh: () => widget.state.reloadAllData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 💳 Premium Balance Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.emeraldGradient,
                borderRadius: BorderRadius.circular(UiRadius.lg),
                boxShadow: UiShadow.elevated,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.state.isTelugu ? 'పాంబ వాలెట్' : 'Pamba Wallet',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Animated balance counter
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: bal),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '₹${value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Add Money button
                  GestureDetector(
                    onTap: () => _showRechargeModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(UiRadius.pill),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.state.isTelugu ? 'డబ్బులు జోడించండి' : 'Add Money',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            
            // ── Quick Recharge Chips ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickRechargeChip('₹500', 500),
                const SizedBox(width: 8),
                _quickRechargeChip('₹1,000', 1000),
                const SizedBox(width: 8),
                _quickRechargeChip('₹2,000', 2000),
              ],
            ),

            const SizedBox(height: 20),

            // ── Transaction Ledger Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.state.isTelugu ? 'లావాదేవీల చరిత్ర' : 'Transaction Ledger',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    _filterChip('ALL', widget.state.isTelugu ? 'అన్నీ' : 'All'),
                    const SizedBox(width: 4),
                    _filterChip('CREDIT', widget.state.isTelugu ? 'జమ' : 'Credits'),
                    const SizedBox(width: 4),
                    _filterChip('DEBIT', widget.state.isTelugu ? 'ఖర్చు' : 'Debits'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (filteredTxs.isEmpty)
              UiEmptyState(
                emoji: '💰',
                title: widget.state.isTelugu ? 'లావాదేవీలు ఏవీ లేవు' : 'No Transactions Yet',
                message: widget.state.isTelugu
                    ? 'మీ పాంబ వాలెట్‌కు డబ్బులు జోడించండి, లావాదేవీల చరిత్ర ఇక్కడ కనిపిస్తుంది.'
                    : 'Add money to your Pamba Wallet and your transaction history will show here.',
                action: ElevatedButton(
                  onPressed: () => _showRechargeModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryMint,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.state.isTelugu ? 'ఇప్పుడే టాప్ అప్ చేయండి' : 'Top Up Now',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: isCredit ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 16,
                            color: isCredit ? UiTone.success : UiTone.error,
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
