import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'game_config.dart';
import 'game_state.dart';

class FlappyScenePainter extends CustomPainter {
  FlappyScenePainter({
    required this.elapsedTime,
    required this.worldScroll,
    required this.birdX,
    required this.birdY,
    required this.birdAngle,
    required this.wingPhase,
    required this.flapSquash,
    required this.hatBounce,
    required this.birdSkin,
    required this.invulnTimer,
    required this.pipes,
    required this.hearts,
    required this.clouds,
    required this.particles,
    required this.feedbacks,
    required this.flashAlpha,
    required this.shakeOffset,
  });

  final double elapsedTime;
  final double worldScroll;
  final double birdX;
  final double birdY;
  final double birdAngle;
  final double wingPhase;
  final double flapSquash;
  final double hatBounce;
  final BirdSkin birdSkin;
  final double invulnTimer;
  final List<PipePair> pipes;
  final List<HeartPickup> hearts;
  final List<SkyCloud> clouds;
  final List<FlapParticle> particles;
  final List<FloatingFeedback> feedbacks;
  final double flashAlpha;
  final Offset shakeOffset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (shakeOffset != Offset.zero) {
      canvas.translate(shakeOffset.dx, shakeOffset.dy);
    }

    final double groundTop = size.height - GamePhysics.groundHeight;

    _drawDaySkyAndSun(canvas, size, groundTop);
    _drawClouds(canvas);
    _drawGroupSkyWatermark(canvas, size, groundTop);
    _drawPastelHills(canvas, size, groundTop);
    _drawPipes3D(canvas, groundTop);
    _drawHearts3D(canvas);
    _drawGroundTiles(canvas, size, groundTop);
    _drawParticles(canvas);
    _drawBird3D(canvas);
    _drawFloatingFeedbacks(canvas);

