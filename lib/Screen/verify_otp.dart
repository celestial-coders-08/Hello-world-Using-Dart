import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../theme/pawstay_theme.dart';
import 'home.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const VerifyOtpScreen({super.key, required this.email, this.fullName = ''});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;

  String get _normalizedEmail => widget.email.trim().toLowerCase();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _otpCode =>
      _controllers.map((controller) => controller.text).join();

  Future<http.Response> _postWithFallback(
    String path,
    String body, {
    Duration primaryTimeout = const Duration(seconds: 10),
  }) async {
    return await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(primaryTimeout);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      final characters = value.split('');
      for (int i = 0; i < _controllers.length; i++) {
        _controllers[i].text = i < characters.length ? characters[i] : '';
      }
      _focusNodes[_controllers.length - 1].requestFocus();
      return;
    }

    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 4) {
      _showSnack('Please enter the 4-digit OTP.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await _postWithFallback(
        '/verify-otp',
        jsonEncode({'email': _normalizedEmail, 'otp': _otpCode}),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        _showSnack('Email verified successfully.');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) {
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(userLookup: _normalizedEmail),
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      _showSnack(
        decoded['detail']?.toString() ?? 'OTP verification failed.',
        isError: true,
      );
    } on TimeoutException {
      _showSnack(
        'Request timed out. Check if the backend is running.',
        isError: true,
      );
    } catch (_) {
      _showSnack('Could not connect to server.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending) {
      return;
    }

    setState(() => _isResending = true);

    try {
      final response = await _postWithFallback(
        '/resend-otp',
        jsonEncode({'email': _normalizedEmail}),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes.first.requestFocus();
        _showSnack('A new OTP has been sent to your email.');
        return;
      }

      final decoded = jsonDecode(response.body);
      _showSnack(
        decoded['detail']?.toString() ?? 'Failed to resend OTP.',
        isError: true,
      );
    } on TimeoutException {
      _showSnack('Request timed out.', isError: true);
    } catch (_) {
      _showSnack('Could not connect to server.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 62,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: PawStayTheme.onSurface,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: PawStayTheme.surfaceContainerLow,
          hintText: '-',
          hintStyle: const TextStyle(color: PawStayTheme.outlineVariant),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PawStayTheme.radiusMd),
            borderSide: const BorderSide(color: PawStayTheme.primary, width: 2),
          ),
        ),
        onChanged: (value) => _onOtpChanged(index, value),
        onTap: () => _controllers[index].selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controllers[index].text.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedFullName = widget.fullName.trim();
    final firstName = trimmedFullName.isEmpty
        ? ''
        : trimmedFullName.split(' ').first;

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: PawStayTheme.onSurface),
        title: Text(
          'OTP Verification',
          style: GoogleFonts.plusJakartaSans(
            color: PawStayTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PawStayTheme.marginMobile),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(PawStayTheme.gutter),
              decoration: BoxDecoration(
                color: PawStayTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
                border: Border.all(color: PawStayTheme.surfaceDim),
                boxShadow: PawStayTheme.ambientShadow1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: PawStayTheme.surfaceContainer,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: PawStayTheme.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verify your email',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: PawStayTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    firstName.isEmpty
                        ? 'Enter the 4-digit OTP sent to ${widget.email}.'
                        : 'Hi $firstName, enter the 4-digit OTP sent to ${widget.email.trim()}.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: PawStayTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, _buildOtpBox),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PawStayTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PawStayTheme.radiusMd,
                          ),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Verify OTP',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Didn't receive the code?",
                    style: GoogleFonts.plusJakartaSans(
                      color: PawStayTheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: _isResending ? null : _resendOtp,
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PawStayTheme.primary,
                            ),
                          )
                        : Text(
                            'Resend OTP',
                            style: GoogleFonts.plusJakartaSans(
                              color: PawStayTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
