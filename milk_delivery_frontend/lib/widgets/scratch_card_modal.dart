import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class ScratchCardRewardModal extends StatefulWidget {
  final AppState state;
  final int rechargeAmount;

  const ScratchCardRewardModal({
    super.key,
    required this.state,
    required this.rechargeAmount,
  });

  static void show(BuildContext context, AppState state, int rechargeAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ScratchCardRewardModal(state: state, rechargeAmount: rechargeAmount),
    );
  }

  @override
  State<ScratchCardRewardModal> createState() => _ScratchCardRewardModalState();
}

class _ScratchCardRewardModalState extends State<ScratchCardRewardModal> with SingleTickerProviderStateMixin {
  bool _isScratched = false;
  late final int _cashback;
  late AnimationController _confettiAnim;

  @override
  void initState() {
    super.initState();
    _cashback = widget.rechargeAmount >= 1000 ? 100 : (widget.rechargeAmount >= 500 ? 50 : 25);
    _confettiAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _confettiAnim.dispose();
    super.dispose();
  }

  void _revealReward() {
    if (_isScratched) return;
    setState(() {
      _isScratched = true;
    });
    _confettiAnim.forward();
    widget.state.topUpWallet(_cashback.toDouble(), 'Cashback Reward');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎁', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    'RECHARGE BONUS REWARD',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _isScratched ? '🎉 Congratulations!' : 'You unlocked a Scratch Card!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              _isScratched ? 'Cashback instantly credited to your MilkDrop wallet.' : 'Tap the card below to reveal your instant cashback reward.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Scratch Card Container
            InkWell(
              onTap: _revealReward,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  gradient: _isScratched
                      ? const LinearGradient(
                          colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_isScratched ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _isScratched
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('₹', style: TextStyle(fontSize: 24, color: Colors.white70, fontWeight: FontWeight.bold)),
                          Text('₹$_cashback', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          const Text('Direct Cashback Credited! 🥳', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 36)),
                          const SizedBox(height: 6),
                          const Text('TAP TO SCRATCH', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          const SizedBox(height: 2),
                          Text('Win up to ₹100 Cashback', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Claim / Close CTA
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  if (!_isScratched) {
                    _revealReward();
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isScratched ? 'Done & Return to Wallet' : 'Scratch & Claim Now',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
