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
    final phoneText = _phoneController.text.trim();
    if (phoneText.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    _phoneNumber = phoneText.startsWith('+91') ? phoneText : '+91 $phoneText';

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

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Full Name')),
      );
      return;
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
                  'By continuing, you agree to MilkDrop Express Terms of Service & Privacy Policy.',
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
      padding: EdgeInsets.fromLTRB(24, topInset + 44, 24, 40),
      decoration: const BoxDecoration(
        gradient: UiGradient.hero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: UiShadow.glowPrimary,
      ),
      child: Column(
        children: [
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
            '⚡ Farm Fresh Dairy • Guaranteed 6:00 AM Delivery',
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
              const Text('Enter Mobile Number', style: UiText.h2),
            ],
          ),
          const SizedBox(height: 6),
          Text('We will send a 4-digit OTP to verify your account', style: UiText.label),
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
                  decoration: _fieldDecoration(hint: 'Enter 10-digit number'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Prominent Continue CTA Button
          _primaryCta(
            key: const ValueKey('send_otp_btn'),
            onTap: _handleSendOTP,
            label: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Get OTP & Continue', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
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
                    const Text('Enter 4-Digit OTP', style: UiText.h2),
                    const SizedBox(height: 2),
                    Text(
                      'Sent to ${_phoneController.text}',
                      style: const TextStyle(color: UiTone.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.edit_rounded, size: 14, color: UiTone.primary),
                label: const Text('Change', style: TextStyle(color: UiTone.primary, fontSize: 12, fontWeight: FontWeight.bold)),
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
                  _canResend ? 'Resend OTP' : 'Resend in ${_resendSeconds}s',
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
            label: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Verify OTP & Secure Login 🔒', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
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
            const Expanded(child: Text('New Customer Profile', style: UiText.h2)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Complete profile to claim ₹500 welcome milk credit',
          style: TextStyle(color: UiTone.primary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),

        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 12),
        _buildTextField(_emailController, 'Email Address', Icons.email_outlined),
        const SizedBox(height: 16),

        const Text('Select Gender', style: UiText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildGenderChip('Male', '👨 Male'),
            _buildGenderChip('Female', '👩 Female'),
            _buildGenderChip('Other', '👤 Other'),
          ],
        ),
        const SizedBox(height: 22),

        // Prominent Complete Registration Button
        _primaryCta(
          onTap: _handleRegisterCustomer,
          label: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text('Complete & Claim ₹500 🥛', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
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
