import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
    with SingleTickerProviderStateMixin {
  // Bell shake animation
  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

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

  final List<Map<String, String>> _curatedBanners = [
    {
      'title': 'Fresh Pasture Cows 🐄',
      'url': 'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'title': 'Pure Morning Milk 🥛',
      'url': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'title': 'Organic Green Farm 🌿',
      'url': 'https://images.unsplash.com/photo-1500595046743-cd271d694d30?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'title': 'Sunrise Harvest 🌅',
      'url': 'https://images.unsplash.com/photo-1516253593875-bd7ba052fbc5?auto=format&fit=crop&w=1200&q=80',
    },
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
    widget.searchController?.removeListener(_onSearchListener);
    super.dispose();
  }

  void _openBannerUploadSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildBannerPickerModal(ctx),
    );
  }

  Widget _buildBannerPickerModal(BuildContext modalCtx) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customize Top Banner 🎨',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              if (widget.state.customBannerImagePath != null)
                TextButton(
                  onPressed: () {
                    widget.state.setCustomBannerImage(null);
                    Navigator.pop(modalCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔄 Reset to default emerald gradient!')),
                    );
                  },
                  child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload a photo from your gallery or choose a farm preset to personalize your top banner.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // Upload Action Buttons (Camera & Gallery)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 88);
                    if (picked != null) {
                      widget.state.setCustomBannerImage(picked.path);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📸 Custom banner updated successfully!')),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0D7C66).withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Color(0xFF0D7C66), size: 26),
                        SizedBox(height: 6),
                        Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0D7C66))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
                    if (picked != null) {
                      widget.state.setCustomBannerImage(picked.path);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🖼️ Gallery banner updated successfully!')),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 26),
                        SizedBox(height: 6),
                        Text('Choose Gallery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text('Or Select Preset Wallpaper:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155))),
          const SizedBox(height: 10),

          // Presets Grid
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _curatedBanners.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final item = _curatedBanners[idx];
                final isSelected = widget.state.customBannerImagePath == item['url'];
                return GestureDetector(
                  onTap: () {
                    widget.state.setCustomBannerImage(item['url']!);
                    Navigator.pop(modalCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✨ Applied "${item['title']}" banner!')),
                    );
                  },
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0D7C66) : Colors.transparent,
                        width: 2.5,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(item['url']!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        item['title']!,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getBannerImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final state = widget.state;
    final city = state.activeAddress?.title ?? 'Kodad';
    final subtitle = state.activeAddress?.summaryAddress ?? state.currentDeliveryAddress;
    final unreadNotifs = state.unreadNotificationCount;
    final customBanner = state.customBannerImagePath;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 14, 16, 26),
      decoration: BoxDecoration(
        color: const Color(0xFF0E784D),
        gradient: customBanner == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16A267), Color(0xFF0E784D), Color(0xFF074E32)],
              )
            : null,
        image: customBanner != null
            ? DecorationImage(
                image: _getBannerImageProvider(customBanner)!,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.52),
                  BlendMode.darken,
                ),
              )
            : null,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B6D44).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Bar: Location Selector + Upload Button + Notification Bell ──
          Row(
            children: [
              // Location Selector
              Expanded(
                child: GestureDetector(
                  onTap: widget.onLocationTap,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                            Text(
                              subtitle.length > 35 ? '${subtitle.substring(0, 35)}...' : subtitle,
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

              // Upload Banner Button (Service-Mobile App style)
              GestureDetector(
                onTap: _openBannerUploadSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Banner',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Notification Bell
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => NotificationsScreen(state: state),
                    ),
                  );
                },
                child: AnimatedBuilder(
                  animation: _bellAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _bellAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        if (unreadNotifs > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadNotifs > 9 ? '9+' : '$unreadNotifs',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
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

          const SizedBox(height: 14),

          // ── Integrated Top Banner Search Bar (Service-Mobile App Style) ──
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                  color: Color(0xFF0D7C66),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.searchController,
                    onChanged: widget.onSearchChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: "Search '${_hints[_currentHintIndex]}'...",
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (widget.searchController?.text.isNotEmpty == true)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                    onPressed: widget.onClearSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D7C66).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Color(0xFF0D7C66),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Morning Dispatch Promo Strip ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'MORNING DROP 05:30 AM ☀️',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                ),
                child: const Text(
                  '🥛 FRESH TODAY',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Headline
          const Text(
            'Order by 11PM Tonight →',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle + CTA
          Row(
            children: [
              const Expanded(
                child: Text(
                  '❄️ 4°C Cold Chain • Farm to Doorstep • Kodad Hub',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDFF7EA),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(UiRadius.pill),
                ),
                child: const Text(
                  'SUBSCRIBE NOW ➔',
                  style: TextStyle(
                    color: Color(0xFF0D7C66),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
