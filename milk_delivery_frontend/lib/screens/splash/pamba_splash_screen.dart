import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Real-world inspired, sleek brand splash screen for Pamba Fresh
/// Modeled after modern quick-commerce and dairy apps (Zepto, Swiggy, Starbucks, Country Delight)
class PambaSplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const PambaSplashScreen({super.key, required this.onFinish});

  @override
  State<PambaSplashScreen> createState() => _PambaSplashScreenState();
}

class _PambaSplashScreenState extends State<PambaSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _bottomFade;

  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();

    // 1. Fluid brand entrance animation (850ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // 2. Subtle ambient breathing glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.80, curve: Curves.easeIn),
      ),
    );

    _bottomFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.50, 1.0, curve: Curves.easeIn),
      ),
    );

    _entranceController.forward();

    // Snappy, modern total display duration: ~1350ms
    _exitTimer = Timer(const Duration(milliseconds: 1350), () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF074B3E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Rich Signature Brand Teal Gradient Background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF074B3E), // Deep Forest Teal
                  Color(0xFF0D7C66), // Iconic Brand Teal
                  Color(0xFF085445), // Grounded Rich Teal
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── 2. Subtle Radial Light Accent Behind Centerpiece ──
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glow = 0.12 + (_pulseController.value * 0.08);
                return Container(
                  width: size.width * 0.85,
                  height: size.width * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF34D399).withValues(alpha: glow),
                        const Color(0xFF0D7C66).withValues(alpha: glow * 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 3. Centered Brand Identity ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular Brand Emblem with Soft Elevation & Ambient Ring
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(0xFF34D399).withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFFDE68A).withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
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
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // Brand Name & Tagline
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        // Wordmark: "Pamba Fresh"
                        const Text(
                          'Pamba Fresh',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle: "Farm to Doorstep, Every Morning"
                        const Text(
                          'Farm to Doorstep, Every Morning',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFCCFBEF), // Soft mint
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Telugu Cultural Authenticity Chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🌾', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 6),
                              Text(
                                'కోదాడ & పరిసర గ్రామాల తాజా పాలు',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 4. Bottom Watermark & Minimal Native Loader ──
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _bottomFade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minimal 3-dot pulse animation
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final delay = index * 0.3;
                          final animValue = ((_pulseController.value + delay) % 1.0);
                          final opacity = 0.3 + (animValue * 0.7);
                          final scale = 0.8 + (animValue * 0.4);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 5 * scale,
                            height: 5 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: opacity),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PAMBA DAIRIES • 100% PURE & FRESH',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
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
