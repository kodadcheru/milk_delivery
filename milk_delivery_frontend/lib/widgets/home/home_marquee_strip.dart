import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Infinitely scrolling horizontal marquee strip — "Farm-fresh milk • Delivered by 6 AM • ..."
class HomeMarqueeStrip extends StatefulWidget {
  const HomeMarqueeStrip({super.key});

  @override
  State<HomeMarqueeStrip> createState() => _HomeMarqueeStripState();
}

class _HomeMarqueeStripState extends State<HomeMarqueeStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ScrollController _scrollController;

  static const _items = [
    '🥛 Farm-Fresh Milk',
    '⏰ Delivered by 6 AM',
    '🌿 100% Natural',
    '💰 Subscribe & Save',
    '🚚 Free Daily Delivery',
    '📅 Pause Anytime',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _controller.addListener(_scroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _controller.repeat();
      }
    });
  }

  void _scroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = maxScroll * _controller.value;
    _scrollController.jumpTo(currentScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_scroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build a repeated list for seamless looping
    final repeatedItems = [..._items, ..._items, ..._items];
    
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: UiTone.primary.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: UiTone.primary.withValues(alpha: 0.1)),
          bottom: BorderSide(color: UiTone.primary.withValues(alpha: 0.1)),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: repeatedItems.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    repeatedItems[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: UiTone.primary.withValues(alpha: 0.8),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: UiTone.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
