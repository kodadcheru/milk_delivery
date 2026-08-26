import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PambaSplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const PambaSplashScreen({super.key, required this.onFinish});

  @override
  State<PambaSplashScreen> createState() => _PambaSplashScreenState();
}

class _PambaSplashScreenState extends State<PambaSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _masterController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _glowAnimation;

  int _currentTagIndex = 0;
  Timer? _tagTimer;

  final List<String> _features = [
    '✨ 100% Pure Certified Vedic Dairy',
    '🌿 Farm-Fresh Organic Groceries & Vegetables',
    '☀️ Guaranteed 05:30 AM Doorstep Drop',
    '❄️ 4.0°C Monitored Cold Chain Logistics',
  ];

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scaleAnimation = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.05, 0.70, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _glowAnimation = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.2, 0.85, curve: Curves.easeInOut),
    );

    _masterController.forward();

    _tagTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (mounted) {
        setState(() {
          _currentTagIndex = (_currentTagIndex + 1) % _features.length;
        });
      }
    });

    // Auto-proceed callback
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _tagTimer?.cancel();
    _masterController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF03160F), // Deep Forest Emerald
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Deep Forest Emerald Textured Gradient Base ──
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF0D3829), // Rich Forest Green Center
                  Color(0xFF062319), // Deep Emerald Mid
                  Color(0xFF02120C), // Dark Obsidian Base
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── 2. Faint Morning Sunbeam Light Streaks (Top Ambient) ──
          Positioned(
            top: -size.width * 0.35,
            left: -size.width * 0.1,
            right: -size.width * 0.1,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glow = 0.18 + (_pulseController.value * 0.08);
                return Container(
                  height: size.width * 1.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE5B54F).withValues(alpha: glow), // Radiant Golden Beam
                        const Color(0xFF10B981).withValues(alpha: glow * 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Subtle Bottom Ambient Reflection
          Positioned(
            bottom: -size.width * 0.4,
            left: 0,
            right: 0,
            child: Container(
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // ── 3. Centered Brand Identity & Golden Line-Art Logo ──
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Embossed Golden Brand Icon Emblem
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft Golden Ambient Shimmer Halo
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 175 + (_pulseController.value * 18),
                              height: 175 + (_pulseController.value * 18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE5B54F).withValues(alpha: 0.22 - (_pulseController.value * 0.12)),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE5B54F).withValues(alpha: 0.12 + (_pulseController.value * 0.08)),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Outer Luxury Golden Border Ring
                        FadeTransition(
                          opacity: _glowAnimation,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  Color(0xFFFFF6D6),
                                  Color(0xFFE5B54F),
                                  Color(0xFF8C6218),
                                  Color(0xFFF9DC7D),
                                  Color(0xFFFFF6D6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE5B54F).withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(2.5),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF041C13), // Deep inner emerald base
                              ),
                            ),
                          ),
                        ),

                        // Brand Circular Logo Asset (Rising sun, cow silhouette, wicker harvest basket, milk bottle)
                        Container(
                          width: 154,
                          height: 154,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/pamba_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/icons/app_icon.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── 4. Brand Naming & Subtitle in High-Contrast Gold Typography ──
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          // Primary Title: "Pamba Fresh" in Shimmering Gold
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFFFFF9E6), // Bright highlight
                                  Color(0xFFF3C76A), // Rich radiant gold
                                  Color(0xFFE5B54F), // Metallic gold
                                  Color(0xFFC9952E), // Deep gold edge
                                ],
                                stops: [0.0, 0.35, 0.70, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds);
                            },
                            child: const Text(
                              'Pamba Fresh',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                                height: 1.1,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Secondary Tagline: "Farm-Fresh Dairy, Groceries & Vegetables"
                          const Text(
                            'Farm-Fresh Dairy, Groceries & Vegetables',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFE2C98F), // Soft Warm Gold
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Telugu Cultural Freshness Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5B54F).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE5B54F).withValues(alpha: 0.30),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              '🌾 కోదాడ & చుట్టుపక్కల గ్రామాల నుంచి తాజా సరఫరా',
                              style: TextStyle(
                                color: Color(0xFFF3C76A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // ── 5. Animated Rotating Feature Pill Tracker ──
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey<int>(_currentTagIndex),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF042116).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE5B54F).withValues(alpha: 0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _features[_currentTagIndex],
                          style: const TextStyle(
                            color: Color(0xFFFFF6D6),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 6. Bottom Elegant Minimal Progress Indicator & Version ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        minHeight: 2.0,
                        backgroundColor: Color(0x33E5B54F),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5B54F)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pamba Fresh v1.0.0 • Pure Vedic Farm Heritage',
                    style: TextStyle(
                      color: const Color(0xFFE5B54F).withValues(alpha: 0.65),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
