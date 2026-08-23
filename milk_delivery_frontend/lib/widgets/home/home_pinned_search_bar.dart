import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

/// Search field that stays reachable after the hero scrolls off.
///
/// Wired as a `SliverPersistentHeader(pinned: true)`. The customer shell has no
/// `SafeArea`, so once this header pins to the very top it would underlap the
/// status bar — the delegate bakes `MediaQuery.padding.top` into its extent and
/// the child pads its content down by the same amount, filling the inset with
/// the shell background so status-bar glyphs stay legible.
class HomePinnedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const HomePinnedSearchBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  State<HomePinnedSearchBar> createState() => _HomePinnedSearchBarState();
}

class _HomePinnedSearchBarState extends State<HomePinnedSearchBar> {
  Timer? _hintTimer;
  Timer? _debounceTimer;
  int _currentHintIndex = 0;

  final List<String> _hints = const [
    'A2 Cow Milk',
    'Farm Eggs',
    'Chicken Breast',
    'Water Can',
    'Buffalo Milk',
    'Mutton Cuts',
  ];

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hints.length;
        });
      }
    });

    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _handleSearch(String value) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        widget.onSearchChanged(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _SearchDelegate(
        topInset: topInset,
        child: Container(
          color: UiTone.shellBackground,
          padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UiRadius.md),
              boxShadow: [
                BoxShadow(
                  color: UiTone.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UiRadius.md),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    border: Border.all(
                      color: UiTone.primary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(UiRadius.md),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (widget.controller.text.isEmpty)
                        Positioned(
                          left: 48,
                          right: 48,
                          child: IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _hints[_currentHintIndex],
                                key: ValueKey<int>(_currentHintIndex),
                                style: const TextStyle(
                                  color: UiText.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      TextField(
                        controller: widget.controller,
                        onChanged: _handleSearch,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: UiTone.ink,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: UiTone.primary,
                            size: 22,
                          ),
                          suffixIcon: widget.controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: UiText.muted,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    widget.controller.clear();
                                    widget.onClearSearch();
                                    _handleSearch('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchDelegate extends SliverPersistentHeaderDelegate {
  final double topInset;
  final Widget child;

  _SearchDelegate({
    required this.topInset,
    required this.child,
  });

  // 50 field + 8 top pad + 8 bottom pad = 66, plus the status-bar inset baked in
  // so the pinned bar clears the notch once the hero scrolls away.
  double get _extent => 66 + topInset;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SearchDelegate oldDelegate) {
    return oldDelegate.topInset != topInset || oldDelegate.child != child;
  }
}
