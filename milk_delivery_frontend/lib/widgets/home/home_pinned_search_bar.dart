import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

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
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SearchDelegate(
        minExtent: 66,
        maxExtent: 66,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B766).withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    border: Border.all(
                      color: const Color(0xFF10B766).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(16),
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
                                  color: Color(0xFF94A3B8),
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
                            color: Color(0xFF0D7C66),
                            size: 22,
                          ),
                          suffixIcon: widget.controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF94A3B8),
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
  final double _minExtent;
  final double _maxExtent;
  final Widget child;

  _SearchDelegate({
    required double minExtent,
    required double maxExtent,
    required this.child,
  })  : _minExtent = minExtent,
        _maxExtent = maxExtent;

  @override
  double get minExtent => _minExtent;

  @override
  double get maxExtent => _maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SearchDelegate oldDelegate) {
    return true;
  }
}
