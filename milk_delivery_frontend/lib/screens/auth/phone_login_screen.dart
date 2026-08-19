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
  bool _isPasswordLoginMode = false;
  bool _isLoading = false;
  String _phoneNumber = '';
  String _selectedGender = 'Male';
  bool _obscurePassword = true;

  // Timer for OTP resend
  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool _canResend = false;

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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

  // Password Login Handler (for Admin & Staff)
  void _handlePasswordLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await ApiService.login(username, password);
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      final profile = await ApiService.fetchUserProfile();
      if (profile != null) {
        await widget.state.onUserAuthenticated(profile);
      } else {
        await widget.state.reloadAllData();
      }
      widget.onLoginSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D7C66),
            content: Text('👋 Welcome back, ${profile?.firstName ?? username}!'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Invalid username or password')),
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
                        child: Column(
                          children: [
                            // Dual-Mode Login Switcher Tabs
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _isPasswordLoginMode = false;
                                        _step = 1;
                                      }),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: !_isPasswordLoginMode ? const Color(0xFF0D7C66) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '📱 Phone OTP',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: !_isPasswordLoginMode ? Colors.white : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _isPasswordLoginMode = true),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _isPasswordLoginMode ? const Color(0xFF0D7C66) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '🔑 Password Login',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _isPasswordLoginMode ? Colors.white : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            if (_isPasswordLoginMode)
                              _buildPasswordLoginView()
                            else
                              _buildCurrentStepView(),
                          ],
                        ),
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

  Widget _buildPasswordLoginView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Staff & Admin Login', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('Sign in with your username & password credentials', style: TextStyle(color: Colors.grey[400], fontSize: 11.5)),
        const SizedBox(height: 18),

        // Username Field
        _buildTextField(_usernameController, 'Username or Mobile', Icons.person_outline),
        const SizedBox(height: 12),

        // Password Field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter Password',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981), size: 18),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),

        // Quick Fill for Admin
        InkWell(
          onTap: () {
            setState(() {
              _usernameController.text = 'admin';
              _passwordController.text = 'admin123';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Text('🛡️ Fill Admin: admin / admin123', style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),

        // Prominent Sign In Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePasswordLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Sign In to Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepView() {
    if (_step == 1) {
      // Step 1: Mobile Phone Number Input
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter Mobile Number', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('We will send a 4-digit OTP to verify your account', style: TextStyle(color: Colors.grey[400], fontSize: 11.5)),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 4),
                    Text('+91', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 10-digit number',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Demo Fill
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildDemoPhoneChip('🛡️ Super Admin Phone', '8919548905', const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 20),

          // Prominent Continue CTA Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get OTP & Continue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    if (_step == 2) {
      // Step 2: OTP Verification
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Enter 4-Digit OTP', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.edit, color: Color(0xFF10B981), size: 13),
                label: const Text('Edit', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text('Code sent to $_phoneNumber', style: TextStyle(color: Colors.grey[400], fontSize: 11.5)),
          const SizedBox(height: 14),

          // Test OTP Hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 16),
                SizedBox(width: 6),
                Text('Test OTP is fixed: 1234', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _canResend ? 'Didn\'t receive OTP?' : 'Resend in ${_resendSeconds}s',
                style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
              ),
              if (_canResend)
                TextButton(
                  onPressed: _handleSendOTP,
                  child: const Text('Resend OTP', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Prominent Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyOTP,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D7C66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Verify OTP & Login 🔒', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
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
        const Row(
          children: [
            Text('🎁', style: TextStyle(fontSize: 20)),
            SizedBox(width: 6),
            Text('New Customer Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        const Text('Complete profile to claim ₹500 welcome milk credit', style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 10),
        _buildTextField(_emailController, 'Email Address', Icons.email_outlined),
        const SizedBox(height: 12),

        const Text('Select Gender', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildGenderChip('Male', '👨 Male'),
            _buildGenderChip('Female', '👩 Female'),
            _buildGenderChip('Other', '👤 Other'),
          ],
        ),
        const SizedBox(height: 20),

        // Prominent Complete Registration Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegisterCustomer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Complete & Claim ₹500 🥛', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoPhoneChip(String label, String phone, Color accentColor) {
    return InkWell(
      onTap: () {
        setState(() {
          _phoneController.text = phone;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          '$label: $phone',
          style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String genderValue, String labelText) {
    final isSelected = _selectedGender == genderValue;
    return ChoiceChip(
      label: Text(labelText),
      selected: isSelected,
      selectedColor: const Color(0xFF0D7C66),
      backgroundColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedGender = genderValue);
      },
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 18),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
