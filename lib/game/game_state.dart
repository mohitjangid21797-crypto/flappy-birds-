import 'dart:math' as math;
import 'dart:ui';

import 'game_config.dart';

enum GamePhase {
  ready,
  playing,
  paused,
  dying,
  gameOver,
}

enum MedalTier {
  none,
  bronze,
  silver,
  gold,
  platinum,
}

extension MedalTierConfig on MedalTier {
  String get label => switch (this) {
        MedalTier.none => 'NONE',
        MedalTier.bronze => 'BRONZE',
        MedalTier.silver => 'SILVER',
        MedalTier.gold => 'GOLD',
        MedalTier.platinum => 'PLATINUM',
      };

  static MedalTier fromScore(int score) {
    if (score >= 40) return MedalTier.platinum;
    if (score >= 30) return MedalTier.gold;
    if (score >= 20) return MedalTier.silver;
    if (score >= 10) return MedalTier.bronze;
    return MedalTier.none;
  }
}

class PipePair {
  PipePair({
    required this.x,
    required this.baseGapCenterY,
    required this.gapHeight,
    required this.kind,
    required this.hoverAmplitude,
    required this.hoverSpeed,
    required this.phase,
    this.passed = false,
  });

  double x;
  double baseGapCenterY;
  double gapHeight;
  final ObstacleKind kind;
  final double hoverAmplitude;
  final double hoverSpeed;
  final double phase;
  bool passed;

  double currentGapCenterY(double elapsedTime) {
    if (hoverAmplitude <= 0.01) return baseGapCenterY;
    return baseGapCenterY +
        math.sin(elapsedTime * hoverSpeed + phase) * hoverAmplitude;
  }

  double topPipeBottomAt(double elapsedTime) =>
      currentGapCenterY(elapsedTime) - gapHeight / 2;

  double bottomPipeTopAt(double elapsedTime) =>
      currentGapCenterY(elapsedTime) + gapHeight / 2;
}

class HeartPickup {
  HeartPickup({
    required this.x,
    required this.baseY,
    required this.phase,
    this.collected = false,
  });

  double x;
  double baseY;
  final double phase;
  bool collected;
}

class SkyCloud {
  SkyCloud({
    required this.x,
    required this.y,
    required this.scale,
    required this.speedFactor,
  });

  double x;
  double y;
  final double scale;
  final double speedFactor;
}

class FloatingFeedback {
  FloatingFeedback({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.life,
    required this.maxLife,
  });

  double x;
  double y;
  final String text;
  final Color color;
  double life;
  final double maxLife;

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}

enum ParticleKind {
  burst,
  trail,
  feather,
}

class FlapParticle {
  FlapParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.maxLife,
    required this.color,
    this.kind = ParticleKind.burst,
    this.gravity = 320.0,
    this.drag = 0.0,
    this.rotation = 0.0,
    this.spin = 0.0,
  });

  double x;
  double y;
  double vx;
  double vy;
  double size;
  double life;
  final double maxLife;
  final Color color;
  final ParticleKind kind;
  final double gravity;
  final double drag;
  double rotation;
  final double spin;

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}
