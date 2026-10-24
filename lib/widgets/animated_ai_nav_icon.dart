import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Native Flutter version of the animated sparkle artwork in animated_svg.html.
/// It avoids creating a WebView for every bottom navigation bar.
class AnimatedAiNavIcon extends StatefulWidget {
  const AnimatedAiNavIcon({super.key});

  @override
  State<AnimatedAiNavIcon> createState() => _AnimatedAiNavIconState();
}

class _AnimatedAiNavIconState extends State<AnimatedAiNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: const Size.square(28),
          painter: _AiSparklePainter(_controller.value),
        ),
      ),
    );
  }
}

class _AiSparklePainter extends CustomPainter {
  const _AiSparklePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    canvas.scale(scale, scale);

    final auraPulse = 0.85 + math.sin(progress * math.pi * 2) * 0.15;
    final aura = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: .92),
          const Color(0xFFEC4899).withValues(alpha: .55),
          const Color(0xFF3B82F6).withValues(alpha: .30),
          Colors.transparent,
        ],
        stops: const [0, .35, .7, 1],
      ).createShader(Rect.fromCircle(center: const Offset(60, 60), radius: 50));
    canvas.save();
    canvas.translate(60, 60);
    canvas.scale(auraPulse);
    canvas.translate(-60, -60);
    canvas.drawCircle(const Offset(60, 60), 50, aura);
    canvas.restore();

    _drawSparkle(
      canvas,
      center: const Offset(46, 60),
      radius: 80,
      offset: Offset(0, 10 * math.sin(progress * math.pi * 2)),
      scale: 0.92 + 0.12 * math.sin(progress * math.pi * 2),
      primary: const [Color(0xFF2563EB), Color(0xFF8B5CF6), Color(0xFFEC4899)],
      highlightRadius: 56,
      coreRadius: 4,
    );
    _drawSparkle(
      canvas,
      center: const Offset(82, 28),
      radius: 36,
      offset: Offset(0, 7 * math.sin((progress - .1) * math.pi * 2)),
      scale: 0.92 + 0.12 * math.sin((progress - .1) * math.pi * 2),
      primary: const [Color(0xFFF43F5E), Color(0xFFD946EF), Color(0xFF38BDF8)],
      highlightRadius: 22,
      coreRadius: 2.5,
    );
    _drawSparkle(
      canvas,
      center: const Offset(84, 84),
      radius: 36,
      offset: Offset(0, 7 * math.sin((progress - .2) * math.pi * 2)),
      scale: 0.92 + 0.12 * math.sin((progress - .2) * math.pi * 2),
      primary: const [Color(0xFF2563EB), Color(0xFF8B5CF6), Color(0xFFEC4899)],
      highlightRadius: 22,
      coreRadius: 2.5,
    );
  }

  void _drawSparkle(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Offset offset,
    required double scale,
    required List<Color> primary,
    required double highlightRadius,
    required double coreRadius,
  }) {
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    final bounds = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );
    canvas.drawPath(
      _sparklePath(center, radius),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: primary,
        ).createShader(bounds),
    );
    canvas.drawPath(
      _sparklePath(center, highlightRadius),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFDF2F8), Color(0xFFE0F2FE)],
        ).createShader(bounds),
    );
    canvas.drawCircle(center, coreRadius, Paint()..color = Colors.white);
    canvas.restore();
  }

  Path _sparklePath(Offset center, double radius) {
    final half = radius / 2;
    final horizontalHalf = half * .8;
    return Path()
      ..moveTo(center.dx, center.dy - half)
      ..cubicTo(center.dx, center.dy - half * .45, center.dx - half * .55,
          center.dy, center.dx - horizontalHalf, center.dy)
      ..cubicTo(center.dx - half * .55, center.dy, center.dx,
          center.dy + half * .45, center.dx, center.dy + half)
      ..cubicTo(center.dx, center.dy + half * .45, center.dx + half * .55,
          center.dy, center.dx + horizontalHalf, center.dy)
      ..cubicTo(center.dx + half * .55, center.dy, center.dx,
          center.dy - half * .45, center.dx, center.dy - half)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _AiSparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
