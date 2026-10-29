import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/pawstay_theme.dart';

// ---------------------------------------------------------------------------
// ConnectivityWrapper
//
// Wraps the entire app tree. When no internet connection is detected it
// overlays the cute offline screen. When connectivity is restored the child
// (normal app content) reappears automatically.
//
// Usage — in MaterialApp's builder:
//   builder: (context, child) {
//     return ConnectivityWrapper(child: child ?? const SizedBox.shrink());
//   },
// ---------------------------------------------------------------------------

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOnline = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Check immediately, then poll every 3 seconds.
    _checkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnectivity();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Tries to open a TCP socket to a reliable host.
  /// Works on Android, iOS, Windows, and macOS — no extra package required.
  Future<void> _checkConnectivity() async {
    bool online = false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    if (mounted && online != _isOnline) {
      setState(() => _isOnline = online);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isOnline) const _NoNetworkOverlay(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _NoNetworkOverlay — the cute offline screen drawn on top of everything.
// ---------------------------------------------------------------------------

class _NoNetworkOverlay extends StatefulWidget {
  const _NoNetworkOverlay();

  @override
  State<_NoNetworkOverlay> createState() => _NoNetworkOverlayState();
}

class _NoNetworkOverlayState extends State<_NoNetworkOverlay>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _bounceAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -14).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _waveAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_waveCtrl);
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _fadeCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: PawStayTheme.primary.withValues(alpha: 0.03),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFF8F4),
                const Color(0xFFFCEDE3),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Animated Puppy Illustration ──────────────────────────
                AnimatedBuilder(
                  animation: _bounceAnim,
                  builder: (context, _) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnim.value),
                      child: _PuppyIllustration(waveAnim: _waveAnim),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // ── Animated WiFi Off Icon ────────────────────────────────
                _PulsingWifiOff(),

                const SizedBox(height: 28),

                // ── Main Message ──────────────────────────────────────────
                Text(
                  'You are Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: PawStayTheme.primary,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Please check your internet connection.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF88726C),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Status Pill ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: PawStayTheme.errorContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: PawStayTheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No Internet Connection',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PawStayTheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // ── Footer pawprint dots ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: PawStayTheme.primary.withValues(
                            alpha: 0.15 + i * 0.12,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PuppyIllustration — custom-drawn puppy face using CustomPaint
// ---------------------------------------------------------------------------

class _PuppyIllustration extends StatelessWidget {
  final Animation<double> waveAnim;
  const _PuppyIllustration({required this.waveAnim});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft background glow circle
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PawStayTheme.primaryContainer.withValues(alpha: 0.25),
                  PawStayTheme.primaryContainer.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          // The puppy drawn with CustomPaint
          CustomPaint(
            size: const Size(190, 190),
            painter: _PuppyPainter(),
          ),
          // Small animated WiFi-slash badge on the puppy
          Positioned(
            bottom: 18,
            right: 18,
            child: AnimatedBuilder(
              animation: waveAnim,
              builder: (_, __) {
                final scale = 1.0 + 0.08 * math.sin(waveAnim.value);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: PawStayTheme.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PawStayTheme.error.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PuppyPainter — draws a cartoon puppy face with Canvas APIs
// ---------------------------------------------------------------------------

class _PuppyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final furColor = const Color(0xFFD97757);      // Terracotta warm
    final darkFurColor = const Color(0xFF8B4513);  // Saddle brown
    final creamColor = const Color(0xFFFFF0E8);    // Cream muzzle
    final noseColor = const Color(0xFF3D2B1F);     // Near black
    final eyeColor = const Color(0xFF2C1810);      // Dark brown eye

    final basePaint = Paint()..style = PaintingStyle.fill;

    // ── 1. Floppy ears ───────────────────────────────────────────────────
    basePaint.color = darkFurColor;
    // Left ear
    final leftEarPath = Path()
      ..moveTo(cx - 54, cy - 44)
      ..quadraticBezierTo(cx - 88, cy - 76, cx - 66, cy + 14)
      ..quadraticBezierTo(cx - 46, cy - 10, cx - 38, cy - 38)
      ..close();
    canvas.drawPath(leftEarPath, basePaint);

    // Right ear
    final rightEarPath = Path()
      ..moveTo(cx + 54, cy - 44)
      ..quadraticBezierTo(cx + 88, cy - 76, cx + 66, cy + 14)
      ..quadraticBezierTo(cx + 46, cy - 10, cx + 38, cy - 38)
      ..close();
    canvas.drawPath(rightEarPath, basePaint);

    // Inner ear highlight
    basePaint.color = furColor.withValues(alpha: 0.55);
    final leftInnerEarPath = Path()
      ..moveTo(cx - 54, cy - 40)
      ..quadraticBezierTo(cx - 80, cy - 68, cx - 62, cy + 8)
      ..quadraticBezierTo(cx - 48, cy - 8, cx - 42, cy - 36)
      ..close();
    canvas.drawPath(leftInnerEarPath, basePaint);

    final rightInnerEarPath = Path()
      ..moveTo(cx + 54, cy - 40)
      ..quadraticBezierTo(cx + 80, cy - 68, cx + 62, cy + 8)
      ..quadraticBezierTo(cx + 48, cy - 8, cx + 42, cy - 36)
      ..close();
    canvas.drawPath(rightInnerEarPath, basePaint);

    // ── 2. Head ───────────────────────────────────────────────────────────
    basePaint.color = furColor;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 10), width: 128, height: 116),
      basePaint,
    );

    // ── 3. Muzzle ─────────────────────────────────────────────────────────
    basePaint.color = creamColor;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 22), width: 64, height: 46),
      basePaint,
    );

    // ── 4. Eyes ───────────────────────────────────────────────────────────
    // Eye whites
    basePaint.color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 24, cy - 10), width: 28, height: 26),
      basePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 24, cy - 10), width: 28, height: 26),
      basePaint,
    );

    // Eye irises (big, sad-looking)
    basePaint.color = eyeColor;
    canvas.drawCircle(Offset(cx - 24, cy - 8), 10, basePaint);
    canvas.drawCircle(Offset(cx + 24, cy - 8), 10, basePaint);

    // Eye pupils shine
    basePaint.color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(cx - 20, cy - 12), 3.5, basePaint);
    canvas.drawCircle(Offset(cx + 28, cy - 12), 3.5, basePaint);

    // Sad curved eyebrows
    final browPaint = Paint()
      ..color = darkFurColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leftBrow = Path()
      ..moveTo(cx - 36, cy - 24)
      ..quadraticBezierTo(cx - 24, cy - 30, cx - 14, cy - 22);
    canvas.drawPath(leftBrow, browPaint);

    final rightBrow = Path()
      ..moveTo(cx + 14, cy - 22)
      ..quadraticBezierTo(cx + 24, cy - 30, cx + 36, cy - 24);
    canvas.drawPath(rightBrow, browPaint);

    // ── 5. Nose ───────────────────────────────────────────────────────────
    basePaint.color = noseColor;
    final nosePath = Path()
      ..moveTo(cx, cy + 6)
      ..quadraticBezierTo(cx - 13, cy + 6, cx - 13, cy + 13)
      ..quadraticBezierTo(cx - 13, cy + 19, cx, cy + 19)
      ..quadraticBezierTo(cx + 13, cy + 19, cx + 13, cy + 13)
      ..quadraticBezierTo(cx + 13, cy + 6, cx, cy + 6)
      ..close();
    canvas.drawPath(nosePath, basePaint);

    // Nose shine
    basePaint.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(cx - 5, cy + 9), 3, basePaint);

    // ── 6. Sad mouth ──────────────────────────────────────────────────────
    final mouthPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Centre line down from nose
    final mouthCenterPath = Path()
      ..moveTo(cx, cy + 19)
      ..lineTo(cx, cy + 27);
    canvas.drawPath(mouthCenterPath, mouthPaint);

    // Sad down-turned curves
    final leftMouthPath = Path()
      ..moveTo(cx, cy + 27)
      ..quadraticBezierTo(cx - 10, cy + 27, cx - 14, cy + 34);
    canvas.drawPath(leftMouthPath, mouthPaint);

    final rightMouthPath = Path()
      ..moveTo(cx, cy + 27)
      ..quadraticBezierTo(cx + 10, cy + 27, cx + 14, cy + 34);
    canvas.drawPath(rightMouthPath, mouthPaint);

    // ── 7. Forehead patch ─────────────────────────────────────────────────
    basePaint.color = darkFurColor.withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 40), width: 30, height: 18),
      basePaint,
    );

    // ── 8. Tear drops (sad puppy eyes 🥺) ────────────────────────────────
    basePaint.color = const Color(0xFF9BB8E8).withValues(alpha: 0.65);
    // Left tear
    final leftTearPath = Path()
      ..moveTo(cx - 28, cy + 6)
      ..quadraticBezierTo(cx - 25, cy + 12, cx - 28, cy + 18)
      ..quadraticBezierTo(cx - 31, cy + 12, cx - 28, cy + 6)
      ..close();
    canvas.drawPath(leftTearPath, basePaint);

    // Right tear
    final rightTearPath = Path()
      ..moveTo(cx + 28, cy + 6)
      ..quadraticBezierTo(cx + 31, cy + 12, cx + 28, cy + 18)
      ..quadraticBezierTo(cx + 25, cy + 12, cx + 28, cy + 6)
      ..close();
    canvas.drawPath(rightTearPath, basePaint);

    // ── 9. Small paw print below ──────────────────────────────────────────
    _drawPawPrint(canvas, Offset(cx - 50, cy + 68), 7, furColor.withValues(alpha: 0.5));
    _drawPawPrint(canvas, Offset(cx + 50, cy + 68), 7, furColor.withValues(alpha: 0.5));
  }

  void _drawPawPrint(Canvas canvas, Offset center, double r, Color color) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    // Main pad
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 2.2, height: r * 1.6),
      p,
    );
    // Toe pads
    final toePositions = [
      Offset(center.dx - r * 0.9, center.dy - r * 1.0),
      Offset(center.dx - r * 0.3, center.dy - r * 1.3),
      Offset(center.dx + r * 0.3, center.dy - r * 1.3),
      Offset(center.dx + r * 0.9, center.dy - r * 1.0),
    ];
    for (final pos in toePositions) {
      canvas.drawCircle(pos, r * 0.42, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// _PulsingWifiOff — animated pulsing Wi-Fi off icon
// ---------------------------------------------------------------------------

class _PulsingWifiOff extends StatefulWidget {
  @override
  State<_PulsingWifiOff> createState() => _PulsingWifiOffState();
}

class _PulsingWifiOffState extends State<_PulsingWifiOff>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PawStayTheme.errorContainer,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PawStayTheme.error.withValues(alpha: 0.15 * _pulse.value),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.wifi_off_rounded,
            size: 38,
            color: PawStayTheme.error,
          ),
        ),
      ),
    );
  }
}

