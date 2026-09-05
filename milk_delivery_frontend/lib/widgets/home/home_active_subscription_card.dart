import 'package:flutter/material.dart';
import '../../models/subscription_model.dart';
import '../../providers/app_state.dart';
import '../../theme/ui_tokens.dart';

class HomeActiveSubscriptionCard extends StatefulWidget {
  final AppState state;
  final SubscriptionModel sub;

  const HomeActiveSubscriptionCard({
    super.key,
    required this.state,
    required this.sub,
  });

  @override
  State<HomeActiveSubscriptionCard> createState() => _HomeActiveSubscriptionCardState();
}

class _HomeActiveSubscriptionCardState extends State<HomeActiveSubscriptionCard> {
  late int _tempQuantity;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tempQuantity = widget.sub.quantity;
  }

  @override
  void didUpdateWidget(covariant HomeActiveSubscriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sub.quantity != widget.sub.quantity && !_isUpdating) {
      _tempQuantity = widget.sub.quantity;
    }
  }

  Future<void> _updateQuantity(int delta) async {
    final newQty = _tempQuantity + delta;
    if (newQty < 0 || newQty > 10) return;
    
    setState(() {
      _tempQuantity = newQty;
      _isUpdating = true;
    });

    final success = await widget.state.updateSubscriptionQuantity(widget.sub.id, newQty);
    
    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (!success) {
          _tempQuantity = widget.sub.quantity;
        }
      });
    }
  }

  String _calculateCountdown() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 5, 30);
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    final diff = target.difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final pName = widget.sub.productDetail != null
        ? widget.sub.productDetail!.localizedName(widget.state.currentLanguage)
        : widget.state.translateProduct('Daily Farm Fresh Milk');
    final pPrice = widget.sub.displayPrice;
    final countdown = _calculateCountdown();
    final isPaused = widget.sub.status != 'ACTIVE';
    final streakDays = widget.sub.streakDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPaused
                ? [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]
                : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(UiRadius.lg),
          border: Border.all(
            color: isPaused
                ? const Color(0xFFFCD34D)
                : const Color(0xFF86EFAC).withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPaused ? const Color(0xFFD97706) : const Color(0xFF0D7C66)).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Title & Dynamic Live Countdown ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isPaused
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : UiTone.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPaused ? Icons.pause_circle_rounded : Icons.autorenew_rounded,
                          color: isPaused ? const Color(0xFFD97706) : UiTone.primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPaused ? 'Subscription Paused' : 'Daily Morning Drop',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: isPaused ? const Color(0xFFB45309) : const Color(0xFF064E3B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (streakDays > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                            borderRadius: BorderRadius.circular(UiRadius.pill),
                          ),
                          child: Text(
                            '🔥 $streakDays days',
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isPaused
                              ? const LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)])
                              : const LinearGradient(colors: [Color(0xFF0D7C66), Color(0xFF0A5C4C)]),
                          borderRadius: BorderRadius.circular(UiRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaused ? Icons.schedule : Icons.bolt_rounded,
                              size: 11,
                              color: isPaused ? const Color(0xFFB45309) : const Color(0xFF34D399),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPaused ? 'On Hold' : 'Next in $countdown',
                              style: TextStyle(
                                color: isPaused ? const Color(0xFF92400E) : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Product Info Row ──
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UiRadius.md),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.sub.productDetail?.icon ?? '🥛', style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: UiTone.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.sub.packSize,
                                style: const TextStyle(
                                  color: UiTone.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${(pPrice * widget.sub.quantity).toStringAsFixed(0)} / drop • ${widget.sub.scheduleType}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => widget.state.setTab(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      side: const BorderSide(color: UiTone.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: UiTone.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.07)),
              const SizedBox(height: 11),

              // ── Quick Actions ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (widget.sub.status == 'ACTIVE') {
                          await widget.state.pauseTomorrow(widget.sub.id);
                        } else {
                          await widget.state.toggleSubscriptionStatus(widget.sub.id);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: UiTone.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              content: Text(
                                widget.sub.status == 'ACTIVE' ? '⏸️ Delivery paused for tomorrow!' : '▶️ Subscription resumed!',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        widget.sub.status == 'ACTIVE' ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                        size: 15,
                      ),
                      label: Text(
                        widget.sub.status == 'ACTIVE' ? 'Pause Tomorrow' : 'Resume Drop',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        foregroundColor: widget.sub.status == 'ACTIVE' ? const Color(0xFFD97706) : UiTone.primary,
                        side: BorderSide(
                          color: widget.sub.status == 'ACTIVE' ? const Color(0xFFF59E0B) : UiTone.primary,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.state.setTab(1),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: const Text(
                        'Edit Plan & Drop',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        backgroundColor: UiTone.primary,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.xs)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // ── Tomorrow Quantity Override Stepper ──
              Container(
                decoration: BoxDecoration(
                  color: UiTone.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                  border: Border.all(color: UiTone.primary.withValues(alpha: 0.2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tomorrow\'s Quantity:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: UiTone.ink,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _isUpdating || _tempQuantity <= 0 ? null : () => _updateQuantity(-1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _tempQuantity > 0 ? Colors.white : Colors.grey[200],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: _tempQuantity > 0 ? UiTone.ink : Colors.grey,
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 32),
                          alignment: Alignment.center,
                          child: _isUpdating 
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  '$_tempQuantity',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        InkWell(
                          onTap: _isUpdating || _tempQuantity >= 10 ? null : () => _updateQuantity(1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _tempQuantity < 10 ? Colors.white : Colors.grey[200],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: _tempQuantity < 10 ? UiTone.ink : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
