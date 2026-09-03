import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/app_state.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../theme/ui_text.dart';
import '../../theme/ui_tokens.dart';

class PhoneLoginScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onLoginSuccess;

  const PhoneLoginScreen({
    super.key,
    required this.state,
    required this.onLoginSuccess,
  });

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  int _step = 1; // 1: Phone Input, 2: OTP Verification, 3: New Customer Registration
  bool _isLoading = false;
  String _phoneNumber = '';
  String _selectedGender = 'Male';

  // Timer for OTP resend
  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool _canResend = false;

  // Controllers
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // 4 Square OTP Box Controllers & Focus Nodes
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      _otpFocusNodes[i].addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String _getOtpValue() => _otpControllers.map((c) => c.text.trim()).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted multi-digit OTP e.g. "1234"
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 4; i++) {
        if (i < digits.length) {
          _otpControllers[i].text = digits[i];
        } else {
          _otpControllers[i].clear();
        }
      }
      if (digits.length >= 4) {
        _otpFocusNodes[3].unfocus();
        _handleVerifyOTP();
      } else if (digits.isNotEmpty) {
        _otpFocusNodes[digits.length.clamp(0, 3)].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty) {
      if (index < 3) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        if (_getOtpValue().length == 4) {
          _handleVerifyOTP();
        }
      }
    }
    setState(() {});
  }

  // Step 1: Send OTP
  void _handleSendOTP() async {
    final rawText = _phoneController.text.trim();
    final digitsOnly = rawText.replaceAll(RegExp(r'\D'), '');

    String clean10 = digitsOnly;
    if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      clean10 = digitsOnly.substring(2);
    } else if (digitsOnly.length > 10) {
      clean10 = digitsOnly.substring(digitsOnly.length - 10);
    }

    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(clean10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            widget.state.isTelugu
                ? 'దయచేసి 6, 7, 8 లేదా 9 తో ప్రారంభమయ్యే సరైన 10 అంకెల మొబైల్ నంబర్‌ను నమోదు చేయండి'
                : 'Please enter a valid 10-digit mobile number starting with 6, 7, 8, or 9',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    _phoneNumber = '+91 $clean10';

    final res = await ApiService.sendOTP(_phoneNumber);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      for (final c in _otpControllers) {
        c.clear();
      }
      setState(() => _step = 2); // Move to OTP verification
      _startResendTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_otpFocusNodes[0].canRequestFocus) {
          _otpFocusNodes[0].requestFocus();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('⚡ OTP sent to your phone! Test OTP is 1234.'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to send OTP')),
        );
      }
    }
  }

  // Step 2: Verify OTP
  void _handleVerifyOTP() async {
    final otpText = _getOtpValue();
    if (otpText.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 4-digit OTP code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await ApiService.verifyOTP(_phoneNumber, otpText);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (res['is_new_user'] == true) {
        // Route to New Customer Registration Form
        setState(() => _step = 3);
      } else {
        // Existing user: sync & login
        if (res['user'] != null) {
          final user = UserModel.fromJson(res['user']);
          await widget.state.onUserAuthenticated(user);
        } else {
          await widget.state.reloadAllData();
        }
        widget.onLoginSuccess();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Invalid OTP code')),
        );
      }
    }
  }

  // Step 3: Complete Registration
  void _handleRegisterCustomer() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            widget.state.isTelugu
                ? 'దయచేసి మీ పూర్తి పేరును నమోదు చేయండి (కనీసం 2 అక్షరాలు)'
                : 'Please enter your Full Name (at least 2 characters)',
          ),
        ),
      );
      return;
    }

    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              widget.state.isTelugu
                  ? 'దయచేసి సరైన ఈమెయిల్ చిరునామాను నమోదు చేయండి (ఉదా: name@example.com)'
                  : 'Please enter a valid email address (e.g. name@example.com)',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    final res = await ApiService.registerMobileUser(
      phone: _phoneNumber,
      firstName: name,
      email: email,
      gender: _selectedGender,
    );
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      if (res['user'] != null) {
        final user = UserModel.fromJson(res['user']);
        await widget.state.onUserAuthenticated(user);
      } else {
        await widget.state.reloadAllData();
      }
      widget.onLoginSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: UiTone.primary,
            content: Text('🎉 Registration Complete! ₹500 welcome bonus credited to your wallet.'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Registration failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Teal hero paints under the status bar → light glyphs for contrast.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: UiTone.shellBackground,
        // top:false — the hero gradient paints up under the status bar for an
        // edge-to-edge branded header; the footer still clears the bottom inset.
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeroHeader(context),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: UiTone.surface,
                            borderRadius: BorderRadius.circular(UiRadius.xl),
                            border: Border.all(color: UiTone.surfaceBorder),
                            boxShadow: UiShadow.elevated,
                          ),
                          child: _buildCurrentStepView(),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),

              // Footer Notice
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 32, 14),
                child: Text(
                  widget.state.tr('terms_notice'),
                  textAlign: TextAlign.center,
                  style: UiText.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Branded gradient header ──
  Widget _buildHeroHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: UiGradient.hero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: UiShadow.glowPrimary,
      ),
      child: Column(
        children: [
          // Top row with Language Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  widget.state.toggleLanguage();
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        widget.state.isTelugu ? 'English' : 'తెలుగు',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Frosted brand mark
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            ),
            child: const Text('🥛', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Pamba',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.state.isTelugu
                ? '⚡ స్వచ్ఛమైన ఫారం పాలు • ప్రతిరోజూ ఉదయం ఇంటి వద్దకే'
                : '⚡ Farm Fresh Dairy • Guaranteed 6:00 AM Delivery',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView() {
    if (_step == 1) {
      // Step 1: Mobile Phone Number Input
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stepHeaderBadge(
                const Icon(Icons.phone_android_rounded, color: UiTone.primary, size: 18),
                UiTone.primarySoft,
              ),
              const SizedBox(width: 10),
              Text(widget.state.tr('login_heading'), style: UiText.h2),
            ],
          ),
          const SizedBox(height: 6),
          Text(widget.state.tr('login_sub'), style: UiText.label),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  color: UiTone.surfaceMuted,
                  borderRadius: BorderRadius.circular(UiRadius.md),
                  border: Border.all(color: UiTone.surfaceBorder),
                ),
                child: const Row(
                  children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text('+91', style: TextStyle(color: UiTone.ink, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(color: UiTone.ink, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1),
                  decoration: _fieldDecoration(hint: widget.state.isTelugu ? '10 అంకెల మొబైల్ నంబర్' : 'Enter 10-digit number'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Prominent Continue CTA Button
          _primaryCta(
            key: const ValueKey('send_otp_btn'),
            onTap: _handleSendOTP,
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.state.tr('send_otp'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              ],
            ),
          ),
        ],
      );
    }

    if (_step == 2) {
      // Step 2: OTP Verification Form
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.state.isTelugu ? '4 అంకెల OTP ని నమోదు చేయండి' : 'Enter 4-Digit OTP', style: UiText.h2),
                    const SizedBox(height: 2),
                    Text(
                      widget.state.isTelugu ? '${_phoneController.text} కు SMS పంపబడింది' : 'Sent to ${_phoneController.text}',
                      style: const TextStyle(color: UiTone.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.edit_rounded, size: 14, color: UiTone.primary),
                label: Text(widget.state.isTelugu ? 'మార్చండి' : 'Change', style: const TextStyle(color: UiTone.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildOtpSquareBoxes(),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: UiTone.primarySoft,
                  borderRadius: BorderRadius.circular(UiRadius.xs),
                  border: Border.all(color: UiTone.primary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.key_rounded, size: 13, color: UiTone.primary),
                    SizedBox(width: 4),
                    Text('Test OTP: 1234', style: TextStyle(color: UiTone.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _canResend ? _handleSendOTP : null,
                child: Text(
                  _canResend ? widget.state.tr('resend_otp') : (widget.state.isTelugu ? 'మళ్లీ పంపడానికి ${_resendSeconds}సె' : 'Resend in ${_resendSeconds}s'),
                  style: TextStyle(
                    color: _canResend ? UiTone.primary : UiText.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _primaryCta(
            key: const ValueKey('verify_otp_btn'),
            onTap: _handleVerifyOTP,
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.state.tr('verify_otp'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
          ),
        ],
      );
    }

    // Step 3: New Customer Registration Form
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _stepHeaderBadge(
              const Text('🎁', style: TextStyle(fontSize: 18)),
              UiTone.warningSoft,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.state.isTelugu ? 'కొత్త కస్టమర్ ప్రొఫైల్' : 'New Customer Profile', style: UiText.h2)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.state.isTelugu ? 'పూర్తి చేసి ₹500 స్వాగత వాలెట్ క్రెడిట్ పొందండి' : 'Complete profile to claim ₹500 welcome milk credit',
          style: const TextStyle(color: UiTone.primary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),

        _buildTextField(_nameController, widget.state.isTelugu ? 'పూర్తి పేరు' : 'Full Name', Icons.person_outline),
        const SizedBox(height: 12),
        _buildTextField(_emailController, widget.state.isTelugu ? 'ఈమెయిల్ చిరునామా' : 'Email Address', Icons.email_outlined),
        const SizedBox(height: 16),

        Text(widget.state.isTelugu ? 'లింగం ఎంచుకోండి' : 'Select Gender', style: UiText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildGenderChip('Male', widget.state.isTelugu ? '👨 పురుషుడు' : '👨 Male'),
            _buildGenderChip('Female', widget.state.isTelugu ? '👩 మహిళ' : '👩 Female'),
            _buildGenderChip('Other', widget.state.isTelugu ? '👤 ఇతర' : '👤 Other'),
          ],
        ),
        const SizedBox(height: 22),

        // Prominent Complete Registration Button
        _primaryCta(
          onTap: _handleRegisterCustomer,
          label: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(widget.state.isTelugu ? 'నమోదు పూర్తి చేయండి 🥛' : 'Complete & Claim ₹500 🥛', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared building blocks ──

  /// Rounded tint chip that leads each step's title.
  Widget _stepHeaderBadge(Widget child, Color bg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(UiRadius.sm),
      ),
      child: child,
    );
  }

  /// Full-width gradient CTA shared by all three steps.
  Widget _primaryCta({Key? key, required VoidCallback onTap, required Widget label}) {
    return InkWell(
      key: key,
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(UiRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: UiGradient.primary,
          borderRadius: BorderRadius.circular(UiRadius.md),
          boxShadow: UiShadow.glowPrimary,
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : label,
      ),
    );
  }

  /// Light-theme input decoration shared by the phone + profile fields.
  InputDecoration _fieldDecoration({required String hint, IconData? prefixIcon}) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(color: UiText.muted, fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: UiTone.primary, size: 18) : null,
      filled: true,
      fillColor: UiTone.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UiRadius.md),
        borderSide: const BorderSide(color: UiTone.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UiRadius.md),
        borderSide: const BorderSide(color: UiTone.primary, width: 1.5),
      ),
    );
  }

  Widget _buildGenderChip(String genderValue, String labelText) {
    final isSelected = _selectedGender == genderValue;
    return ChoiceChip(
      label: Text(labelText),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: UiTone.primary,
      backgroundColor: UiTone.surfaceMuted,
      side: BorderSide(
        color: isSelected ? UiTone.primary : UiTone.surfaceBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiRadius.sm)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : UiTone.softText,
        fontWeight: FontWeight.bold,
        fontSize: 11.5,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedGender = genderValue);
      },
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: UiTone.ink, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _fieldDecoration(hint: label, prefixIcon: icon),
    );
  }

  Widget _buildOtpSquareBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) => _buildOtpSquareBox(index)),
    );
  }

  Widget _buildOtpSquareBox(int index) {
    final controller = _otpControllers[index];
    final focusNode = _otpFocusNodes[index];
    final isFilled = controller.text.isNotEmpty;
    final isFocused = focusNode.hasFocus;

    return Container(
      width: 58,
      height: 62,
      decoration: BoxDecoration(
        color: isFocused ? Colors.white : (isFilled ? UiTone.primarySoft : UiTone.surfaceMuted),
        borderRadius: BorderRadius.circular(UiRadius.md),
        border: Border.all(
          color: isFocused ? UiTone.primary : (isFilled ? UiTone.primary : UiTone.surfaceBorder),
          width: isFocused ? 2.2 : (isFilled ? 1.6 : 1.0),
        ),
        boxShadow: isFocused ? UiShadow.glowPrimary : null,
      ),
      child: Center(
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
              if (controller.text.isEmpty && index > 0) {
                _otpControllers[index - 1].clear();
                _otpFocusNodes[index - 1].requestFocus();
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
            textInputAction: index == 3 ? TextInputAction.done : TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
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
            onChanged: (val) => _onOtpDigitChanged(index, val),
          ),
        ),
      ),
    );
  }
}
