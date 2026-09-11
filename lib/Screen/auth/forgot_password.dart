import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../theme/pawstay_theme.dart';
import 'login.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 1 = Enter Email, 2 = Verify OTP, 3 = Reset Password, 4 = Success
  int _currentStep = 1;

  final _emailCtr = TextEditingController();
  final List<TextEditingController> _otpCtrs = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  final _newPasswordCtr = TextEditingController();
  final _confirmPasswordCtr = TextEditingController();

  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isResending = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailCtr.dispose();
    for (final controller in _otpCtrs) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _newPasswordCtr.dispose();
    _confirmPasswordCtr.dispose();
    super.dispose();
  }

  String get _email => _emailCtr.text.trim().toLowerCase();
  String get _otpCode => _otpCtrs.map((c) => c.text).join();

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade700 : PawStayTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Step 1: Send OTP to Email ---
  Future<void> _sendOtp() async {
    if (!_formKeyEmail.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': _email}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => _currentStep = 2);
        _showSnackBar(data['message'] ?? 'OTP code sent to your email.');
      } else {
        _showSnackBar(data['detail'] ?? 'Failed to send OTP.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 2: Verify OTP ---
  Future<void> _verifyOtp() async {
    if (_otpCode.length != 4) {
      _showSnackBar('Please enter the 4-digit OTP code.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': _email, 'otp': _otpCode}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => _currentStep = 3);
        _showSnackBar('OTP verified! Please set your new password.');
      } else {
        _showSnackBar(
          data['detail'] ?? 'Invalid OTP code. Please check and try again.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Step 2 Sub: Resend OTP ---
  Future<void> _resendOtp() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': _email}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        for (final ctr in _otpCtrs) {
          ctr.clear();
        }
        if (_otpFocusNodes.isNotEmpty) {
          _otpFocusNodes.first.requestFocus();
        }
        _showSnackBar('A new OTP has been sent to your email.');
      } else {
        _showSnackBar(data['detail'] ?? 'Failed to resend OTP.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // --- Step 3: Reset Password ---
  Future<void> _resetPassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;

    final newPwd = _newPasswordCtr.text.trim();
    final confirmPwd = _confirmPasswordCtr.text.trim();

    if (newPwd != confirmPwd) {
      _showSnackBar('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _email,
              'new_password': newPwd,
              'confirm_password': confirmPwd,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() => _currentStep = 4);
        _showSnackBar('Password reset successfully!');
      } else {
        _showSnackBar(
          data['detail'] ?? 'Failed to reset password.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      final chars = value.split('');
      for (int i = 0; i < _otpCtrs.length; i++) {
        _otpCtrs[i].text = i < chars.length ? chars[i] : '';
      }
      _otpFocusNodes.last.requestFocus();
      return;
    }

    if (value.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFAF5F0);
    const primaryBrown = Color(0xFF964024);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back Button
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    if (_currentStep > 1 && _currentStep < 4) {
                      setState(() => _currentStep--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Badge
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _currentStep == 1
                                        ? Icons.vpn_key_rounded
                                        : _currentStep == 2
                                        ? Icons.mark_email_read_rounded
                                        : _currentStep == 3
                                        ? Icons.lock_reset_rounded
                                        : Icons.check_circle_rounded,
                                    size: 42,
                                    color: primaryBrown,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFAAD0A7),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: bgColor,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Title & Subtitle
                        Text(
                          _currentStep == 1
                              ? 'Forgot Password?'
                              : _currentStep == 2
                              ? 'Verify OTP'
                              : _currentStep == 3
                              ? 'New Password'
                              : 'Password Reset',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _currentStep == 1
                                ? "Enter your email address and we'll send a 4-digit verification code to your inbox."
                                : _currentStep == 2
                                ? "Enter the 4-digit verification code sent to $_email."
                                : _currentStep == 3
                                ? "Create a new strong password for your PawStay account."
                                : "Your password has been successfully reset. You can now log in with your new credentials.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.black54,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Main Card View
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: _currentStep == 1
                              ? _buildStep1Email(primaryBrown)
                              : _currentStep == 2
                              ? _buildStep2Otp(primaryBrown)
                              : _currentStep == 3
                              ? _buildStep3NewPassword(primaryBrown)
                              : _buildStep4Success(primaryBrown),
                        ),

                        const SizedBox(height: 24),

                        // Back to Login Link
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Return to Login',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryBrown,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 1: Email Form ---
  Widget _buildStep1Email(Color primaryBrown) {
    const lightInputFill = Color(0xFFEFEBE6);

    return Form(
      key: _formKeyEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email ID',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtr,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'human@example.com',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.black38,
                fontSize: 15,
              ),
              filled: true,
              fillColor: lightInputFill,
              prefixIcon: const Icon(
                Icons.mail_outline_rounded,
                color: Colors.black45,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBrown, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(val.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send OTP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: OTP Verification Form ---
  Widget _buildStep2Otp(Color primaryBrown) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 62,
              child: TextField(
                controller: _otpCtrs[index],
                focusNode: _otpFocusNodes[index],
                autofocus: index == 0,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFEFEBE6),
                  hintText: '-',
                  hintStyle: const TextStyle(color: Colors.black26),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primaryBrown, width: 1.5),
                  ),
                ),
                onChanged: (value) => _onOtpChanged(index, value),
                onTap: () => _otpCtrs[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _otpCtrs[index].text.length,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Verify OTP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code?",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            TextButton(
              onPressed: _isResending ? null : _resendOtp,
              child: _isResending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryBrown,
                      ),
                    )
                  : Text(
                      'Resend OTP',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 3: New Password Form ---
  Widget _buildStep3NewPassword(Color primaryBrown) {
    const lightInputFill = Color(0xFFEFEBE6);

    return Form(
      key: _formKeyPassword,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Password',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordCtr,
            obscureText: _obscureNewPassword,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.black38,
                fontSize: 15,
              ),
              filled: true,
              fillColor: lightInputFill,
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.black45,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBrown, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a new password';
              }
              if (val.trim().length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm New Password',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordCtr,
            obscureText: _obscureConfirmPassword,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.black38,
                fontSize: 15,
              ),
              filled: true,
              fillColor: lightInputFill,
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.black45,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBrown, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please confirm your new password';
              }
              if (val.trim() != _newPasswordCtr.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBrown,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Reset Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 4: Success Screen ---
  Widget _buildStep4Success(Color primaryBrown) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 64,
          color: Color(0xFF2E7D32),
        ),
        const SizedBox(height: 16),
        Text(
          'Password Reset Done!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been changed successfully. You can now log in using your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.5,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Go to Login',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
