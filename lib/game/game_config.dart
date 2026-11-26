import 'dart:ui';

enum GameMode {
  heartRun,
  classic,
  speedUp,
}

extension GameModeConfig on GameMode {
  String get label => switch (this) {
        GameMode.heartRun => 'Heart Run',
        GameMode.classic => 'Classic',
        GameMode.speedUp => 'Speed Up',
      };

  String get subtitle => switch (this) {
        GameMode.heartRun =>
          '3D moving gates & collectible hearts for extra shield lives',
        GameMode.classic => 'Pure 1-life arcade run through 3D sky pillars',
        GameMode.speedUp =>
          'Speed ramps up with every point + collectible shield hearts',
      };

  double get pipeSpeed => switch (this) {
        GameMode.heartRun => 215.0,
        GameMode.classic => 220.0,
        GameMode.speedUp => 210.0,
      };

  double get pipeGap => switch (this) {
        GameMode.heartRun => 156.0,
        GameMode.classic => 148.0,
        GameMode.speedUp => 152.0,
      };

  double get pipeSpacing => switch (this) {
        GameMode.heartRun => 268.0,
        GameMode.classic => 256.0,
        GameMode.speedUp => 262.0,
      };

  bool get heartsEnabled => switch (this) {
        GameMode.heartRun => true,
        GameMode.classic => false,
        GameMode.speedUp => true,
      };

  bool get accelerates => switch (this) {
        GameMode.heartRun => false,
        GameMode.classic => false,
        GameMode.speedUp => true,
      };
}

enum BirdSkin {
  skyCap,
  solarAce,
  emeraldJet,
}

extension BirdSkinConfig on BirdSkin {
  String get label => switch (this) {
        BirdSkin.skyCap => 'Sky Cap',
        BirdSkin.solarAce => 'Solar Ace',
        BirdSkin.emeraldJet => 'Emerald Jet',
      };

  Color get primaryLight => switch (this) {
        BirdSkin.skyCap => const Color(0xFFA8ECFF),
        BirdSkin.solarAce => const Color(0xFFFFF099),
        BirdSkin.emeraldJet => const Color(0xFFA7F3D0),
      };

  Color get primaryMid => switch (this) {
        BirdSkin.skyCap => const Color(0xFF42C2FA),
        BirdSkin.solarAce => const Color(0xFFF59E0B),
        BirdSkin.emeraldJet => const Color(0xFF10B981),
      };

  Color get primaryDark => switch (this) {
        BirdSkin.skyCap => const Color(0xFF177BB8),
        BirdSkin.solarAce => const Color(0xFFB45309),
        BirdSkin.emeraldJet => const Color(0xFF047857),
      };

  Color get hatCrown => switch (this) {
        BirdSkin.skyCap => const Color(0xFFA8703C),
        BirdSkin.solarAce => const Color(0xFF334155),
        BirdSkin.emeraldJet => const Color(0xFFB91C1C),
      };

  Color get hatShade => switch (this) {
        BirdSkin.skyCap => const Color(0xFF6B411C),
        BirdSkin.solarAce => const Color(0xFF1E293B),
        BirdSkin.emeraldJet => const Color(0xFF7F1D1D),
      };
}

enum ObstacleKind {
  emeraldCylinder,
  hoverPropellerGate,
  beaconTower,
}

class GameColors {
  // Daytime Pastel Sky & Hills
  static const Color skyTop = Color(0xFF56C8FA);
  static const Color skyMid = Color(0xFF9EE3FD);
  static const Color skyHorizon = Color(0xFFE5F8FF);

  static const Color sunCore = Color(0xFFFFF8BA);
  static const Color sunGlow = Color(0xFFFFE761);

  static const Color cloudHalo = Color(0xFFB8E6FA);
  static const Color cloudFill = Color(0xFFFFFFFF);

  static const Color hillBack = Color(0xFFFADDE6);
  static const Color hillFront = Color(0xFFF5C3D3);

  // 3D Obstacle Palettes
  static const Color pipeBorder = Color(0xFF1A2D0C);
  static const Color pipeDarkEdge = Color(0xFF2B4D12);
  static const Color pipeShadowLeft = Color(0xFF47721E);
  static const Color pipeMid = Color(0xFF7FB836);
  static const Color pipeSpecular = Color(0xFFDCFA8E);
  static const Color pipeShadowRight = Color(0xFF365915);

  static const Color gateBlueDark = Color(0xFF1D4ED8);
  static const Color gateBlueMid = Color(0xFF3B82F6);
  static const Color gateBlueLight = Color(0xFF93C5FD);
  static const Color gateGold = Color(0xFFFBBF24);
  static const Color gateGoldDark = Color(0xFFB45309);

  static const Color towerCoralDark = Color(0xFF9F1239);
  static const Color towerCoralMid = Color(0xFFE11D48);
  static const Color towerCoralLight = Color(0xFFFDA4AF);

  // Segmented Grass & Soil Tile Ground
  static const Color groundDivider = Color(0xFF1A140E);
  static const Color grassBright = Color(0xFF18CA00);
  static const Color grassShadow = Color(0xFF0A8F00);
  static const Color soilTop = Color(0xFF8C5D32);
  static const Color soilMid = Color(0xFFCFA774);
  static const Color soilBottom = Color(0xFF6B421D);
  static const Color soilPebble = Color(0xFF472A10);

  // Bird Common Accents
  static const Color birdOutline = Color(0xFF141820);
  static const Color birdBeakTop = Color(0xFFFFB424);
  static const Color birdBeakBottom = Color(0xFFE26800);
  static const Color hatBand = Color(0xFF281B12);

  // Collectible Heart
  static const Color heartBright = Color(0xFFFF8096);
  static const Color heartRed = Color(0xFFE5253A);
  static const Color heartDeep = Color(0xFF9E0F21);

  // UI & Score Palette
  static const Color scoreRed = Color(0xFFE53E3E);
  static const Color panelSurface = Color(0xFFFCFDFF);
  static const Color panelBorder = Color(0xFF1E3A5F);
  static const Color accentCoral = Color(0xFFE53E3E);
  static const Color accentCoralDark = Color(0xFFB91C1C);
  static const Color accentSky = Color(0xFF0EA5E9);
  static const Color accentSkyDark = Color(0xFF0369A1);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color brandNavy = Color(0xFF15325B);
}

class GamePhysics {
  static const double gravity = 1480.0;
  static const double flapVelocity = -455.0;
  static const double maxFallSpeed = 620.0;
  static const double groundHeight = 82.0;
  static const double birdVisualWidth = 58.0;
  static const double birdVisualHeight = 48.0;
  static const double birdHitRadius = 15.0;
  static const double pipeWidth = 72.0;
  static const double pipeCapOverhang = 6.0;
  static const double pipeCapHeight = 28.0;
  static const double obstacle3dDepth = 12.0;
  static const int maxHearts = 3;
}
