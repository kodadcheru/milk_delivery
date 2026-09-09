import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ui_tokens.dart';

/// Next-gen 4-box OTP input with animated orbit curl, spin verification,
/// and green checkmark verdict tile inspired by @_code_and_chill_
class OrbitOtpBoxes extends StatefulWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final ValueChanged<String>? onCompleted;
  final bool isVerifying;
  final bool isSuccess;
  final bool isError;
  final VoidCallback? onResetError;

  const OrbitOtpBoxes({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.onCompleted,
    this.isVerifying = false,
    this.isSuccess = false,
    this.isError = false,
    this.onResetError,
  });

  @override
  State<OrbitOtpBoxes> createState() => OrbitOtpBoxesState();
}

class OrbitOtpBoxesState extends State<OrbitOtpBoxes> with TickerProviderStateMixin {
  late final AnimationController _morphController;
  late final AnimationController _spinController;
  late final AnimationController _successController;
  late final AnimationController _shakeController;

  late final Animation<double> _morphAnimation;
  late final Animation<double> _shakeAnimation;
  late final Animation<double> _successScaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Morph row -> orbit ring (450ms)
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutCubic,
    );

    // 2. Spin the orbit ring while verifying (1000ms per turn)
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 3. Verdict success: screw down into single verified tile (400ms)
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successScaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    // 4. Verdict error: shake horizontally (400ms)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _syncWithProps();
  }

  @override
  void didUpdateWidget(covariant OrbitOtpBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWithProps();
  }

  void _syncWithProps() {
    if (widget.isSuccess) {
      _spinController.stop();
      _successController.forward();
      HapticFeedback.mediumImpact();
    } else if (widget.isError) {
      _spinController.stop();
      _successController.reset();
      _shakeController.forward(from: 0.0).then((_) {
        _morphController.reverse();
        widget.onResetError?.call();
      });
      HapticFeedback.heavyImpact();
    } else if (widget.isVerifying) {
      if (!_morphController.isCompleted) {
        _morphController.forward();
      }
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
      HapticFeedback.lightImpact();
    } else {
      // Idle state
      _spinController.stop();
      _spinController.reset();
      _successController.reset();
      if (_morphController.value > 0) {
        _morphController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _spinController.dispose();
    _successController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    final count = widget.controllers.length;
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < count; i++) {
        if (i < digits.length) {
          widget.controllers[i].text = digits[i];
        } else {
          widget.controllers[i].clear();
        }
      }
      if (digits.length >= count) {
        widget.focusNodes[count - 1].unfocus();
        widget.onCompleted?.call(digits.substring(0, count));
      } else if (digits.isNotEmpty) {
        widget.focusNodes[digits.length.clamp(0, count - 1)].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty) {
      if (index < count - 1) {
        widget.focusNodes[index + 1].requestFocus();
      } else {
        widget.focusNodes[index].unfocus();
        final code = widget.controllers.map((c) => c.text.trim()).join();
        if (code.length == count) {
          widget.onCompleted?.call(code);
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final count = widget.controllers.length;
        final boxWidth = count >= 6 ? 44.0 : 58.0;
        final boxHeight = count >= 6 ? 54.0 : 62.0;
        const orbitRadius = 38.0;
        const orbitBoxSize = 24.0;

        // Container height: 84px
        const containerHeight = 84.0;
        final centerX = totalWidth / 2;
        final centerY = containerHeight / 2;

        // Row positions for N boxes
        final spacing = count > 1 ? (totalWidth - (count * boxWidth)) / (count - 1) : 0.0;
        final rowCentersX = List.generate(count, (i) {
          return (i * (boxWidth + spacing)) + (boxWidth / 2);
        });

        return AnimatedBuilder(
          animation: Listenable.merge([
            _morphAnimation,
            _spinController,
            _successScaleAnimation,
            _shakeAnimation,
          ]),
          builder: (context, child) {
            final t = _morphAnimation.value;
            final isSuccess = widget.isSuccess && _successScaleAnimation.value > 0.1;

            // Shake offset calculation
            double shakeX = 0.0;
            if (_shakeController.isAnimating) {
              final progress = _shakeAnimation.value;
              shakeX = math.sin(progress * math.pi * 6) * 10 * (1 - progress);
            }

            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: SizedBox(
                width: totalWidth,
                height: containerHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // ── Orbit Hub Glow (Visible when morphing or verifying) ──
                    if (t > 0.05 && !isSuccess)
                      Positioned(
                        left: centerX - orbitRadius - 10,
                        top: centerY - orbitRadius - 10,
                        child: Container(
                          width: (orbitRadius * 2) + 20,
                          height: (orbitRadius * 2) + 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: UiTone.primary.withValues(alpha: 0.18 * t),
                              width: 1.5,
                            ),
                            gradient: RadialGradient(
                              colors: [
                                UiTone.primary.withValues(alpha: 0.12 * t),
                                Colors.transparent,
                              ],
                              stops: const [0.2, 1.0],
                            ),
                          ),
                        ),
                      ),

                    // ── The N Boxes / Orbiting Tiles ──
                    if (!isSuccess)
                      for (int i = 0; i < count; i++)
                        _buildAnimatedTile(
                          index: i,
                          count: count,
                          t: t,
                          rowCenterX: rowCentersX[i],
                          centerY: centerY,
                          centerX: centerX,
                          boxWidth: boxWidth,
                          boxHeight: boxHeight,
                          orbitRadius: orbitRadius,
                          orbitBoxSize: orbitBoxSize,
                        ),

                    // ── Single Verified Tile on Success ──
                    if (isSuccess)
                      Center(
                        child: Transform.scale(
                          scale: _successScaleAnimation.value,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: UiTone.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: UiTone.primary.withValues(alpha: 0.4),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedTile({
    required int index,
    required int count,
    required double t,
    required double rowCenterX,
    required double centerY,
    required double centerX,
    required double boxWidth,
    required double boxHeight,
    required double orbitRadius,
    required double orbitBoxSize,
  }) {
    final controller = widget.controllers[index];
    final focusNode = widget.focusNodes[index];
    final isFilled = controller.text.isNotEmpty;
    final isFocused = focusNode.hasFocus;

    // Orbit angle for index i distributed evenly
    final baseAngle = (index * (2 * math.pi / count));
    final spinAngle = _spinController.value * (2 * math.pi);
    final currentAngle = baseAngle + spinAngle;

    // Current position interpolated from row to orbit
    final targetOrbitX = centerX + (orbitRadius * math.cos(currentAngle));
    final targetOrbitY = centerY + (orbitRadius * math.sin(currentAngle));

    final currentX = rowCenterX + (targetOrbitX - rowCenterX) * t;
    final currentY = centerY + (targetOrbitY - centerY) * t;

    // Interpolated dimensions
    final currentW = boxWidth + (orbitBoxSize - boxWidth) * t;
    final currentH = boxHeight + (orbitBoxSize - boxHeight) * t;
    final currentRadius = 12.0 + (orbitBoxSize / 2 - 12.0) * t;

    // Tile styling
    final Color bgColor = t > 0.6
        ? UiTone.primary
        : (isFocused ? Colors.white : (isFilled ? UiTone.primarySoft : UiTone.surfaceMuted));

    final Color borderColor = isFocused || t > 0.4
        ? UiTone.primary
        : (isFilled ? UiTone.primary : UiTone.surfaceBorder);

    final double borderWidth = isFocused ? 2.2 : (isFilled || t > 0.4 ? 1.6 : 1.0);

    return Positioned(
      left: currentX - (currentW / 2),
      top: currentY - (currentH / 2),
      child: Container(
        width: currentW,
        height: currentH,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(currentRadius),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: isFocused || t > 0.5
              ? [
                  BoxShadow(
                    color: UiTone.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: t > 0.5
              ? (currentW > 18
                  ? Text(
                      controller.text.isNotEmpty ? controller.text : '•',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    )
                  : const SizedBox.shrink())
              : Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                      if (controller.text.isEmpty && index > 0) {
                        widget.controllers[index - 1].clear();
                        widget.focusNodes[index - 1].requestFocus();
                        setState(() {});
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: index == count - 1 ? TextInputAction.done : TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(count),
                    ],
                    style: const TextStyle(
                      color: UiTone.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (val) => _onDigitChanged(index, val),
                  ),
                ),
        ),
      ),
    );
  }
}
