import 'dart:ui';

enum DifficultyMode {
  chill('Chill', 165.0, 178.0, 290.0),
  classic('Classic', 210.0, 150.0, 255.0),
  turbo('Turbo', 265.0, 136.0, 232.0);

  const DifficultyMode(
    this.label,
    this.pipeSpeed,
    this.pipeGap,
    this.pipeSpacing,
  );

  final String label;
  final double pipeSpeed;
  final double pipeGap;
  final double pipeSpacing;
}

class GameColors {
  static const Color skyTop = Color(0xFF162246);
  static const Color skyMid = Color(0xFF23396D);
  static const Color skyHorizon = Color(0xFF365794);

  static const Color cloudDark = Color(0xFF47679A);
  static const Color cloudLight = Color(0xFF5D80B6);

  static const Color cityBack = Color(0xFF2B4168);
  static const Color cityFront = Color(0xFF37517C);
  static const Color cityWindow = Color(0xFF4A699C);

  static const Color bushDark = Color(0xFF1F6623);
  static const Color bushMid = Color(0xFF2F8E2E);
  static const Color bushLight = Color(0xFF4AC03A);

  static const Color pipeBorder = Color(0xFF141414);
  static const Color pipeHighlightBright = Color(0xFFC2FF74);
  static const Color pipeHighlight = Color(0xFF9CE659);
  static const Color pipeMain = Color(0xFF73BF2E);
  static const Color pipeShadow = Color(0xFF558C22);
  static const Color pipeShadowDeep = Color(0xFF3B6615);

  static const Color groundBorder = Color(0xFF1B1B1B);
  static const Color grassLight = Color(0xFF9CE659);
  static const Color grassMain = Color(0xFF73BF2E);
  static const Color grassDark = Color(0xFF558C22);
  static const Color dirtLight = Color(0xFFE5DF9E);
  static const Color dirtMain = Color(0xFFDAD28B);
  static const Color dirtPebble = Color(0xFFC4B66A);

  static const Color birdOutline = Color(0xFF141414);
  static const Color birdHighlight = Color(0xFFFFEC70);
  static const Color birdYellow = Color(0xFFF8C61E);
  static const Color birdOrange = Color(0xFFE87818);
  static const Color birdBeakTop = Color(0xFFF43814);
  static const Color birdBeakBottom = Color(0xFFC81E0C);
  static const Color birdWing = Color(0xFFFFFDF2);
  static const Color birdWingShade = Color(0xFFE6DEC0);

  static const Color panelBg = Color(0xFFDED895);
  static const Color panelBorder = Color(0xFF543847);
  static const Color panelInner = Color(0xFFD0C67E);
  static const Color accentGold = Color(0xFFF8C61E);
  static const Color accentOrange = Color(0xFFE86101);
}

class GamePhysics {
  static const double gravity = 1480.0;
  static const double flapVelocity = -450.0;
  static const double maxFallSpeed = 620.0;
  static const double groundHeight = 76.0;
  static const double birdVisualWidth = 52.0;
  static const double birdVisualHeight = 38.0;
  static const double birdHitRadius = 15.5;
  static const double pipeWidth = 70.0;
  static const double pipeCapOverhang = 5.0;
  static const double pipeCapHeight = 28.0;
}