    if (flashAlpha > 0.001) {
      final Paint flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashAlpha.clamp(0.0, 0.8));
      canvas.drawRect(Offset.zero & size, flashPaint);
    }

    canvas.restore();
  }

  void _drawDaySkyAndSun(Canvas canvas, Size size, double groundTop) {
    final Rect skyRect = Rect.fromLTWH(0, 0, size.width, groundTop);
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          GameColors.skyTop,
          GameColors.skyMid,
          GameColors.skyHorizon,
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final Offset sunCenter = Offset(size.width * 0.14, 78);
    canvas.save();
    canvas.translate(sunCenter.dx, sunCenter.dy);
    canvas.rotate(elapsedTime * 0.14);
    final Paint rayPaint = Paint()
      ..color = GameColors.sunGlow.withValues(alpha: 0.18);
    for (int i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate((math.pi / 4) * i);
      final Path ray = Path()
        ..moveTo(-10, 0)
        ..lineTo(-24, -145)
        ..lineTo(24, -145)
        ..lineTo(10, 0)
        ..close();
      canvas.drawPath(ray, rayPaint);
      canvas.restore();
    }
    canvas.restore();

    final double pulse = 1.0 + 0.06 * math.sin(elapsedTime * 2.2);
    canvas.drawCircle(
      sunCenter,
      48 * pulse,
      Paint()..color = GameColors.sunGlow.withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      sunCenter,
      28,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Colors.white, GameColors.sunCore, GameColors.sunGlow],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 28)),
    );
  }

  void _drawClouds(Canvas canvas) {
    for (final SkyCloud cloud in clouds) {
      _drawSingleCloud(canvas, cloud.x, cloud.y, cloud.scale);
    }
  }

  void _drawSingleCloud(Canvas canvas, double x, double y, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);

    final Paint haloPaint = Paint()..color = GameColors.cloudHalo;
    final Paint fillPaint = Paint()..color = GameColors.cloudFill;

    const List<List<double>> puffs = [
      [-62, 16, 20],
      [-32, 4, 28],
      [8, -10, 38],
      [48, 2, 26],
      [76, 16, 18],
    ];
    for (final List<double> p in puffs) {
      canvas.drawCircle(Offset(p[0], p[1]), p[2] + 8, haloPaint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-88, 12, 190, 26),
        const Radius.circular(13),
      ),
      haloPaint,
    );

    for (final List<double> p in puffs) {
      canvas.drawCircle(Offset(p[0], p[1]), p[2], fillPaint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-82, 16, 178, 18),
        const Radius.circular(9),
      ),
      fillPaint,
    );

    canvas.restore();
  }

  void _drawGroupSkyWatermark(Canvas canvas, Size size, double groundTop) {
    final double heroSize = (size.width * 0.068).clamp(24.0, 44.0);
    final double eyebrowSize = (heroSize * 0.36).clamp(11.0, 16.0);

    final TextPainter heroMeasure = TextPainter(
      text: TextSpan(
        text: '2130 GROUP',
        style: TextStyle(
          fontSize: heroSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double heroWidth = heroMeasure.width + 44.0;
    final double span = size.width + heroWidth + 120.0;
    final double progress =
        (elapsedTime * 22.0 + worldScroll * 0.035 + span * 0.5) % span;
    final double driftX = size.width + heroWidth * 0.5 + 60.0 - progress;

    final double baseSkyY =
        math.max(122.0, math.min(groundTop * 0.36, groundTop - 185.0));
    final double floatY = math.sin(elapsedTime * 1.15) * 7.5;
    final double breathScale = 1.0 + 0.015 * math.sin(elapsedTime * 1.5);

    const double edgePad = 70.0;
    final double leftFade = ((driftX + heroWidth * 0.35) / edgePad).clamp(0.0, 1.0);
    final double rightFade =
        ((size.width - driftX + heroWidth * 0.35) / edgePad).clamp(0.0, 1.0);
    final double fadeAlpha =
        (0.76 + 0.1 * math.sin(elapsedTime * 1.4)) * math.min(leftFade, rightFade);
    if (fadeAlpha <= 0.01) return;

    final double eyebrowY = -heroSize * 0.62;
    final double heroY = heroSize * 0.12;
    final double ruleY = heroSize * 0.68;

    final TextPainter eyebrowGlow = TextPainter(
      text: TextSpan(
        text: "LET'S PLAY WITH",
        style: TextStyle(
          fontSize: eyebrowSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 3.6,
          color: Colors.white.withValues(alpha: 0.78 * fadeAlpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final TextPainter eyebrowFill = TextPainter(
      text: TextSpan(
        text: "LET'S PLAY WITH",
        style: TextStyle(
          fontSize: eyebrowSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 3.6,
          color: const Color(0xFF0F2744).withValues(alpha: 0.78 * fadeAlpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final TextPainter heroHalo = TextPainter(
      text: TextSpan(
        text: '2130 GROUP',
        style: TextStyle(
          fontSize: heroSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white.withValues(alpha: 0.78 * fadeAlpha),
          shadows: [
            Shadow(
              color: const Color(0xFF0F2744).withValues(alpha: 0.18 * fadeAlpha),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double halfW = heroWidth * 0.65;
    final double sweep = (math.sin(elapsedTime * 1.25) * 0.5 + 0.5) * 0.55;
    final Rect gradRect = Rect.fromLTRB(-halfW, heroY - 12, halfW, heroY + 14);
    final Shader textShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF1E3A8A).withValues(alpha: fadeAlpha),
        const Color(0xFF0284C7).withValues(alpha: fadeAlpha),
        const Color(0xFF0D9488).withValues(alpha: fadeAlpha),
        const Color(0xFFF59E0B).withValues(alpha: fadeAlpha),
        const Color(0xFF1D4ED8).withValues(alpha: fadeAlpha),
      ],
      stops: [
        0.0,
        math.max(0.08, 0.22 + sweep * 0.4),
        math.min(0.86, 0.48 + sweep * 0.5),
        math.min(0.96, 0.72 + sweep * 0.35),
        1.0,
      ],
    ).createShader(gradRect);

    final TextPainter heroFill = TextPainter(
      text: TextSpan(
        text: '2130 GROUP',
        style: TextStyle(
          fontSize: heroSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          foreground: Paint()..shader = textShader,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(driftX, baseSkyY + floatY);
    canvas.scale(breathScale);

    eyebrowGlow.paint(
      canvas,
      Offset(-eyebrowGlow.width / 2, eyebrowY - eyebrowGlow.height / 2 + 1),
    );
    eyebrowFill.paint(
      canvas,
      Offset(-eyebrowFill.width / 2, eyebrowY - eyebrowFill.height / 2),
    );

    heroHalo.paint(
      canvas,
      Offset(-heroHalo.width / 2, heroY - heroHalo.height / 2),
    );
    heroFill.paint(
      canvas,
      Offset(-heroFill.width / 2, heroY - heroFill.height / 2),
    );

    final double glintCenter = ((elapsedTime * 0.42) % 1.8) - 0.4;
    if (glintCenter >= -0.2 && glintCenter <= 1.2) {
      final Shader sheenShader = LinearGradient(
        colors: [
          const Color(0x00FFFFFF),
          Colors.white.withValues(alpha: 0.52 * fadeAlpha),
          const Color(0x00FFFFFF),
        ],
        stops: [
          (glintCenter - 0.14).clamp(0.0, 1.0),
          glintCenter.clamp(0.0, 1.0),
          (glintCenter + 0.14).clamp(0.0, 1.0),
        ],
      ).createShader(Rect.fromLTRB(-halfW, heroY - 12, halfW, heroY + 14));

      final TextPainter heroSheen = TextPainter(
        text: TextSpan(
          text: '2130 GROUP',
          style: TextStyle(
            fontSize: heroSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            foreground: Paint()..shader = sheenShader,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      heroSheen.paint(
        canvas,
        Offset(-heroSheen.width / 2, heroY - heroSheen.height / 2),
      );
    }

    final double lineHalf = math.min(size.width * 0.26, heroWidth * 0.46);
    final Rect lineRect = Rect.fromLTWH(-lineHalf, ruleY - 1.0, lineHalf * 2, 2.0);
    final Paint linePaint = Paint()
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          const Color(0x000284C7),
          const Color(0xFF0284C7).withValues(alpha: 0.55 * fadeAlpha),
          const Color(0xFFF59E0B).withValues(alpha: 0.78 * fadeAlpha),
          const Color(0xFF0D9488).withValues(alpha: 0.55 * fadeAlpha),
          const Color(0x000284C7),
        ],
        stops: const [0.0, 0.28, 0.5, 0.72, 1.0],
      ).createShader(lineRect);
    canvas.drawLine(Offset(-lineHalf, ruleY), Offset(lineHalf, ruleY), linePaint);

    final double orbX = math.sin(elapsedTime * 1.45) * (lineHalf * 0.62);
    canvas.drawCircle(
      Offset(orbX, ruleY),
      2.6,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * fadeAlpha),
    );

    canvas.restore();
  }

  void _drawPastelHills(Canvas canvas, Size size, double groundTop) {
    _drawHillWave(
      canvas: canvas,
      width: size.width,
      groundTop: groundTop,
      baseHeight: 152,
      amplitude: 52,
      wavelength: 480,
      scroll: worldScroll * 0.16,
      color: GameColors.hillBack,
    );

    _drawHillWave(
      canvas: canvas,
      width: size.width,
      groundTop: groundTop,
      baseHeight: 84,
      amplitude: 34,
      wavelength: 390,
      scroll: worldScroll * 0.28 + 140,
      color: GameColors.hillFront,
    );
  }

  void _drawHillWave({
    required Canvas canvas,
    required double width,
    required double groundTop,
    required double baseHeight,
    required double amplitude,
    required double wavelength,
    required double scroll,
    required Color color,
  }) {
    final Path path = Path()..moveTo(-20, groundTop);
    final double phase = (scroll / wavelength) * math.pi * 2;
    for (double x = -20; x <= width + 20; x += 16) {
      final double y = groundTop -
          baseHeight -
          math.sin((x / wavelength) * math.pi * 2 + phase) * amplitude;
      path.lineTo(x, y);
    }
    path.lineTo(width + 20, groundTop);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawPipes3D(Canvas canvas, double groundTop) {
    for (final PipePair pipe in pipes) {
      final double topBottom = pipe.topPipeBottomAt(elapsedTime);
      final double bottomTop = pipe.bottomPipeTopAt(elapsedTime);

      if (topBottom > 0) {
        _drawSingle3DObstacle(
          canvas: canvas,
          x: pipe.x,
          top: -12,
          bottom: topBottom,
          capAtBottom: true,
          kind: pipe.kind,
          phase: pipe.phase,
        );
      }

      if (bottomTop < groundTop) {
        _drawSingle3DObstacle(
          canvas: canvas,
          x: pipe.x,
          top: bottomTop,
          bottom: groundTop,
          capAtBottom: false,
          kind: pipe.kind,
          phase: pipe.phase,
        );
      }
    }
  }

  void _drawSingle3DObstacle({
    required Canvas canvas,
    required double x,
    required double top,
    required double bottom,
    required bool capAtBottom,
    required ObstacleKind kind,
    required double phase,
  }) {
    const double w = GamePhysics.pipeWidth;
    const double capOverhang = GamePhysics.pipeCapOverhang;
    const double capH = GamePhysics.pipeCapHeight;
    const double depth = GamePhysics.obstacle3dDepth;
    const double skewY = 6.0;

    final List<Color> gradientColors;
    final Color sideShadowColor;
    final Color rimAccentColor;
    final Color borderColor;

    switch (kind) {
      case ObstacleKind.emeraldCylinder:
        gradientColors = const [
          GameColors.pipeShadowLeft,
          GameColors.pipeMid,
          GameColors.pipeSpecular,
          GameColors.pipeMid,
          GameColors.pipeShadowRight,
        ];
        sideShadowColor = GameColors.pipeDarkEdge;
        rimAccentColor = GameColors.pipeSpecular;
        borderColor = GameColors.pipeBorder;
      case ObstacleKind.hoverPropellerGate:
        gradientColors = const [
          GameColors.gateBlueDark,
          GameColors.gateBlueMid,
          GameColors.gateBlueLight,
          GameColors.gateBlueMid,
          GameColors.gateBlueDark,
        ];
        sideShadowColor = const Color(0xFF172554);
        rimAccentColor = GameColors.gateGold;
        borderColor = const Color(0xFF0F172A);
      case ObstacleKind.beaconTower:
        gradientColors = const [
          GameColors.towerCoralDark,
          GameColors.towerCoralMid,
          GameColors.towerCoralLight,
          GameColors.towerCoralMid,
          GameColors.towerCoralDark,
        ];
        sideShadowColor = const Color(0xFF4C0519);
        rimAccentColor = GameColors.gateGold;
        borderColor = const Color(0xFF2D0612);
    }

    final Rect shaftRect = Rect.fromLTWH(x, top, w, bottom - top);
    final double capY = capAtBottom ? bottom - capH : top;
    final Rect capRect = Rect.fromLTWH(
      x - capOverhang,
      capY,
      w + capOverhang * 2,
      capH,
    );

    // Soft cast shadow behind 3D column
    canvas.drawRect(
      shaftRect.translate(depth + 4, 2),
      Paint()..color = const Color(0x180F172A),
    );

    // 3D Extruded right-side face on shaft
    final Path shaftSide = Path()
      ..moveTo(shaftRect.right, shaftRect.top)
      ..lineTo(shaftRect.right + depth, shaftRect.top - skewY)
      ..lineTo(shaftRect.right + depth, shaftRect.bottom - skewY)
      ..lineTo(shaftRect.right, shaftRect.bottom)
      ..close();
    canvas.drawPath(shaftSide, Paint()..color = sideShadowColor);

    // Front cylindrical face on shaft
    _paintCylinderRect(canvas, shaftRect, gradientColors);

    // Animated diagonal shine / energy sweep inside shaft
    canvas.save();
    canvas.clipRect(shaftRect);
    final double sweepPos =
        ((elapsedTime * 90 + phase * 60) % (shaftRect.height + 120)) - 60;
    final double bandY = shaftRect.top + sweepPos;
    canvas.drawRect(
      Rect.fromLTWH(shaftRect.left, bandY, shaftRect.width, 18),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    if (kind == ObstacleKind.beaconTower) {
      // Gold horizontal structural rings on tower
      for (double ry = shaftRect.top + 38;
          ry < shaftRect.bottom - 38;
          ry += 56) {
        canvas.drawRect(
          Rect.fromLTWH(shaftRect.left + 2, ry, shaftRect.width - 4, 5),
          Paint()..color = GameColors.gateGold.withValues(alpha: 0.75),
        );
      }
    }
    canvas.restore();

    // 3D Extruded right-side face on cap
    final Path capSide = Path()
      ..moveTo(capRect.right, capRect.top)
      ..lineTo(capRect.right + depth, capRect.top - skewY)
      ..lineTo(capRect.right + depth, capRect.bottom - skewY)
      ..lineTo(capRect.right, capRect.bottom)
      ..close();
    canvas.drawPath(capSide, Paint()..color = sideShadowColor);

    // Front cylindrical face on cap
    _paintCylinderRect(canvas, capRect, gradientColors);

    // 3D Elliptical hollow rim at pipe mouth!
    final double mouthY = capAtBottom ? capRect.bottom : capRect.top;
    final Rect mouthOuter = Rect.fromCenter(
      center: Offset(capRect.center.dx + 2, mouthY),
      width: capRect.width - 4,
      height: 11,
    );
    canvas.drawOval(
      mouthOuter,
      Paint()..color = rimAccentColor.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      mouthOuter.deflate(3.0),
      Paint()..color = const Color(0xFF0B1910),
    );
    canvas.drawOval(
      mouthOuter,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Crisp borders on 3D geometry
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRect(shaftRect, borderPaint);
    canvas.drawPath(shaftSide, borderPaint);
    canvas.drawRect(capRect, borderPaint);
    canvas.drawPath(capSide, borderPaint);

    // Kind-specific animated 3D attachments
    if (kind == ObstacleKind.hoverPropellerGate) {
      // Spinning 3D golden propeller blades mounted on the cap mouth!
      final double propY = capAtBottom ? capRect.top + 8 : capRect.bottom - 8;
      _drawSpinningPropeller3D(
        canvas,
        Offset(capRect.center.dx, propY),
        elapsedTime * 11.0 + phase,
      );
    } else if (kind == ObstacleKind.beaconTower) {
      // Glowing pulsing amber beacon orb on cap center
      final double orbY = capAtBottom ? capRect.top + 10 : capRect.bottom - 10;
      final double glow = 0.55 + 0.45 * math.sin(elapsedTime * 6.5 + phase);
      final Offset orbCenter = Offset(capRect.center.dx, orbY);
      canvas.drawCircle(
        orbCenter,
        11,
        Paint()..color = GameColors.gateGold.withValues(alpha: 0.35 * glow),
      );
      canvas.drawCircle(
        orbCenter,
        6,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [
              Colors.white,
              GameColors.gateGold,
              GameColors.gateGoldDark,
            ],
          ).createShader(Rect.fromCircle(center: orbCenter, radius: 6)),
      );
    }
  }

  void _paintCylinderRect(
      Canvas canvas, Rect rect, List<Color> gradientColors) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: gradientColors,
        stops: const [0.0, 0.20, 0.36, 0.68, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawSpinningPropeller3D(Canvas canvas, Offset center, double angle) {
    final double bladeWidth = math.cos(angle).abs() * 24.0 + 4.0;
    final Paint bladePaint = Paint()
      ..shader = const LinearGradient(
        colors: [GameColors.gateGoldDark, GameColors.gateGold, Colors.white],
      ).createShader(
        Rect.fromCenter(center: center, width: bladeWidth * 2, height: 8),
      );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - bladeWidth * 0.55, center.dy),
        width: bladeWidth,
        height: 7,
      ),
      bladePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + bladeWidth * 0.55, center.dy),
        width: bladeWidth,
        height: 7,
      ),
      bladePaint,
    );
    canvas.drawCircle(
      center,
      5,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      Offset(center.dx - 1.2, center.dy - 1.2),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _drawHearts3D(Canvas canvas) {
    for (final HeartPickup heart in hearts) {
      if (heart.collected) continue;
      final double y =
          heart.baseY + math.sin(elapsedTime * 4.2 + heart.phase) * 6.0;
      final double pulse =
          1.0 + 0.08 * math.sin(elapsedTime * 6.0 + heart.phase);
      final double spinX =
          0.74 + 0.26 * math.cos(elapsedTime * 3.4 + heart.phase);

      canvas.save();
      canvas.translate(heart.x, y);
      canvas.scale(pulse * spinX, pulse);

      canvas.drawCircle(
        Offset.zero,
        22,
        Paint()..color = GameColors.heartBright.withValues(alpha: 0.28),
      );

      final Path path = Path()
        ..moveTo(0, 14)
        ..cubicTo(-19, 2, -19, -15, -8, -15)
        ..cubicTo(-2, -15, 0, -8, 0, -7)
        ..cubicTo(0, -8, 2, -15, 8, -15)
        ..cubicTo(19, -15, 19, 2, 0, 14)
        ..close();

      final Rect bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            radius: 0.95,
            colors: [
              Colors.white,
              GameColors.heartBright,
              GameColors.heartRed,
              GameColors.heartDeep,
            ],
            stops: [0.0, 0.22, 0.62, 1.0],
          ).createShader(bounds),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF4A0810)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      canvas.restore();
    }
  }

  void _drawGroundTiles(Canvas canvas, Size size, double groundTop) {
    const double tileWidth = 64.0;
    final double offset = worldScroll % tileWidth;

    final Paint grassPaint = Paint()..color = GameColors.grassBright;
    final Paint grassDarkPaint = Paint()..color = GameColors.grassShadow;
    final Paint soilTopPaint = Paint()..color = GameColors.soilTop;
    final Paint soilMidPaint = Paint()..color = GameColors.soilMid;
    final Paint soilBottomPaint = Paint()..color = GameColors.soilBottom;
    final Paint pebblePaint = Paint()..color = GameColors.soilPebble;
    final Paint dividerPaint = Paint()..color = GameColors.groundDivider;

    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + 18, size.width, 16),
      soilTopPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + 34, size.width, 24),
      soilMidPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        groundTop + 58,
        size.width,
        GamePhysics.groundHeight - 58,
      ),
      soilBottomPaint,
    );

    for (double x = -offset - tileWidth;
        x < size.width + tileWidth;
        x += tileWidth) {
      final Path grassWave = Path()
        ..moveTo(x, groundTop)
        ..lineTo(x + tileWidth, groundTop)
        ..lineTo(x + tileWidth, groundTop + 19)
        ..lineTo(x + tileWidth * 0.78, groundTop + 26)
        ..lineTo(x + tileWidth * 0.56, groundTop + 17)
        ..lineTo(x + tileWidth * 0.34, groundTop + 26)
        ..lineTo(x + tileWidth * 0.14, groundTop + 18)
        ..lineTo(x, groundTop + 22)
        ..close();

      // 3D shadow lip under grass wave
      canvas.drawPath(
        grassWave.shift(const Offset(0, 3)),
        Paint()..color = const Color(0x44000000),
      );
      canvas.drawPath(grassWave, grassPaint);
      canvas.drawRect(
        Rect.fromLTWH(x + 2, groundTop + 2, tileWidth - 4, 4),
        grassDarkPaint,
      );

      canvas.drawCircle(Offset(x + 16, groundTop + 67), 2.5, pebblePaint);
      canvas.drawCircle(Offset(x + 34, groundTop + 73), 2.0, pebblePaint);
      canvas.drawCircle(Offset(x + 50, groundTop + 65), 2.8, pebblePaint);

      canvas.drawRect(
        Rect.fromLTWH(x, groundTop, 3.2, GamePhysics.groundHeight),
        dividerPaint,
      );
    }

    canvas.drawRect(Rect.fromLTWH(0, groundTop, size.width, 3.0), dividerPaint);
  }

  void _drawParticles(Canvas canvas) {
    final Paint paint = Paint();
    for (final FlapParticle pt in particles) {
      final double progress = pt.alpha;
      switch (pt.kind) {
        case ParticleKind.trail:
          final double fade = math.pow(progress, 1.35).toDouble();
          final double radius = pt.size * (0.28 + 0.55 * progress);
          paint.color = pt.color.withValues(alpha: fade * 0.28);
          canvas.drawCircle(Offset(pt.x, pt.y), radius * 1.85, paint);
          paint.color = pt.color.withValues(alpha: fade * 0.9);
          canvas.drawCircle(Offset(pt.x, pt.y), radius, paint);
        case ParticleKind.feather:
          final double fade = math.pow(progress, 1.15).toDouble();
          final double radius = pt.size * (0.45 + 0.55 * progress);
          canvas.save();
          canvas.translate(pt.x, pt.y);
          canvas.rotate(pt.rotation);
          paint.color = pt.color.withValues(alpha: fade * 0.92);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * 2.9,
              height: radius * 1.16,
            ),
            paint,
          );
          canvas.restore();
        case ParticleKind.burst:
          paint.color = pt.color.withValues(alpha: progress);
          canvas.drawCircle(
            Offset(pt.x, pt.y),
            pt.size * (0.3 + 0.35 * progress),
            paint,
          );
      }
    }
  }

  void _drawBird3D(Canvas canvas) {
    if (invulnTimer > 0 && ((invulnTimer * 18).floor().isOdd)) {
      _drawShieldRing(canvas);
      return;
    }

    if (invulnTimer > 0) {
      _drawShieldRing(canvas);
    }

    drawCool3DBird(
      canvas: canvas,
      center: Offset(birdX, birdY),
      angle: birdAngle,
      wingPhase: wingPhase,
      flapSquash: flapSquash,
      hatBounce: hatBounce,
      elapsedTime: elapsedTime,
      skin: birdSkin,
    );
  }

  void _drawShieldRing(Canvas canvas) {
    final double pulse = 1.0 + 0.08 * math.sin(elapsedTime * 16.0);
    canvas.drawCircle(
      Offset(birdX, birdY),
      29 * pulse,
      Paint()
        ..color = GameColors.heartBright.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(birdX, birdY),
      29 * pulse,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
  }

  void _drawFloatingFeedbacks(Canvas canvas) {
    for (final FloatingFeedback fb in feedbacks) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: fb.text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: fb.color.withValues(alpha: fb.alpha),
            shadows: [
              Shadow(
                color: Colors.white.withValues(alpha: fb.alpha * 0.9),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(fb.x - tp.width / 2, fb.y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant FlappyScenePainter oldDelegate) => true;
}

void drawCool3DBird({
  required Canvas canvas,
  required Offset center,
  required double angle,
  required double wingPhase,
  required double flapSquash,
  required double hatBounce,
  required double elapsedTime,
  required BirdSkin skin,
  double scale = 1.0,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  canvas.rotate(angle);

  // Squash & stretch on flap for volumetric 3D animation feel
  final double sx = 1.0 + flapSquash * 0.14;
  final double sy = 1.0 - flapSquash * 0.12;
  canvas.scale(sx, sy);

  final Paint outline = Paint()
    ..color = GameColors.birdOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeJoin = StrokeJoin.round;

  // 1. Animated 3D fanned tail feathers
  final double tailFlutter = math.sin(wingPhase) * 2.5;
  final Path tail = Path()
    ..moveTo(-16, 0)
    ..lineTo(-28, -7 + tailFlutter * 0.5)
    ..lineTo(-22, 1)
    ..lineTo(-29, 5 + tailFlutter)
    ..lineTo(-21, 8)
    ..lineTo(-25, 14 + tailFlutter * 0.4)
    ..lineTo(-14, 9)
    ..close();
  canvas.drawPath(tail, Paint()..color = skin.primaryDark);
  canvas.drawPath(tail, outline);

  // 2. Volumetric 3D spherical body with off-center specular lighting
  const Rect bodyRect = Rect.fromLTWH(-18, -14, 37, 31);
  final Paint bodyFill = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 0.92,
      colors: [
        Colors.white,
        skin.primaryLight,
        skin.primaryMid,
        skin.primaryDark,
      ],
      stops: const [0.0, 0.24, 0.65, 1.0],
    ).createShader(bodyRect);
  canvas.drawOval(bodyRect, bodyFill);

  // Soft 3D rim-light crescent along top-left back
  canvas.drawArc(
    bodyRect.deflate(2.5),
    math.pi * 1.05,
    math.pi * 0.55,
    false,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );
  canvas.drawOval(bodyRect, outline);

  // 3. 3D Expressive blinking eye with glossy specular glint
  final bool isBlinking = (elapsedTime % 3.4) > 3.27;
  const Rect eyeRect = Rect.fromLTWH(2, -8.5, 12.5, 10.5);
  if (isBlinking) {
    canvas.drawLine(
      const Offset(2, -3),
      const Offset(14.5, -3),
      outline,
    );
  } else {
    canvas.drawOval(eyeRect, Paint()..color = Colors.white);
    canvas.drawOval(eyeRect, outline);
    canvas.drawCircle(
      const Offset(9.2, -2.8),
      2.6,
      Paint()..color = GameColors.birdOutline,
    );
    // Glossy 3D specular glint inside eye
    canvas.drawCircle(
      const Offset(10.0, -3.8),
      1.0,
      Paint()..color = Colors.white,
    );
    // Cool half-lidded brow
    canvas.drawRect(
      const Rect.fromLTWH(1, -9.5, 14, 4.0),
      Paint()..color = skin.primaryMid,
    );
    canvas.drawLine(
      const Offset(1, -5.5),
      const Offset(15, -5.5),
      outline,
    );
  }

  // 4. 3D-shaded chunky two-part orange beak
  final Path upperBeak = Path()
    ..moveTo(13, -1)
    ..quadraticBezierTo(28, -2.5, 27, 3.5)
    ..lineTo(13, 4.5)
    ..close();
  canvas.drawPath(
    upperBeak,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFD873), GameColors.birdBeakTop],
      ).createShader(upperBeak.getBounds()),
  );
  canvas.drawPath(upperBeak, outline);

  final Path lowerBeak = Path()
    ..moveTo(13, 4.5)
    ..lineTo(26, 4.5)
    ..quadraticBezierTo(23.5, 10.5, 12, 8.8)
    ..close();
  canvas.drawPath(lowerBeak, Paint()..color = GameColors.birdBeakBottom);
  canvas.drawPath(lowerBeak, outline);

  // 5. 3D Foreshortened wing with cast shadow onto the body
  final double wingWave = math.sin(wingPhase);
  final double wingScaleY = 0.55 + 0.45 * wingWave.abs();
  final double wingOffsetY = wingWave * 5.0;
  final double wingTilt = wingWave * 0.45;

  // Ambient shadow under wing on bird belly
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(-3, 6.5 + wingOffsetY * 0.25),
      width: 17,
      height: 8,
    ),
    Paint()..color = const Color(0x33000000),
  );

  canvas.save();
  canvas.translate(-4, 3.5 + wingOffsetY * 0.5);
  canvas.rotate(wingTilt);
  canvas.scale(1.0, wingScaleY);
  final Path wing = Path()
    ..moveTo(-10, -4)
    ..quadraticBezierTo(3, -7, 7, 2)
    ..quadraticBezierTo(2, 11, -9, 9)
    ..quadraticBezierTo(-14, 2, -10, -4)
    ..close();
  canvas.drawPath(
    wing,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, skin.primaryLight, skin.primaryMid],
      ).createShader(wing.getBounds()),
  );
  canvas.drawPath(wing, outline);
  canvas.restore();

  // 6. 3D Brown Fedora / Top Hat with bounce lag & cast brim shadow
  // Shadow cast onto forehead
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(2, -12), width: 22, height: 5),
    Paint()..color = const Color(0x33000000),
  );

  canvas.save();
  canvas.translate(2, -13.5 - hatBounce * 5.5);
  canvas.rotate(0.12 - hatBounce * 0.14);

  final RRect crown = RRect.fromRectAndCorners(
    const Rect.fromLTWH(-10.5, -12, 21, 12),
    topLeft: const Radius.circular(4.5),
    topRight: const Radius.circular(4.5),
  );
  canvas.drawRRect(
    crown,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [skin.hatCrown, skin.hatShade],
        stops: const [0.4, 1.0],
      ).createShader(crown.outerRect),
  );
  // Hat specular edge highlight
  canvas.drawLine(
    const Offset(-8, -10),
    const Offset(-8, -4.5),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2.0,
  );
  // Hatband
  canvas.drawRect(
    const Rect.fromLTWH(-10.5, -4, 21, 4),
    Paint()..color = GameColors.hatBand,
  );
  canvas.drawRRect(crown, outline);

  // 3D Elliptical tilted brim
  final RRect brim = RRect.fromRectAndRadius(
    const Rect.fromLTWH(-16, -2, 32, 5.2),
    const Radius.circular(2.6),
  );
  canvas.drawRRect(brim, Paint()..color = skin.hatShade);
  canvas.drawRRect(brim, outline);
  canvas.restore();

  canvas.restore();
}

class BirdPreviewPainter extends CustomPainter {
  BirdPreviewPainter({required this.skin});

  final BirdSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    drawCool3DBird(
      canvas: canvas,
      center: Offset(size.width * 0.46, size.height * 0.56),
      angle: -0.08,
      wingPhase: 0.6,
      flapSquash: 0.0,
      hatBounce: 0.0,
      elapsedTime: 1.0,
      skin: skin,
      scale: 0.68,
    );
  }

  @override
  bool shouldRepaint(covariant BirdPreviewPainter oldDelegate) =>
      oldDelegate.skin != skin;
}
