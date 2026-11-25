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
    required this.wingFrame,
    required this.pipes,
    required this.stars,
    required this.ghosts,
    required this.particles,
    required this.flashAlpha,
    required this.shakeOffset,
  });

  final double elapsedTime;
  final double worldScroll;
  final double birdX;
  final double birdY;
  final double birdAngle;
  final int wingFrame;
  final List<PipePair> pipes;
  final List<NightStar> stars;
  final List<GhostSprite> ghosts;
  final List<FlapParticle> particles;
  final double flashAlpha;
  final Offset shakeOffset;

  static const List<String> _birdBodyGrid = [
    '......KKKKKK.....',
    '....KKHHHHYYKK...',
    '...KHHYYYYKWWWK..',
    '..KHHYYYYYKWWKWK.',
    '.KYYYYYYYYKWWWK..',
    '.KYYYYYYYYYKKKKK.',
    '.KYYYYYYYYKRRRRRK',
    '.KOOOOOOOOOKKKKK.',
    '..KOOOOOOOKDDDDK.',
    '...KOOOOOOOKKKKK.',
    '....KKOOOOOOK....',
    '......KKKKKK.....',
  ];

  static const List<String> _ghostGrid = [
    '....KKKKKK....',
    '..KKWWWWWWKK..',
    '.KWWWWWWWWWWK.',
    '.KWWWKKKKKWWK.',
    'KWWWWKWWWKWWWK',
    'KWWWWKWKWKWWWK',
    'KWWWWKWWWKWWWK',
    'KWWWWKKKKKWWWK',
    'KSSSSSSSSSSSSK',
    '.KKWKKWWKKWKK.',
    '...KK....KK...',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (shakeOffset != Offset.zero) {
      canvas.translate(shakeOffset.dx, shakeOffset.dy);
    }

    final double groundTop = size.height - GamePhysics.groundHeight;

    _drawNightSky(canvas, size, groundTop);
    _drawStars(canvas, size, groundTop);
    _drawClouds(canvas, size, groundTop);
    _drawCitySkyline(canvas, size, groundTop);
    _drawBushes(canvas, size, groundTop);
    _drawGhosts(canvas, groundTop);
    _drawPipes(canvas, groundTop);
    _drawGround(canvas, size, groundTop);
    _drawParticles(canvas);
    _drawBird(canvas);

    if (flashAlpha > 0.001) {
      final Paint flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashAlpha.clamp(0.0, 0.85));
      canvas.drawRect(Offset.zero & size, flashPaint);
    }

    canvas.restore();
  }

  void _drawNightSky(Canvas canvas, Size size, double groundTop) {
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
        stops: [0.0, 0.58, 1.0],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);
  }

  void _drawStars(Canvas canvas, Size size, double groundTop) {
    final Paint paint = Paint()..isAntiAlias = false;
    final double skyHeight = math.max(120.0, groundTop - 110.0);

    for (final NightStar star in stars) {
      final double twinkle =
          0.55 + 0.45 * math.sin(elapsedTime * 2.6 + star.phase);
      final double sx =
          ((star.nx * size.width - worldScroll * 0.03) % size.width +
                  size.width) %
              size.width;
      final double sy = star.ny * skyHeight + 16.0;
      paint.color = star.color.withValues(alpha: twinkle.clamp(0.25, 1.0));

      if (star.isSparkle) {
        final double arm = star.size;
        canvas.drawRect(
          Rect.fromLTWH(sx - arm * 0.35, sy - arm, arm * 0.7, arm * 2),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(sx - arm, sy - arm * 0.35, arm * 2, arm * 0.7),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(sx, sy, star.size, star.size),
          paint,
        );
      }
    }
  }

  void _drawClouds(Canvas canvas, Size size, double groundTop) {
    final double baseY = groundTop - 72.0;
    const double tileWidth = 360.0;
    final double offset = (worldScroll * 0.14) % tileWidth;

    final Paint lightPaint = Paint()..color = GameColors.cloudLight;
    final Paint darkPaint = Paint()..color = GameColors.cloudDark;

    for (double x = -offset - tileWidth; x < size.width + tileWidth; x += tileWidth) {
      _drawCloudCluster(canvas, x, baseY - 6, lightPaint);
      _drawCloudCluster(canvas, x, baseY + 6, darkPaint);
    }
  }

  void _drawCloudCluster(Canvas canvas, double x, double baseY, Paint paint) {
    const List<List<double>> puffs = [
      [28, -22, 34],
      [74, -36, 44],
      [126, -24, 36],
      [172, -16, 30],
      [226, -30, 40],
      [278, -38, 42],
      [330, -22, 34],
    ];
    for (final List<double> p in puffs) {
      canvas.drawCircle(Offset(x + p[0], baseY + p[1]), p[2], paint);
    }
    canvas.drawRect(
      Rect.fromLTWH(x, baseY - 18, 362, 100),
      paint,
    );
  }

  void _drawCitySkyline(Canvas canvas, Size size, double groundTop) {
    final double baseY = groundTop - 22.0;
    const double patternWidth = 320.0;
    final double offset = (worldScroll * 0.24) % patternWidth;

    final Paint backPaint = Paint()..color = GameColors.cityBack;
    final Paint frontPaint = Paint()..color = GameColors.cityFront;
    final Paint windowPaint = Paint()..color = GameColors.cityWindow;

    const List<List<double>> buildings = [
      [6, 54, 92, 0],
      [52, 42, 64, 1],
      [88, 60, 108, 0],
      [142, 46, 76, 1],
      [182, 58, 98, 0],
      [234, 40, 58, 1],
      [268, 56, 86, 0],
    ];

    for (double x = -offset - patternWidth;
        x < size.width + patternWidth;
        x += patternWidth) {
      for (final List<double> b in buildings) {
        final double bx = x + b[0];
        final double bw = b[1];
        final double bh = b[2];
        final bool isFront = b[3] > 0.5;
        final Rect rect = Rect.fromLTWH(bx, baseY - bh, bw, bh + 22);
        canvas.drawRect(rect, isFront ? frontPaint : backPaint);

        // Subtle pixel rooftop trim and darkened window grid
        canvas.drawRect(
          Rect.fromLTWH(bx + 4, baseY - bh - 4, bw - 8, 4),
          isFront ? frontPaint : backPaint,
        );
        for (double wy = baseY - bh + 10; wy < baseY - 26; wy += 16) {
          for (double wx = bx + 8; wx < bx + bw - 10; wx += 12) {
            if (((wx + wy).toInt() % 3) != 0) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 7), windowPaint);
            }
          }
        }
      }
    }
  }

  void _drawBushes(Canvas canvas, Size size, double groundTop) {
    const double tileWidth = 220.0;
    final double offset = (worldScroll * 0.45) % tileWidth;

    final Paint lightPaint = Paint()..color = GameColors.bushLight;
    final Paint midPaint = Paint()..color = GameColors.bushMid;
    final Paint darkPaint = Paint()..color = GameColors.bushDark;

    for (double x = -offset - tileWidth; x < size.width + tileWidth; x += tileWidth) {
      const List<List<double>> mounds = [
        [20, 22],
        [52, 30],
        [88, 24],
        [124, 28],
        [162, 22],
        [198, 27],
      ];
      for (final List<double> m in mounds) {
        canvas.drawCircle(Offset(x + m[0], groundTop - 6), m[1], lightPaint);
        canvas.drawCircle(Offset(x + m[0], groundTop - 1), m[1] - 3, midPaint);
      }
      canvas.drawRect(
        Rect.fromLTWH(x, groundTop - 10, tileWidth + 2, 12),
        darkPaint,
      );
    }
  }

  void _drawGhosts(Canvas canvas, double groundTop) {
    for (final GhostSprite ghost in ghosts) {
      final double bobY =
          ghost.baseY + math.sin(elapsedTime * 2.2 + ghost.phase) * 9.0;
      if (bobY > groundTop - 48) continue;

      final double px = 2.6 * ghost.scale;
      final double startX = ghost.x - (_ghostGrid[0].length * px) / 2;
      final double startY = bobY - (_ghostGrid.length * px) / 2;

      final Paint p = Paint()..isAntiAlias = false;
      for (int r = 0; r < _ghostGrid.length; r++) {
        final String row = _ghostGrid[r];
        for (int c = 0; c < row.length; c++) {
          final String ch = row[c];
          if (ch == '.') continue;
          switch (ch) {
            case 'K':
              p.color = const Color(0xFF1A2238);
            case 'W':
              p.color = const Color(0xFFFDFEFF);
            case 'S':
              p.color = const Color(0xFFD6E2F5);
            default:
              continue;
          }
          canvas.drawRect(
            Rect.fromLTWH(
              startX + c * px,
              startY + r * px,
              px + 0.35,
              px + 0.35,
            ),
            p,
          );
        }
      }
    }
  }

  void _drawPipes(Canvas canvas, double groundTop) {
    for (final PipePair pipe in pipes) {
      // Top pipe (extends from y = -10 down to pipe.topPipeBottom)
      if (pipe.topPipeBottom > 0) {
        _drawSinglePipe(
          canvas: canvas,
          x: pipe.x,
          top: -8,
          bottom: pipe.topPipeBottom,
          capAtBottom: true,
        );
      }

      // Bottom pipe (extends from pipe.bottomPipeTop down to groundTop)
      if (pipe.bottomPipeTop < groundTop) {
        _drawSinglePipe(
          canvas: canvas,
          x: pipe.x,
          top: pipe.bottomPipeTop,
          bottom: groundTop,
          capAtBottom: false,
        );
      }
    }
  }

  void _drawSinglePipe({
    required Canvas canvas,
    required double x,
    required double top,
    required double bottom,
    required bool capAtBottom,
  }) {
    const double w = GamePhysics.pipeWidth;
    const double capOverhang = GamePhysics.pipeCapOverhang;
    const double capH = GamePhysics.pipeCapHeight;

    final Rect shaftRect = Rect.fromLTWH(x, top, w, bottom - top);
    _drawPipeShadedSegment(canvas, shaftRect);

    final double capY = capAtBottom ? bottom - capH : top;
    final Rect capRect = Rect.fromLTWH(
      x - capOverhang,
      capY,
      w + capOverhang * 2,
      capH,
    );
    _drawPipeShadedSegment(canvas, capRect);

    // Subtle rim bevel inside the cap
    final Paint rimHighlight = Paint()
      ..color = GameColors.pipeHighlightBright.withValues(alpha: 0.55);
    final Paint rimShadow = Paint()
      ..color = GameColors.pipeShadowDeep.withValues(alpha: 0.45);
    canvas.drawRect(
      Rect.fromLTWH(capRect.left + 3, capRect.top + 3, capRect.width - 6, 3),
      rimHighlight,
    );
    canvas.drawRect(
      Rect.fromLTWH(capRect.left + 3, capRect.bottom - 6, capRect.width - 6, 3),
      rimShadow,
    );

    final Paint borderPaint = Paint()
      ..color = GameColors.pipeBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawRect(shaftRect, borderPaint);
    canvas.drawRect(capRect, borderPaint);
  }

  void _drawPipeShadedSegment(Canvas canvas, Rect rect) {
    final double w = rect.width;
    // Main base
    canvas.drawRect(rect, Paint()..color = GameColors.pipeMain);
    // Left highlight band
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 6, rect.top, w * 0.17, rect.height),
      Paint()..color = GameColors.pipeHighlight,
    );
    // Crisp bright edge highlight
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 9, rect.top, w * 0.06, rect.height),
      Paint()..color = GameColors.pipeHighlightBright,
    );
    // Secondary thin highlight
    canvas.drawRect(
      Rect.fromLTWH(rect.left + w * 0.28, rect.top, w * 0.05, rect.height),
      Paint()..color = GameColors.pipeHighlight,
    );
    // Right shadow band
    canvas.drawRect(
      Rect.fromLTWH(rect.right - w * 0.26, rect.top, w * 0.16, rect.height),
      Paint()..color = GameColors.pipeShadow,
    );
    // Deepest right shadow edge
    canvas.drawRect(
      Rect.fromLTWH(rect.right - w * 0.11, rect.top, w * 0.11, rect.height),
      Paint()..color = GameColors.pipeShadowDeep,
    );
  }

  void _drawGround(Canvas canvas, Size size, double groundTop) {
    const double grassStripHeight = 22.0;
    const double tileWidth = 32.0;
    final double offset = worldScroll % tileWidth;

    // Sandy earth base
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        groundTop + grassStripHeight,
        size.width,
        GamePhysics.groundHeight - grassStripHeight,
      ),
      Paint()..color = GameColors.dirtMain,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + grassStripHeight, size.width, 6),
      Paint()..color = GameColors.dirtLight,
    );

    // Scrolling subtle dirt pebbles
    final Paint pebblePaint = Paint()..color = GameColors.dirtPebble;
    for (double x = -offset - tileWidth; x < size.width + tileWidth; x += tileWidth) {
      canvas.drawRect(
        Rect.fromLTWH(x + 6, groundTop + 36, 8, 4),
        pebblePaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 20, groundTop + 52, 6, 4),
        pebblePaint,
      );
    }

    // Green tiled grass strip matching the pixel block strip in screenshot
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, size.width, grassStripHeight),
      Paint()..color = GameColors.grassMain,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + 2, size.width, 4),
      Paint()..color = GameColors.grassLight,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + grassStripHeight - 5, size.width, 5),
      Paint()..color = GameColors.grassDark,
    );

    final Paint tileDivider = Paint()..color = GameColors.grassDark;
    final Paint tileHighlight = Paint()..color = GameColors.grassLight;
    for (double x = -offset - tileWidth; x < size.width + tileWidth; x += tileWidth) {
      // Diagonal pixel chevron block seam
      canvas.drawRect(
        Rect.fromLTWH(x + 12, groundTop + 4, 8, 14),
        tileHighlight,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 24, groundTop + 3, 4, grassStripHeight - 4),
        tileDivider,
      );
    }

    // Crisp top & bottom borders on grass strip
    final Paint borderPaint = Paint()..color = GameColors.groundBorder;
    canvas.drawRect(Rect.fromLTWH(0, groundTop, size.width, 2.5), borderPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + grassStripHeight, size.width, 2.5),
      borderPaint,
    );
  }

  void _drawParticles(Canvas canvas) {
    final Paint paint = Paint()..isAntiAlias = false;
    for (final FlapParticle pt in particles) {
      paint.color = pt.color.withValues(alpha: pt.alpha);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(pt.x, pt.y),
          width: pt.size,
          height: pt.size,
        ),
        paint,
      );
    }
  }

  void _drawBird(Canvas canvas) {
    canvas.save();
    canvas.translate(birdX, birdY);
    canvas.rotate(birdAngle);

    final int cols = _birdBodyGrid[0].length;
    final int rows = _birdBodyGrid.length;
    final double px = GamePhysics.birdVisualWidth / cols;
    final double py = GamePhysics.birdVisualHeight / rows;
    final double startX = -GamePhysics.birdVisualWidth / 2;
    final double startY = -GamePhysics.birdVisualHeight / 2;

    final Paint pixelPaint = Paint()..isAntiAlias = false;

    for (int r = 0; r < rows; r++) {
      final String row = _birdBodyGrid[r];
      for (int c = 0; c < cols; c++) {
        final String ch = row[c];
        if (ch == '.') continue;
        switch (ch) {
          case 'K':
            pixelPaint.color = GameColors.birdOutline;
          case 'H':
            pixelPaint.color = GameColors.birdHighlight;
          case 'Y':
            pixelPaint.color = GameColors.birdYellow;
          case 'O':
            pixelPaint.color = GameColors.birdOrange;
          case 'W':
            pixelPaint.color = Colors.white;
          case 'R':
            pixelPaint.color = GameColors.birdBeakTop;
          case 'D':
            pixelPaint.color = GameColors.birdBeakBottom;
          default:
            continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            startX + c * px,
            startY + r * py,
            px + 0.35,
            py + 0.35,
          ),
          pixelPaint,
        );
      }
    }

    // Draw 3-frame animated pixel wing
    final int wingOffsetY = switch (wingFrame % 3) {
      0 => 4, // up
      1 => 5, // mid
      _ => 6, // down
    };
    const List<String> wingGrid = [
      '.KKKKKK.',
      'KWWWWWWK',
      'KSSSSSSK',
      '.KKKKKK.',
    ];
    for (int r = 0; r < wingGrid.length; r++) {
      final String row = wingGrid[r];
      for (int c = 0; c < row.length; c++) {
        final String ch = row[c];
        if (ch == '.') continue;
        pixelPaint.color = switch (ch) {
          'K' => GameColors.birdOutline,
          'W' => GameColors.birdWing,
          _ => GameColors.birdWingShade,
        };
        canvas.drawRect(
          Rect.fromLTWH(
            startX + c * px,
            startY + (wingOffsetY + r) * py,
            px + 0.35,
            py + 0.35,
          ),
          pixelPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FlappyScenePainter oldDelegate) => true;
}
