import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Production-grade calm, premium morning dairy splash screen
class PambaSplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const PambaSplashScreen({super.key, required this.onFinish});

  @override
  State<PambaSplashScreen> createState() => _PambaSplashScreenState();
}

class _PambaSplashScreenState extends State<PambaSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _rippleController;

  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();

    // 1. Entrance controller (850ms, forward once)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // 2. Ambient glow and loading dots controller (1600ms, repeat forward)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // 3. Ripple expansion controller (800ms, forward once)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start background and reveals immediately (0ms)
    _entranceController.forward();

    // Start ripple effect at 150ms
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _rippleController.forward();
      }
    });

    // Fire haptic tick exactly when wordmark locks in (350ms)
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        HapticFeedback.lightImpact();
      }
    });

    // Exit to next screen at 1300ms
    _exitTimer = Timer(const Duration(milliseconds: 1300), () {
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
    _rippleController.dispose();
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
          // ── 1. Background Gradient (Phase 1: 100ms-500ms) ──
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              final bgProgress = CurvedAnimation(
                parent: _entranceController,
                curve: const Interval(100 / 850, 500 / 850, curve: Curves.easeInOut),
              ).value;

              final color2 = Color.lerp(
                  const Color(0xFF074B3E), const Color(0xFF0D7C66), bgProgress)!;
              final color3 = Color.lerp(
                  const Color(0xFF074B3E), const Color(0xFF085445), bgProgress)!;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF074B3E),
                      color2,
                      color3,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              );
            },
          ),

          // ── 2. Concentric Ripple Effect (Phase 2: 150ms-750ms) ──
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _RipplePainter(_rippleController.value),
              );
            },
          ),

          // ── 3. Ambient Glow (Phase 1 & 5) ──
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_entranceController, _pulseController]),
              builder: (context, child) {
                // Bloom from 100ms to 500ms
                final bloom = CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(100 / 850, 500 / 850, curve: Curves.easeInOut),
                ).value;

                // Breathing effect loops with pulse controller
                final pulse = sin(_pulseController.value * pi);
                final glowOpacity = (0.15 * bloom) + (0.05 * pulse * bloom);

                return Container(
                  width: size.width * 0.85,
                  height: size.width * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF34D399)
                            .withValues(alpha: glowOpacity.clamp(0.0, 1.0)),
                        const Color(0xFF0D7C66)
                            .withValues(alpha: (glowOpacity * 0.4).clamp(0.0, 1.0)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 4. Center Column ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo (Always visible, scale 1.0, opacity 1.0 to prevent double-flash)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFF10B766).withValues(alpha: 0.3),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/pamba_logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset('assets/icons/app_icon.png',
                            fit: BoxFit.cover);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // Typography Reveals
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, child) {
                    // Phase 3: Wordmark (350ms-750ms)
                    final wordmarkAnim = CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(350 / 850, 750 / 850,
                          curve: Curves.easeOutBack),
                    ).value;

                    // Phase 4: Supporting Elements (550ms-850ms)
                    final supportAnim = CurvedAnimation(
                      parent: _entranceController,
                      curve: const Interval(550 / 850, 1.0, curve: Curves.easeOut),
                    ).value;

                    return Column(
                      children: [
                        Transform.translate(
                          offset: Offset(0, 15 * (1 - wordmarkAnim)),
                          child: Opacity(
                            opacity: wordmarkAnim.clamp(0.0, 1.0),
                            child: const Text(
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
                          ),
                        ),

                        const SizedBox(height: 8),

                        Opacity(
                          opacity: supportAnim.clamp(0.0, 1.0),
                          child: const Text(
                            'Farm to Doorstep, Every Morning',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFCCFBEF), // Cream Mint
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Transform.scale(
                          scale: 0.92 + (0.08 * supportAnim),
                          child: Opacity(
                            opacity: supportAnim.clamp(0.0, 1.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5),
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
                                      color: Color(0xFFFDE68A), // Warm gold
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── 5. Bottom Loading Dots & Text ──
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (context, child) {
                final bottomFade = CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(550 / 850, 1.0, curve: Curves.easeOut),
                ).value;

                return Opacity(
                  opacity: bottomFade.clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Forward-only staggered dots
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final delay = i * 0.2;
                              final dotProgress =
                                  ((_pulseController.value + delay) % 1.0);
                              final scale = 0.8 + 0.4 * sin(dotProgress * pi);
                              final alpha = 0.4 + 0.6 * sin(dotProgress * pi);

                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 5 * scale,
                                height: 5 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white
                                      .withValues(alpha: alpha.clamp(0.0, 1.0)),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for expanding concentric ripple rings
class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 70.0; // Logo radius
    final maxRadius = 140.0; // ~2x logo radius

    void drawCircle(double p) {
      if (p <= 0 || p >= 1) return;
      final radius = baseRadius + (maxRadius - baseRadius) * p;
      final opacity = (0.25 * (1 - p)).clamp(0.0, 1.0);
      paint.color = const Color(0xFF34D399).withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }

    // Circle 1
    drawCircle(progress);

    // Circle 2 (delayed by 0.15)
    final p2 = progress - 0.15;
    if (p2 > 0) {
      // Normalize p2 to still finish gracefully
      drawCircle(p2 / 0.85);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
