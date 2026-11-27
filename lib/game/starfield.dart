import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

enum _StarLayer { far, mid }

enum _StarTint { white, cool, warm }

class _StarSpec {
  const _StarSpec({
    required this.seedX,
    required this.seedY,
    required this.radius,
    required this.twinkleSpeed,
    required this.phase,
    required this.layer,
    required this.tint,
  });

  final double seedX;
  final double seedY;
  final double radius;
  final double twinkleSpeed;
  final double phase;
  final _StarLayer layer;
  final _StarTint tint;
}

class Starfield {
  Starfield({int farCount = 46, int midCount = 20})
      : _stars = _generateStars(farCount, midCount);

  static const double _farParallax = 0.024;
  static const double _midParallax = 0.048;

  final List<_StarSpec> _stars;

  static List<_StarSpec> _generateStars(int farCount, int midCount) {
    final List<_StarSpec> items = <_StarSpec>[];
    for (int i = 0; i < farCount; i++) {
      final _StarTint tint = i % 4 == 0
          ? _StarTint.warm
          : (i % 3 == 0 ? _StarTint.cool : _StarTint.white);
      items.add(
        _StarSpec(
          seedX: (i * 0.6180339887 + 0.07) % 1.0,
          seedY: (i * 0.3819660113 + 0.11) % 1.0,
          radius: 1.0 + (i % 3) * 0.45,
          twinkleSpeed: 2.8 + (i % 5) * 0.7,
          phase: i * 1.73,
          layer: _StarLayer.far,
          tint: tint,
        ),
      );
    }

    for (int i = 0; i < midCount; i++) {
      final _StarTint tint = i % 3 == 0
          ? _StarTint.cool
          : (i.isEven ? _StarTint.white : _StarTint.warm);
      items.add(
        _StarSpec(
          seedX: (i * 0.7548776662 + 0.23) % 1.0,
          seedY: (i * 0.569840291 + 0.05) % 1.0,
          radius: 3.1 + (i % 3) * 0.95,
          twinkleSpeed: 3.6 + (i % 4) * 0.9,
          phase: i * 2.47,
          layer: _StarLayer.mid,
          tint: tint,
        ),
      );
    }

    return List<_StarSpec>.unmodifiable(items);
  }

  void paint(
    Canvas canvas,
    Size size,
    double groundTop,
    double elapsedTime,
    double worldScroll, {
    double intensity = 1.0,
  }) {
    if (groundTop <= 80.0 || intensity <= 0.01) return;

    final double starBandHeight = groundTop * 0.80;
    final double span = size.width + 60.0;

    for (final _StarSpec star in _stars) {
      final bool isFar = star.layer == _StarLayer.far;
      final double parallax = isFar ? _farParallax : _midParallax;
      final double drift = isFar ? 1.4 : 2.6;
      final double rawX =
          star.seedX * span - (worldScroll * parallax + elapsedTime * drift);
      final double x = (((rawX % span) + span) % span) - 30.0;
      final double y =
          12.0 + star.seedY * (starBandHeight * (isFar ? 0.88 : 0.78));
      final double altFade =
          math.max(0.22, 1.0 - (y / starBandHeight) * 0.68) * intensity;

      final double primaryWave =
          0.5 + 0.5 * math.sin(elapsedTime * star.twinkleSpeed + star.phase);
      final double shimmerWave = 0.5 +
          0.5 *
              math.sin(
                elapsedTime * star.twinkleSpeed * 1.9 + star.phase * 1.4,
              );

      if (isFar) {
        final double flicker = 0.28 +
            0.72 *
                math.pow(primaryWave * 0.7 + shimmerWave * 0.3, 1.35).toDouble();
        final double alpha = math.min(0.96, (0.36 + flicker * 0.62) * altFade);
        if (alpha <= 0.02) continue;

        final double r = star.radius * (0.85 + flicker * 0.3);
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()..color = _colorFor(star.tint, alpha),
        );
      } else {
        final double flicker =
            math.pow(primaryWave * 0.65 + shimmerWave * 0.35, 1.45).toDouble();
        final double alpha = math.min(0.98, (0.36 + flicker * 0.66) * altFade);
        if (alpha <= 0.02) continue;

        final double arm = star.radius + flicker * 1.8;
        final Rect haloRect =
            Rect.fromCircle(center: Offset(x, y), radius: arm * 2.5);
        canvas.drawCircle(
          Offset(x, y),
          arm * 2.5,
          Paint()
            ..shader = RadialGradient(
              colors: [
                _colorFor(star.tint, alpha * 0.72),
                _colorFor(star.tint, alpha * 0.25),
                const Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(haloRect),
        );

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(elapsedTime * 0.32 + star.phase);
        final double inner = arm * 0.24;
        final Path shape = Path()
          ..moveTo(0, -arm)
          ..quadraticBezierTo(inner, -inner, arm, 0)
          ..quadraticBezierTo(inner, inner, 0, arm)
          ..quadraticBezierTo(-inner, inner, -arm, 0)
          ..quadraticBezierTo(-inner, -inner, 0, -arm)
          ..close();

        canvas.drawPath(
          shape,
          Paint()..color = _colorFor(star.tint, alpha),
        );
        canvas.restore();
      }
    }
  }

  Color _colorFor(_StarTint tint, double alpha) {
    final double clamped = alpha.clamp(0.0, 1.0);
    switch (tint) {
      case _StarTint.warm:
        return const Color(0xFFFFEEB2).withValues(alpha: clamped);
      case _StarTint.cool:
        return const Color(0xFFB6E8FF).withValues(alpha: clamped);
      case _StarTint.white:
        return Colors.white.withValues(alpha: clamped);
    }
  }
}
