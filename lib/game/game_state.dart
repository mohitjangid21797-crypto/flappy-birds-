import 'dart:ui';

enum GamePhase {
  ready,
  playing,
  paused,
  dying,
  gameOver,
}

enum MedalTier {
  none('NONE'),
  bronze('BRONZE'),
  silver('SILVER'),
  gold('GOLD'),
  platinum('PLATINUM');

  const MedalTier(this.label);
  final String label;

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
    required this.gapCenterY,
    required this.gapHeight,
    this.passed = false,
  });

  double x;
  double gapCenterY;
  double gapHeight;
  bool passed;

  double get topPipeBottom => gapCenterY - gapHeight / 2;
  double get bottomPipeTop => gapCenterY + gapHeight / 2;
}

class NightStar {
  const NightStar({
    required this.nx,
    required this.ny,
    required this.size,
    required this.color,
    required this.isSparkle,
    required this.phase,
  });

  final double nx;
  final double ny;
  final double size;
  final Color color;
  final bool isSparkle;
  final double phase;
}

class GhostSprite {
  GhostSprite({
    required this.x,
    required this.baseY,
    required this.scale,
    required this.phase,
    required this.speedFactor,
  });

  double x;
  double baseY;
  final double scale;
  double phase;
  final double speedFactor;
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
  });

  double x;
  double y;
  double vx;
  double vy;
  double size;
  double life;
  final double maxLife;
  final Color color;

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}
