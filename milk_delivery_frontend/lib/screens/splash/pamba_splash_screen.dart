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
  late final Animation<double> _ringAnimation;

  int _currentTagIndex = 0;
  Timer? _tagTimer;

  final List<String> _features = [
    '🥛 100% Pure Certified Dairy',
    '🚜 Direct From Heritage Vedic Farms',
    '🛵 Guaranteed 05:30 AM Doorstep Drop',
    '❄️ 3.8°C Monitored Cold Chain',
  ];

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scaleAnimation = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.1, 0.75, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _ringAnimation = CurvedAnimation(
      parent: _masterController,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOutQuad),
    );

    _masterController.forward();

    _tagTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (mounted) {
        setState(() {
          _currentTagIndex = (_currentTagIndex + 1) % _features.length;
        });
      }
    });

    // Auto-proceed callback
    Future.delayed(const Duration(milliseconds: 2400), () {
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
      backgroundColor: const Color(0xFF060911),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Cinematic Background Ambient Lights ──
          Positioned(
            top: -size.width * 0.4,
            left: -size.width * 0.2,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.2);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: size.width * 1.2,
                    height: size.width * 1.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00F59B).withValues(alpha: 0.18),
                          const Color(0xFF0D7C66).withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: -size.width * 0.3,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // ── 2. Master Centered Emblem & Branding ──
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Emblem Box with Glowing Rings
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient Breathing Pulse Ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 140 + (_pulseController.value * 16),
                              height: 140 + (_pulseController.value * 16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00F59B).withValues(alpha: 0.25 - (_pulseController.value * 0.15)),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                        // Outer Expanding Ring
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F59B), Color(0xFF0D7C66), Color(0xFF0284C7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F59B).withValues(alpha: 0.35),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Inner Obsidian Shield Glass
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF081220),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '🥛',
                              style: TextStyle(fontSize: 54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App Title with Metallic Gradient & Spring Slide
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return const LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Color(0xFFE2E8F0),
                                      Color(0xFF00F59B),
                                    ],
                                    stops: [0.0, 0.6, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds);
                                },
                                child: const Text(
                                  'PAMBA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4.0,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Localized Dual Subtitle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F59B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF00F59B).withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'పాంబ • స్వచ్ఛమైన ఆవు & గేదె పాలు',
                              style: TextStyle(
                                color: Color(0xFF00F59B),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Animated Rotating Feature Pill Tracker
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Text(
                          _features[_currentTagIndex],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Bottom Minimal Progress Loader & Version ──
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F59B)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pamba v1.0.0 • Farm Fresh Daily 🥛',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
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
