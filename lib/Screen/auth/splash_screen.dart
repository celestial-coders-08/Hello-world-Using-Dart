import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/pawstay_theme.dart';
import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ──────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _pawsCtrl;
  late final AnimationController _bgCtrl;

  // ── Animations ─────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  final List<_FloatingPaw> _paws = [];

  @override
  void initState() {
    super.initState();
    _buildPaws();

    // Logo scale + fade (0 → 600 ms)
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Brand text slides up (delay 400 ms, duration 500 ms)
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Tagline fades (delay 750 ms, duration 500 ms)
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));

    // Floating paw prints loop
    _pawsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Background gradient shift
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _runSequence();
  }

  void _buildPaws() {
    final rng = Random();
    for (int i = 0; i < 8; i++) {
      _paws.add(
        _FloatingPaw(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          size: 18.0 + rng.nextDouble() * 20,
          speed: 0.3 + rng.nextDouble() * 0.7,
          phase: rng.nextDouble(),
          opacity: 0.04 + rng.nextDouble() * 0.08,
        ),
      );
    }
  }

  Future<void> _runSequence() async {
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    _taglineCtrl.forward();
    // Navigate after splash hold
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, sa) => const LoginScreen(),
          transitionsBuilder: (c, a, sa, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _pawsCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoCtrl,
          _textCtrl,
          _taglineCtrl,
          _pawsCtrl,
          _bgCtrl,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Animated background gradient ──────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFFFFF8F4),
                        const Color(0xFFFFEDE3),
                        _bgCtrl.value,
                      )!,
                      Color.lerp(
                        const Color(0xFFF6ECE5),
                        const Color(0xFFFFD6BE),
                        _bgCtrl.value * 0.6,
                      )!,
                    ],
                  ),
                ),
              ),

              // ── Floating paw prints ───────────────────────────────────
              ..._paws.map((paw) {
                final t = (_pawsCtrl.value + paw.phase) % 1.0;
                final yOffset = -t * size.height * paw.speed;
                return Positioned(
                  left: paw.x * size.width,
                  top: paw.y * size.height + yOffset,
                  child: Opacity(
                    opacity: paw.opacity * (1.0 - t * 0.5),
                    child: Transform.rotate(
                      angle: paw.x * 2 * pi,
                      child: Icon(
                        Icons.pets,
                        size: paw.size,
                        color: PawStayTheme.primary,
                      ),
                    ),
                  ),
                );
              }),

              // ── Decorative circles ────────────────────────────────────
              Positioned(
                top: -size.height * 0.08,
                right: -size.width * 0.15,
                child: Container(
                  width: size.width * 0.55,
                  height: size.width * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PawStayTheme.primaryContainer.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.1,
                left: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PawStayTheme.secondary.withValues(alpha: 0.06),
                  ),
                ),
              ),

              // ── Centre content ────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo paw icon
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PawStayTheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: PawStayTheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Brand name
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Text(
                          'PawStay',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: PawStayTheme.primary,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tagline
                    SlideTransition(
                      position: _taglineSlide,
                      child: FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'Care, comfort & love for your pet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: PawStayTheme.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Loading dots at bottom ──────────────────────────────────
              Positioned(
                bottom: 56,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _taglineFade,
                  child: _LoadingDots(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Loading dots widget
// ──────────────────────────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final bounce = sin(phase * pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, -6 * bounce),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PawStayTheme.primary.withValues(
                      alpha: 0.35 + 0.65 * bounce,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Data class for floating paw prints
// ──────────────────────────────────────────────────────────────────────────

class _FloatingPaw {
  final double x, y, size, speed, phase, opacity;
  const _FloatingPaw({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
  });
}
