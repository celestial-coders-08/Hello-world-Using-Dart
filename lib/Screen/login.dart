import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/pawstay_theme.dart';
import '../config/api_config.dart';
import 'signup.dart';
import 'home.dart';
import 'verify_otp.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  // Animation controller for scale-bounce of primary button
  late AnimationController _buttonScaleController;

  @override
  void initState() {
    super.initState();
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _buttonScaleController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
        ),
        backgroundColor: isError ? PawStayTheme.error : PawStayTheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _onLoginPressed() async {
    _buttonScaleController.reverse().then(
      (_) => _buttonScaleController.forward(),
    );

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final body = jsonEncode({
        'email_or_username': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/login'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        _showSnack(decoded['message'] ?? 'Login successful!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomeScreen(userLookup: _emailController.text.trim()),
          ),
        );
      } else {
        final decoded = jsonDecode(response.body);
        final detail =
            decoded['detail'] ?? 'Login failed. Please check credentials.';
        _showSnack(detail, isError: true);

        if (response.statusCode == 403 ||
            detail.toString().toLowerCase().contains('unverified')) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VerifyOtpScreen(email: _emailController.text.trim()),
            ),
          );
        }
      }
    } on TimeoutException {
      _showSnack('Connection timed out. Is backend running?', isError: true);
    } catch (_) {
      _showSnack('Could not connect to server.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: PawStayTheme.background,
      body: Stack(
        children: [
          // Background Gradient Circles for Visual Aesthetics (Tailwind floating blur equivalent)
          Positioned(
            top: -size.height * 0.1,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PawStayTheme.primaryContainer.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.15,
            right: -size.width * 0.15,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PawStayTheme.secondaryContainer.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Central container layout
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: PawStayTheme.marginMobile,
              ),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: PawStayTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(PawStayTheme.radiusLg),
                  border: Border.all(
                    color: PawStayTheme.surfaceDim,
                    width: 1.0,
                  ),
                  boxShadow: PawStayTheme.ambientShadow2,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: PawStayTheme.gutter,
                  vertical: PawStayTheme.gutter * 1.5,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Logo Area
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PawStayTheme.surfaceContainer,
                          boxShadow: PawStayTheme.ambientShadow1,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuA8RJj9f4EnjA7BkNpLbCt4PE2gsE1KeDTKGfAdta4sgEMGLs19XUGa9udNcJapsAbk55Py4XhgHk_BkisgvgZ_BuwnAIx1YQzQpNgKT_0kMXn7N5WUgFH5oZ1ykBsZ4EWgixeYfFtOcrrCRIRdcKTvS8TaQ3mELnS9yL-AbzTpjPWp5Ger5lAlu9P14zzj1i4hTt-Z3xr9JOLdvkUjajISxSNgqFuDwRcQSuTyxHibaFnsZteK_EM7',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.pets,
                                color: PawStayTheme.primary,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'PawStay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: PawStayTheme.primary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Welcome back! Please login to continue.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: PawStayTheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Email input field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PawStayTheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: PawStayTheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter your email',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                color: PawStayTheme.outlineVariant,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(val)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Password input field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: PawStayTheme.onSurface,
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Forgot password functionality is coming soon!',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: PawStayTheme.primary,
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: PawStayTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: PawStayTheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: PawStayTheme.outlineVariant,
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Login button with press bounce
                      ScaleTransition(
                        scale: _buttonScaleController,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onLoginPressed,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: PawStayTheme.primary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  PawStayTheme.radiusDefault,
                                ),
                              ),
                              shadowColor: PawStayTheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            child: _isLoading
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
                                    'Login',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Navigation check
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: PawStayTheme.onSurfaceVariant,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, a, sa) =>
                                      const SignupScreen(),
                                  transitionsBuilder: (context, a, sa, child) =>
                                      FadeTransition(opacity: a, child: child),
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'Sign up',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: PawStayTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
