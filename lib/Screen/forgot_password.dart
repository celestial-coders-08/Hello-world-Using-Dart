import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../theme/pawstay_theme.dart';
import 'login.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: Enter Email+Phone, 2: Enter OTP, 3: Reset Password

  final _emailCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _otpCtr = TextEditingController();
  final _newPasswordCtr = TextEditingController();
  final _confirmPasswordCtr = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailCtr.dispose();
    _phoneCtr.dispose();
    _otpCtr.dispose();
    _newPasswordCtr.dispose();
    _confirmPasswordCtr.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
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

  // ── Step 1: Request OTP ──────────────────────────────────────────────────
  Future<void> _requestOtp() async {
    final email = _emailCtr.text.trim();
    final phone = _phoneCtr.text.trim();

    if (email.isEmpty || phone.isEmpty) {
      _showSnackBar('Please enter both Email and Phone Number.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = jsonEncode({'email': email, 'phone_number': phone});
      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _showSnackBar(data['message'] ?? 'OTP code sent!');
        setState(() => _step = 2);
      } else {
        _showSnackBar(data['detail'] ?? 'Failed to send OTP.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Step 2: Validate OTP locally and move to password input ─────────────
  void _verifyOtpStep() {
    final otp = _otpCtr.text.trim();
    if (otp.length < 4) {
      _showSnackBar(
        'Please enter the 4-digit verification code.',
        isError: true,
      );
      return;
    }
    setState(() => _step = 3);
  }

  // ── Step 3: Reset Password ───────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final newPassword = _newPasswordCtr.text;
    final confirmPassword = _confirmPasswordCtr.text;

    if (newPassword.isEmpty || newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters.', isError: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = jsonEncode({
        'email': _emailCtr.text.trim(),
        'otp': _otpCtr.text.trim(),
        'new_password': newPassword,
      });

      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/reset-password'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        _showSnackBar(data['message'] ?? 'Password reset successfully!');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        _showSnackBar(
          data['detail'] ?? 'Password reset failed.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Connection error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PawStayTheme.primary),
          onPressed: () {
            if (_step > 1) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: PawStayTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
                border: Border.all(color: PawStayTheme.surfaceDim),
                boxShadow: PawStayTheme.ambientShadow1,
              ),
              padding: const EdgeInsets.all(PawStayTheme.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: PawStayTheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 40,
                            color: PawStayTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _step == 1
                              ? 'Forgot Password?'
                              : _step == 2
                              ? 'Enter OTP'
                              : 'Reset Password',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: PawStayTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _step == 1
                              ? 'Enter your registered Email & Phone Number to receive a reset OTP.'
                              : _step == 2
                              ? 'Enter the 4-digit code sent to ${_emailCtr.text}.'
                              : 'Create a new secure password for your account.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: PawStayTheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  if (_step == 1) ...[
                    // Email
                    Text(
                      'Email',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtr,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'jane@example.com',
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          color: PawStayTheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    Text(
                      'Phone Number',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneCtr,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+91 9876543210',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: PawStayTheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Send Verification Code',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ] else if (_step == 2) ...[
                    // OTP Input
                    Text(
                      '4-Digit Verification Code',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _otpCtr,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0000',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.pin_outlined,
                          color: PawStayTheme.outlineVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _verifyOtpStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Verify Code',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // New Password
                    Text(
                      'New Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPasswordCtr,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: PawStayTheme.outlineVariant,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm New Password
                    Text(
                      'Confirm New Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordCtr,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: PawStayTheme.outlineVariant,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PawStayTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Reset Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
