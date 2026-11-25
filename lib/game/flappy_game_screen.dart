import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'game_config.dart';
import 'game_state.dart';
import 'pixel_sprites.dart';
import 'sfx.dart';

class FlappyGameScreen extends StatefulWidget {
  const FlappyGameScreen({super.key});

  @override
  State<FlappyGameScreen> createState() => _FlappyGameScreenState();
}

class _FlappyGameScreenState extends State<FlappyGameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final FocusNode _focusNode = FocusNode();
  final SoundController _sfx = SoundController();
  final math.Random _rng = math.Random();

  Duration? _lastTick;
  double _elapsedTime = 0.0;
  double _worldScroll = 0.0;

  GamePhase _phase = GamePhase.ready;
  DifficultyMode _difficulty = DifficultyMode.classic;

  Size _viewport = const Size(800, 600);
  double _birdY = 240.0;
  double _birdVelocity = 0.0;
  double _birdAngle = 0.0;
  int _wingFrame = 1;
  double _wingTimer = 0.0;

  int _score = 0;
  int _bestScore = 0;
  bool _isNewBest = false;
  double _gameOverCooldown = 0.0;

  double _flashAlpha = 0.0;
  double _shakeTimer = 0.0;
  Offset _shakeOffset = Offset.zero;

  final List<PipePair> _pipes = [];
  final List<NightStar> _stars = [];
  final List<GhostSprite> _ghosts = [];
  final List<FlapParticle> _particles = [];
  double? _lastGapY;

  @override
  void initState() {
    super.initState();
    _bestScore = _sfx.loadBestScore();
    _initStars();
    _initGhosts();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initStars() {
    _stars.clear();
    const List<Color> palette = [
      Colors.white,
      Color(0xFFAEC6FF),
      Color(0xFFFFE45E),
    ];
    for (int i = 0; i < 48; i++) {
      final bool isSparkle = i % 7 == 0;
      _stars.add(
        NightStar(
          nx: _rng.nextDouble(),
          ny: _rng.nextDouble() * 0.92,
          size: isSparkle ? 3.5 + _rng.nextDouble() * 2.0 : 2.0 + (i % 2),
          color: isSparkle ? const Color(0xFFFFE45E) : palette[i % palette.length],
          isSparkle: isSparkle,
          phase: _rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  void _initGhosts() {
    _ghosts.clear();
    _ghosts.addAll([
      GhostSprite(
        x: 110,
        baseY: 105,
        scale: 1.0,
        phase: 0.4,
        speedFactor: 0.16,
      ),
      GhostSprite(
        x: 135,
        baseY: 380,
        scale: 0.95,
        phase: 2.3,
        speedFactor: 0.19,
      ),
      GhostSprite(
        x: 520,
        baseY: 165,
        scale: 0.85,
        phase: 4.1,
        speedFactor: 0.14,
      ),
    ]);
  }

  double get _groundTop =>
      math.max(220.0, _viewport.height - GamePhysics.groundHeight);

  double get _birdX => (_viewport.width * 0.26).clamp(84.0, 220.0);

  void _onTick(Duration elapsed) {
    final Duration? prev = _lastTick;
    _lastTick = elapsed;
    if (prev == null) {
      return;
    }
    final double rawDt = (elapsed - prev).inMicroseconds / 1000000.0;
    final double dt = rawDt.clamp(0.0, 0.033);

    setState(() {
      _update(dt);
    });
  }

  void _update(double dt) {
    if (_phase == GamePhase.paused) {
      return;
    }

    _elapsedTime += dt;

    if (_flashAlpha > 0) {
      _flashAlpha = math.max(0.0, _flashAlpha - dt * 5.0);
    }

    if (_shakeTimer > 0) {
      _shakeTimer = math.max(0.0, _shakeTimer - dt);
      final double mag = (_shakeTimer / 0.22) * 7.0;
      _shakeOffset = Offset(
        (_rng.nextDouble() * 2 - 1) * mag,
        (_rng.nextDouble() * 2 - 1) * mag,
      );
    } else {
      _shakeOffset = Offset.zero;
    }

    // Update particles regardless of phase
    for (int i = _particles.length - 1; i >= 0; i--) {
      final FlapParticle p = _particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _particles.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 320.0 * dt;
    }

    if (_phase == GamePhase.ready) {
      _worldScroll += _difficulty.pipeSpeed * 0.55 * dt;
      _updateGhosts(_difficulty.pipeSpeed * 0.55, dt);
      _birdY = _groundTop * 0.42 + math.sin(_elapsedTime * 5.2) * 9.0;
      _birdAngle = 0.0;
      _advanceWingAnimation(dt, speed: 9.0);
      return;
    }

    if (_phase == GamePhase.playing) {
      final double speed = _difficulty.pipeSpeed;
      _worldScroll += speed * dt;
      _updateGhosts(speed, dt);
      _advanceWingAnimation(dt, speed: _birdVelocity < 0 ? 15.0 : 8.0);

      // Bird physics
      _birdVelocity = math.min(
        GamePhysics.maxFallSpeed,
        _birdVelocity + GamePhysics.gravity * dt,
      );
      _birdY += _birdVelocity * dt;

      // Ceiling clamp
      const double minY = GamePhysics.birdHitRadius + 6.0;
      if (_birdY < minY) {
        _birdY = minY;
        if (_birdVelocity < 0) {
          _birdVelocity = 0;
        }
      }

      // Smooth arcade pitch tilt
      if (_birdVelocity < 90) {
        _birdAngle = (_birdAngle - dt * 6.5).clamp(-0.44, 1.35);
      } else {
        final double fallRatio =
            ((_birdVelocity - 90) / (GamePhysics.maxFallSpeed - 90))
                .clamp(0.0, 1.0);
        final double targetAngle = -0.15 + fallRatio * 1.48;
        _birdAngle += (targetAngle - _birdAngle) * math.min(1.0, dt * 8.0);
      }

      // Move pipes & score
      for (final PipePair pipe in _pipes) {
        pipe.x -= speed * dt;
        if (!pipe.passed && pipe.x + GamePhysics.pipeWidth / 2 < _birdX) {
          pipe.passed = true;
          _score += 1;
          if (_score > _bestScore) {
            _bestScore = _score;
            _isNewBest = true;
            _sfx.saveBestScore(_bestScore);
          }
          _sfx.play(GameSfx.score);
        }
      }

      _pipes.removeWhere((p) => p.x < -GamePhysics.pipeWidth - 30);

      // Spawn new pipes cleanly based on spacing
      if (_pipes.isEmpty) {
        _spawnPipe(math.max(_viewport.width + 60, _birdX + 340));
      } else {
        final double rightmostX = _pipes.last.x;
        if (rightmostX < _viewport.width - _difficulty.pipeSpacing + 90) {
          _spawnPipe(rightmostX + _difficulty.pipeSpacing);
        }
      }

      // Collision checks
      if (_checkCollisions()) {
        _triggerCrash();
      }
      return;
    }

    if (_phase == GamePhase.dying) {
      _birdVelocity = math.min(
        GamePhysics.maxFallSpeed * 1.25,
        _birdVelocity + GamePhysics.gravity * 1.15 * dt,
      );
      _birdY += _birdVelocity * dt;
      _birdAngle = math.min(1.48, _birdAngle + dt * 5.2);

      final double floorY = _groundTop - GamePhysics.birdHitRadius;
      if (_birdY >= floorY) {
        _birdY = floorY;
        _phase = GamePhase.gameOver;
        _gameOverCooldown = 0.35;
      }
      return;
    }

    if (_phase == GamePhase.gameOver && _gameOverCooldown > 0) {
      _gameOverCooldown = math.max(0.0, _gameOverCooldown - dt);
    }
  }

  void _advanceWingAnimation(double dt, {required double speed}) {
    _wingTimer += dt * speed;
    if (_wingTimer >= 1.0) {
      _wingTimer = 0.0;
      _wingFrame = (_wingFrame + 1) % 3;
    }
  }

  void _updateGhosts(double worldSpeed, double dt) {
    final double w = math.max(360.0, _viewport.width);
    for (final GhostSprite ghost in _ghosts) {
      ghost.x -= worldSpeed * ghost.speedFactor * dt;
      if (ghost.x < -60) {
        ghost.x = w + 50 + _rng.nextDouble() * 90;
        ghost.baseY = 65 + _rng.nextDouble() * math.max(120.0, _groundTop - 160);
      }
    }
  }

  void _spawnPipe(double x) {
    final double gap = _difficulty.pipeGap;
    final double margin = 62.0 + gap / 2;
    final double minY = margin;
    final double maxY = math.max(minY + 10.0, _groundTop - margin);

    double gapY;
    if (_lastGapY == null) {
      gapY = minY + _rng.nextDouble() * (maxY - minY);
    } else {
      const double maxDelta = 165.0;
      final double lo = math.max(minY, _lastGapY! - maxDelta);
      final double hi = math.min(maxY, _lastGapY! + maxDelta);
      gapY = lo + _rng.nextDouble() * math.max(1.0, hi - lo);
    }
    _lastGapY = gapY;

    _pipes.add(
      PipePair(
        x: x,
        gapCenterY: gapY,
        gapHeight: gap,
      ),
    );
  }

  bool _checkCollisions() {
    final double bx = _birdX;
    final double by = _birdY;
    const double r = GamePhysics.birdHitRadius;

    // Ground collision
    if (by + r >= _groundTop) {
      return true;
    }

    // Pipe collisions (shaft + overhanging cap)
    for (final PipePair pipe in _pipes) {
      if (pipe.x - GamePhysics.pipeCapOverhang > bx + r ||
          pipe.x + GamePhysics.pipeWidth + GamePhysics.pipeCapOverhang <
              bx - r) {
        continue;
      }

      // Top pipe shaft + cap
      if (pipe.topPipeBottom > 0) {
        final Rect topShaft = Rect.fromLTWH(
          pipe.x,
          -200,
          GamePhysics.pipeWidth,
          pipe.topPipeBottom + 200,
        );
        final Rect topCap = Rect.fromLTWH(
          pipe.x - GamePhysics.pipeCapOverhang,
          pipe.topPipeBottom - GamePhysics.pipeCapHeight,
          GamePhysics.pipeWidth + GamePhysics.pipeCapOverhang * 2,
          GamePhysics.pipeCapHeight,
        );
        if (_circleIntersectsRect(bx, by, r, topShaft) ||
            _circleIntersectsRect(bx, by, r, topCap)) {
          return true;
        }
      }

      // Bottom pipe shaft + cap
      if (pipe.bottomPipeTop < _groundTop) {
        final Rect bottomShaft = Rect.fromLTWH(
          pipe.x,
          pipe.bottomPipeTop,
          GamePhysics.pipeWidth,
          _groundTop - pipe.bottomPipeTop,
        );
        final Rect bottomCap = Rect.fromLTWH(
          pipe.x - GamePhysics.pipeCapOverhang,
          pipe.bottomPipeTop,
          GamePhysics.pipeWidth + GamePhysics.pipeCapOverhang * 2,
          GamePhysics.pipeCapHeight,
        );
        if (_circleIntersectsRect(bx, by, r, bottomShaft) ||
            _circleIntersectsRect(bx, by, r, bottomCap)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _circleIntersectsRect(double cx, double cy, double r, Rect rect) {
    final double closestX = cx.clamp(rect.left, rect.right);
    final double closestY = cy.clamp(rect.top, rect.bottom);
    final double dx = cx - closestX;
    final double dy = cy - closestY;
    return (dx * dx + dy * dy) < (r * r);
  }

  void _triggerCrash() {
    _sfx.play(GameSfx.hit);
    _flashAlpha = 0.78;
    _shakeTimer = 0.22;

    for (int i = 0; i < 12; i++) {
      final double angle = _rng.nextDouble() * math.pi * 2;
      final double spd = 70 + _rng.nextDouble() * 170;
      _particles.add(
        FlapParticle(
          x: _birdX,
          y: _birdY,
          vx: math.cos(angle) * spd,
          vy: math.sin(angle) * spd - 60,
          size: 4 + _rng.nextDouble() * 4,
          life: 0.45 + _rng.nextDouble() * 0.25,
          maxLife: 0.7,
          color: i.isEven ? GameColors.birdYellow : Colors.white,
        ),
      );
    }

    final double floorY = _groundTop - GamePhysics.birdHitRadius;
    if (_birdY >= floorY - 2) {
      _birdY = floorY;
      _phase = GamePhase.gameOver;
      _gameOverCooldown = 0.35;
    } else {
      _birdVelocity = -120.0;
      _phase = GamePhase.dying;
      _sfx.play(GameSfx.die);
    }
  }

  void _flap() {
    if (_phase == GamePhase.paused || _phase == GamePhase.dying) return;

    if (_phase == GamePhase.gameOver) {
      if (_gameOverCooldown <= 0) {
        _resetToReady();
      }
      return;
    }

    setState(() {
      if (_phase == GamePhase.ready) {
        _phase = GamePhase.playing;
        _score = 0;
        _isNewBest = false;
        _pipes.clear();
        _lastGapY = null;
        _spawnPipe(math.max(_viewport.width * 0.85, _birdX + 340));
      }

      _birdVelocity = GamePhysics.flapVelocity;
      _birdAngle = -0.44;
      _wingFrame = 0;
      _wingTimer = 0.0;

      // Subtle puff particles under wing
      for (int i = 0; i < 4; i++) {
        _particles.add(
          FlapParticle(
            x: _birdX - 16 + (_rng.nextDouble() * 8 - 4),
            y: _birdY + 8 + (_rng.nextDouble() * 6 - 3),
            vx: -60 - _rng.nextDouble() * 50,
            vy: 40 + _rng.nextDouble() * 60,
            size: 3.5 + _rng.nextDouble() * 2.5,
            life: 0.28,
            maxLife: 0.28,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        );
      }
    });
    _sfx.play(GameSfx.flap);
  }

  void _resetToReady() {
    _sfx.play(GameSfx.swoosh);
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _isNewBest = false;
      _pipes.clear();
      _particles.clear();
      _lastGapY = null;
      _birdVelocity = 0.0;
      _birdAngle = 0.0;
      _birdY = _groundTop * 0.42;
      _flashAlpha = 0.0;
      _shakeTimer = 0.0;
    });
    _focusNode.requestFocus();
  }

  void _togglePause() {
    if (_phase == GamePhase.playing) {
      setState(() => _phase = GamePhase.paused);
    } else if (_phase == GamePhase.paused) {
      setState(() {
        _phase = GamePhase.playing;
        _lastTick = null;
      });
    }
    _focusNode.requestFocus();
  }

  void _toggleMute() {
    setState(() {
      _sfx.muted = !_sfx.muted;
    });
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      if (_phase == GamePhase.gameOver && _gameOverCooldown <= 0) {
        _resetToReady();
      } else {
        _flap();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyP || key == LogicalKeyboardKey.escape) {
      if (_phase == GamePhase.playing || _phase == GamePhase.paused) {
        _togglePause();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.keyR || key == LogicalKeyboardKey.enter) {
      if (_phase == GamePhase.gameOver || _phase == GamePhase.paused) {
        _resetToReady();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.skyTop,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            _viewport = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Playfield canvas with instant zero-latency pointer-down response
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    _focusNode.requestFocus();
                    _flap();
                  },
                  child: CustomPaint(
                    size: _viewport,
                    painter: FlappyScenePainter(
                      elapsedTime: _elapsedTime,
                      worldScroll: _worldScroll,
                      birdX: _birdX,
                      birdY: _birdY,
                      birdAngle: _birdAngle,
                      wingFrame: _wingFrame,
                      pipes: _pipes,
                      stars: _stars,
                      ghosts: _ghosts,
                      particles: _particles,
                      flashAlpha: _flashAlpha,
                      shakeOffset: _shakeOffset,
                    ),
                  ),
                ),

                // Top-center live score (matching screenshot counter)
                if (_phase == GamePhase.playing ||
                    _phase == GamePhase.dying ||
                    _phase == GamePhase.paused)
                  Positioned(
                    top: 26,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: _OutlinedText(
                          text: '$_score',
                          fontSize: 54,
                          strokeWidth: 7,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Top-right HUD controls (Audio + Pause)
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HudIconButton(
                          tooltip: _sfx.muted ? 'Unmute Sound' : 'Mute Sound',
                          icon: _sfx.muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          onPressed: _toggleMute,
                        ),
                        if (_phase == GamePhase.playing ||
                            _phase == GamePhase.paused) ...[
                          const SizedBox(width: 8),
                          _HudIconButton(
                            tooltip:
                                _phase == GamePhase.paused ? 'Resume' : 'Pause',
                            icon: _phase == GamePhase.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            onPressed: _togglePause,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Ready / Title Overlay
                if (_phase == GamePhase.ready) _buildReadyOverlay(),

                // Paused Overlay
                if (_phase == GamePhase.paused) _buildPausedOverlay(),

                // Game Over Scoreboard Overlay
                if (_phase == GamePhase.gameOver) _buildGameOverOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadyOverlay() {
    return SafeArea(
      child: Stack(
        children: [
          // Title Banner above bird
          Positioned(
            top: math.max(24.0, _groundTop * 0.12),
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _OutlinedText(
                    text: 'FLAPPY BIRD',
                    fontSize: 44,
                    strokeWidth: 7,
                    fillColor: Color(0xFFF8F9FA),
                  ),
                  if (_bestScore > 0) ...[
                    const SizedBox(height: 6),
                    _OutlinedText(
                      text: 'BEST $_bestScore',
                      fontSize: 18,
                      strokeWidth: 4,
                      fillColor: GameColors.accentGold,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Prompt & Difficulty selector below bird
          Positioned(
            bottom: GamePhysics.groundHeight + 28,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF142042).withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: const Text(
                      'TAP OR PRESS SPACE TO FLY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _DifficultySelector(
                  selected: _difficulty,
                  onSelected: (DifficultyMode mode) {
                    _sfx.play(GameSfx.swoosh);
                    setState(() {
                      _difficulty = mode;
                    });
                    _focusNode.requestFocus();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: _RetroPanel(
        width: 290,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _OutlinedText(
              text: 'PAUSED',
              fontSize: 30,
              strokeWidth: 5,
              fillColor: Colors.white,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _RetroButton(
                    label: 'RESUME',
                    color: GameColors.pipeMain,
                    onPressed: _togglePause,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RetroButton(
                    label: 'RESTART',
                    color: GameColors.accentOrange,
                    onPressed: _resetToReady,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final MedalTier medal = MedalTier.fromScore(_score);
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _OutlinedText(
            text: 'GAME OVER',
            fontSize: 42,
            strokeWidth: 7,
            fillColor: Color(0xFFFFA036),
          ),
          const SizedBox(height: 18),
          _RetroPanel(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Medal slot
                    Column(
                      children: [
                        const Text(
                          'MEDAL',
                          style: TextStyle(
                            color: Color(0xFF9E6B43),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MedalBadge(tier: medal),
                        const SizedBox(height: 6),
                        Text(
                          medal == MedalTier.none ? '—' : medal.label,
                          style: const TextStyle(
                            color: GameColors.panelBorder,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // Score & Best columns
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'SCORE',
                            style: TextStyle(
                              color: Color(0xFF9E6B43),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _OutlinedText(
                            text: '$_score',
                            fontSize: 30,
                            strokeWidth: 4.5,
                            fillColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_isNewBest)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE03A24),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              const Text(
                                'BEST',
                                style: TextStyle(
                                  color: Color(0xFF9E6B43),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          _OutlinedText(
                            text: '$_bestScore',
                            fontSize: 30,
                            strokeWidth: 4.5,
                            fillColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            child: _RetroButton(
              label: 'PLAY AGAIN',
              color: GameColors.accentOrange,
              onPressed: _resetToReady,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText({
    required this.text,
    required this.fontSize,
    required this.strokeWidth,
    required this.fillColor,
  });

  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      height: 1.05,
    );

    return Stack(
      children: [
        // Drop shadow
        Transform.translate(
          offset: const Offset(0, 3),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF0A0F1F).withValues(alpha: 0.75),
            ),
          ),
        ),
        // Crisp black outline
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF141414),
          ),
        ),
        // Fill
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(color: fillColor),
        ),
      ],
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF142042).withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({
    required this.selected,
    required this.onSelected,
  });

  final DifficultyMode selected;
  final ValueChanged<DifficultyMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF142042).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DifficultyMode.values.map((DifficultyMode mode) {
          final bool active = mode == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: active ? GameColors.accentGold : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                onTap: () => onSelected(mode),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40, minWidth: 74),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    mode.label.toUpperCase(),
                    style: TextStyle(
                      color: active ? const Color(0xFF141414) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RetroPanel extends StatelessWidget {
  const _RetroPanel({
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GameColors.panelBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: GameColors.panelBorder,
          width: 3.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RetroButton extends StatelessWidget {
  const _RetroButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF141414),
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalBadge extends StatelessWidget {
  const _MedalBadge({required this.tier});

  final MedalTier tier;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color shine;
    switch (tier) {
      case MedalTier.none:
        fill = GameColors.panelInner;
        shine = GameColors.panelInner;
      case MedalTier.bronze:
        fill = const Color(0xFFCD7F32);
        shine = const Color(0xFFE7A96D);
      case MedalTier.silver:
        fill = const Color(0xFFC0C8D4);
        shine = const Color(0xFFF0F4F8);
      case MedalTier.gold:
        fill = const Color(0xFFF8C61E);
        shine = const Color(0xFFFFF099);
      case MedalTier.platinum:
        fill = const Color(0xFF9BE7FF);
        shine = Colors.white;
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(
          color: tier == MedalTier.none
              ? const Color(0xFFB5AA64)
              : const Color(0xFF543847),
          width: 3,
        ),
        gradient: tier == MedalTier.none
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [shine, fill],
              ),
      ),
      child: tier == MedalTier.none
          ? null
          : const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 32,
            ),
    );
  }
}
