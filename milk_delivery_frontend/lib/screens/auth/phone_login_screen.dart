import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/app_state.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

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
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
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
      setState(() => _step = 2); // Move to OTP verification
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0D7C66),
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
    final otpText = _otpController.text.trim();
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
            backgroundColor: Color(0xFF0D7C66),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hero App Branding Icon
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D7C66).withValues(alpha: 0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Text('🥛', style: TextStyle(fontSize: 42)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'MilkDrop Express',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '⚡ Farm Fresh Dairy • Guaranteed 6:00 AM Delivery',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 22),

                      // Card Shell
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _buildCurrentStepView(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Notice
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
              child: Text(
                'By continuing, you agree to MilkDrop Express Terms of Service & Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 9.5),
              ),
            ),
          ],
        ),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 8),
              const Text('Enter Mobile Number', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('We will send a 4-digit OTP to verify your account', style: TextStyle(color: Colors.grey[400], fontSize: 11.5)),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text('+91', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 10-digit number',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13, letterSpacing: 0),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Prominent Continue CTA Button
          InkWell(
            key: const ValueKey('send_otp_btn'),
            onTap: _isLoading ? null : _handleSendOTP,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get OTP & Continue', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                      ],
                    ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter 4-Digit OTP', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Sent to ${_phoneController.text}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF38BDF8)),
                label: const Text('Change', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 14),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 26, letterSpacing: 14),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.key_rounded, size: 13, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text('Test OTP: 1234', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _canResend ? _handleSendOTP : null,
                child: Text(
                  _canResend ? 'Resend OTP' : 'Resend in ${_resendSeconds}s',
                  style: TextStyle(
                    color: _canResend ? const Color(0xFF38BDF8) : Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          InkWell(
            key: const ValueKey('verify_otp_btn'),
            onTap: _isLoading ? null : _handleVerifyOTP,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Verify OTP & Secure Login 🔒', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🎁', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 8),
            const Text('New Customer Profile', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Complete profile to claim ₹500 welcome milk credit', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),

        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 12),
        _buildTextField(_emailController, 'Email Address', Icons.email_outlined),
        const SizedBox(height: 14),

        const Text('Select Gender', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
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
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegisterCustomer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Complete & Claim ₹500 🥛', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderChip(String genderValue, String labelText) {
    final isSelected = _selectedGender == genderValue;
    return ChoiceChip(
      label: Text(labelText),
      selected: isSelected,
      selectedColor: const Color(0xFF0D7C66),
      backgroundColor: const Color(0xFF0F172A),
      side: BorderSide(
        color: isSelected ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.2),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
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
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 18),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      ),
    );
  }
}

