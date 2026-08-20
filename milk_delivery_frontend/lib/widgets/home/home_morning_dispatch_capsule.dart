import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/ui_tokens.dart';

class HomeMorningDispatchCapsule extends StatefulWidget {
  final AppState state;

  const HomeMorningDispatchCapsule({super.key, required this.state});

  @override
  State<HomeMorningDispatchCapsule> createState() => _HomeMorningDispatchCapsuleState();
}

class _HomeMorningDispatchCapsuleState extends State<HomeMorningDispatchCapsule> {
  late Timer _timer;
  String _hoursStr = '04';
  String _minsStr = '12';
  String _secsStr = '00';

  @override
  void initState() {
    super.initState();
    _calcTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calcTimeLeft());
  }

  void _calcTimeLeft() {
    final now = DateTime.now();
    var cutoff = DateTime(now.year, now.month, now.day, 23, 0); // 11:00 PM cutoff for next morning
    if (now.isAfter(cutoff)) {
      cutoff = cutoff.add(const Duration(days: 1));
    }
    final diff = cutoff.difference(now);
    if (mounted) {
      setState(() {
        _hoursStr = diff.inHours.toString().padLeft(2, '0');
        _minsStr = (diff.inMinutes % 60).toString().padLeft(2, '0');
        _secsStr = (diff.inSeconds % 60).toString().padLeft(2, '0');
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeHub = widget.state.locationHubs.isNotEmpty ? widget.state.locationHubs.first : null;
    final hubName = activeHub != null ? (activeHub['name'] ?? 'Kodad Depot') : 'Kodad Depot';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.morningSkyGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: UiTone.surface.withValues(alpha: 0.12), width: 1.2),
        boxShadow: UiShadow.card,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryMint,
                      shape: BoxShape.circle,
                      boxShadow: UiShadow.card,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE • $hubName',
                    style: const TextStyle(
                      color: AppTheme.primaryMint,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UiTone.surface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(UiRadius.lg),
                ),
                child: const Row(
                  children: [
                    Text('❄️', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 4),
                    Text(
                      '4°C Cold Chain',
                      style: TextStyle(color: UiTone.surface, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order for Morning 05:30 AM Drop',
                      style: TextStyle(
                        color: UiTone.surface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Subscribe by 11:00 PM tonight for farm doorstep drop tomorrow',
                      style: TextStyle(
                        color: UiTone.surface.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: UiTone.surface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CUTOFF IN',
                      style: TextStyle(color: AppTheme.accentAmber, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_hoursStr:$_minsStr:$_secsStr',
                      style: const TextStyle(
                        color: UiTone.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
