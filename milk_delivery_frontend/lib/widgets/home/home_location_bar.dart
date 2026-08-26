import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../screens/customer/notifications_screen.dart';
import '../../theme/ui_tokens.dart';

class HomeLocationBar extends StatefulWidget {
  final AppState state;
  final VoidCallback onLocationTap;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;

  const HomeLocationBar({
    super.key,
    required this.state,
    required this.onLocationTap,
    this.searchController,
    this.onSearchChanged,
    this.onClearSearch,
  });

  @override
  State<HomeLocationBar> createState() => _HomeLocationBarState();
}

class _HomeLocationBarState extends State<HomeLocationBar>
    with TickerProviderStateMixin {
  // Bell shake animation
  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  // Location pin pulse animation (Service-Mobile style)
  late AnimationController _locationPulseController;
  late Animation<double> _locationPulseScale;

  // Search hint rotator
  Timer? _hintTimer;
  int _currentHintIndex = 0;
  final List<String> _hints = const [
    'A2 Fresh Cow Milk',
    'Organic Farm Eggs',
    'Thick Buffalo Curd',
    'Mineral Water 20L',
    'Pure Cow Ghee',
    'Farm Fresh Paneer',
  ];

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bellAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _bellController, curve: Curves.easeInOut));

    // Continuous smooth location breathing pulse
    _locationPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _locationPulseScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _locationPulseController, curve: Curves.easeInOut),
    );

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hints.length;
        });
      }
    });

    widget.searchController?.addListener(_onSearchListener);
  }

  void _onSearchListener() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomeLocationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.unreadNotificationCount > 0 &&
        oldWidget.state.unreadNotificationCount != widget.state.unreadNotificationCount) {
      _bellController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _bellController.dispose();
    _locationPulseController.dispose();
    widget.searchController?.removeListener(_onSearchListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final state = widget.state;
    final city = state.activeAddress?.title ?? (state.activeAddress?.customTag.isNotEmpty == true ? state.activeAddress!.customTag : 'Kodad');
    final subtitle = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
    final unreadNotifs = state.unreadNotificationCount;
    final sf = state.storefrontConfig;

    final bannerUrl = sf.bannerImageUrl.trim();
    final hasCustomBanner = bannerUrl.isNotEmpty;
    final hasAnyText = sf.headline.trim().isNotEmpty ||
        sf.subtitle.trim().isNotEmpty ||
        sf.dispatchTag.trim().isNotEmpty ||
        sf.promoChip.trim().isNotEmpty ||
        sf.ctaText.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: hasAnyText ? 260 : 160),
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, hasAnyText ? 28 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E784D),
        gradient: !hasCustomBanner
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16A267), Color(0xFF0E784D), Color(0xFF074E32)],
              )
            : null,
        image: hasCustomBanner
            ? DecorationImage(
                image: NetworkImage(bannerUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: hasAnyText ? 0.52 : 0.28),
                  BlendMode.darken,
                ),
              )
            : null,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B6D44).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Bar: Location Selector + Notification Bell ──
          Row(
            children: [
              // Location Selector
              Expanded(
                child: GestureDetector(
                  onTap: widget.onLocationTap,
                  child: Row(
                    children: [
                      // Pulsing Location Icon Box (Service-Mobile Signature)
                      AnimatedBuilder(
                        animation: _locationPulseScale,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _locationPulseScale.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Eyebrow with Live Status Tag
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'DELIVERY LOCATION',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFDFF7EA),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'LIVE 📍',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            // Main Locality Name & Subtitle
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'CHANGE',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white,
                                        size: 13,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              subtitle.length > 36 ? '${subtitle.substring(0, 36)}...' : subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFDFF7EA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Notification Bell
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationsScreen(state: state),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        if (unreadNotifs > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 8,
                                minHeight: 8,
                              ),
                              child: Text(
                                unreadNotifs > 9 ? '9+' : '$unreadNotifs',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Seamless Blended Translucent Search Bar ──
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.searchController,
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search '${_hints[_currentHintIndex]}'...",
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (widget.searchController?.text.isNotEmpty == true)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                    onPressed: widget.onClearSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),

          // ── Storefront Promo Strip (Only rendered if text is present) ──
          if (sf.dispatchTag.trim().isNotEmpty || sf.promoChip.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                if (sf.dispatchTag.trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      sf.dispatchTag.trim(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (sf.promoChip.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                    ),
                    child: Text(
                      sf.promoChip.trim(),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Headline (Only rendered if text is present)
          if (sf.headline.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              sf.headline.trim(),
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ],

          // Subtitle + CTA (Only rendered if text is present)
          if (sf.subtitle.trim().isNotEmpty || sf.ctaText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (sf.subtitle.trim().isNotEmpty)
                  Expanded(
                    child: Text(
                      sf.subtitle.trim(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDFF7EA),
                        height: 1.25,
                      ),
                    ),
                  ),
                if (sf.ctaText.trim().isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UiRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      sf.ctaText.trim(),
                      style: const TextStyle(
                        color: Color(0xFF0D7C66),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
