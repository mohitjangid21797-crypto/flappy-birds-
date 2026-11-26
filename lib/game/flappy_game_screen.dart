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

  GameMode? _selectedMode;
  GameMode get _mode => _selectedMode ?? GameMode.heartRun;
  set _mode(GameMode value) => _selectedMode = value;

  BirdSkin? _selectedSkin;
  BirdSkin get _birdSkin => _selectedSkin ?? BirdSkin.skyCap;
  set _birdSkin(BirdSkin value) => _selectedSkin = value;

  Size _viewport = const Size(800, 600);
  double _birdY = 240.0;
  double _birdVelocity = 0.0;
  double _birdAngle = 0.0;

  double? _wingPhaseVal;
  double get _wingPhase => _wingPhaseVal ?? 0.0;
  set _wingPhase(double value) => _wingPhaseVal = value;

  double? _flapSquashVal;
  double get _flapSquash => _flapSquashVal ?? 0.0;
  set _flapSquash(double value) => _flapSquashVal = value;

  double? _hatBounceVal;
  double get _hatBounce => _hatBounceVal ?? 0.0;
  set _hatBounce(double value) => _hatBounceVal = value;

  double? _scorePopVal;
  double get _scorePop => _scorePopVal ?? 0.0;
  set _scorePop(double value) => _scorePopVal = value;

  int _score = 0;
  int _bestScore = 0;

  int? _heartsRemainingVal;
  int get _heartsRemaining => _heartsRemainingVal ?? 1;
  set _heartsRemaining(int value) => _heartsRemainingVal = value;

  int? _heartsCollectedVal;
  int get _heartsCollected => _heartsCollectedVal ?? 0;
  set _heartsCollected(int value) => _heartsCollectedVal = value;

  int? _pipesSpawnedVal;
  int get _pipesSpawnedCount => _pipesSpawnedVal ?? 0;
  set _pipesSpawnedCount(int value) => _pipesSpawnedVal = value;

  bool _isNewBest = false;

  double? _invulnTimerVal;
  double get _invulnTimer => _invulnTimerVal ?? 0.0;
  set _invulnTimer(double value) => _invulnTimerVal = value;

  double _gameOverCooldown = 0.0;
  double _flashAlpha = 0.0;
  double _shakeTimer = 0.0;
  Offset _shakeOffset = Offset.zero;

  final List<PipePair> _pipes = [];
  List<HeartPickup>? _heartsList;
  List<HeartPickup> get _hearts => _heartsList ??= <HeartPickup>[];

  List<SkyCloud>? _cloudsList;
  List<SkyCloud> get _clouds => _cloudsList ??= _createDefaultClouds();

  final List<FlapParticle> _particles = [];
  List<FloatingFeedback>? _feedbacksList;
  List<FloatingFeedback> get _feedbacks =>
      _feedbacksList ??= <FloatingFeedback>[];

  double? _lastGapY;

  double? _trailEmitAccumVal;
  double get _trailEmitAccum => _trailEmitAccumVal ?? 0.0;
  set _trailEmitAccum(double value) => _trailEmitAccumVal = value;

  @override
  void initState() {
    super.initState();
    _bestScore = _sfx.loadBestScore();
    _cloudsList = _createDefaultClouds();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<SkyCloud> _createDefaultClouds() {
    return [
      SkyCloud(x: 160, y: 110, scale: 1.05, speedFactor: 0.14),
      SkyCloud(x: 470, y: 82, scale: 0.85, speedFactor: 0.10),
      SkyCloud(x: 780, y: 132, scale: 1.15, speedFactor: 0.16),
    ];
  }

  double get _groundTop =>
      math.max(220.0, _viewport.height - GamePhysics.groundHeight);

  double get _birdX => (_viewport.width * 0.26).clamp(84.0, 220.0);

  double get _baseSpeed => _mode.pipeSpeed;

  double get _pipeSpacing => _mode.pipeSpacing;

  double get _currentSpeed {
    if (!_mode.accelerates) return _baseSpeed;
    return _baseSpeed + math.min(120.0, _score * 4.0);
  }

  double get _speedMultiplier => _currentSpeed / _baseSpeed;

  void _onTick(Duration elapsed) {
    final Duration? prev = _lastTick;
    _lastTick = elapsed;
    if (prev == null) return;

    final double rawDt = (elapsed - prev).inMicroseconds / 1000000.0;
    final double dt = rawDt.clamp(0.0, 0.033);

    setState(() {
      _update(dt);
    });
  }

  void _update(double dt) {
    if (_phase == GamePhase.paused) return;

    _elapsedTime += dt;

    if (_invulnTimer > 0) {
      _invulnTimer = math.max(0.0, _invulnTimer - dt);
    }

    if (_flapSquash > 0) {
      _flapSquash = math.max(0.0, _flapSquash - dt * 5.2);
    }

    if (_hatBounce > 0) {
      _hatBounce = math.max(0.0, _hatBounce - dt * 4.0);
    }

    if (_scorePop > 0) {
      _scorePop = math.max(0.0, _scorePop - dt * 4.5);
    }

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

    for (int i = _particles.length - 1; i >= 0; i--) {
      final FlapParticle p = _particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        _particles.removeAt(i);
        continue;
      }
      if (p.drag > 0) {
        final double damp = math.exp(-p.drag * dt);
        p.vx *= damp;
        p.vy *= damp;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.gravity * dt;
      if (p.spin != 0) {
        p.rotation += p.spin * dt;
      }
    }
    if (_particles.length > 200) {
      _particles.removeRange(0, _particles.length - 200);
    }

    for (int i = _feedbacks.length - 1; i >= 0; i--) {
      final FloatingFeedback fb = _feedbacks[i];
      fb.life -= dt;
      if (fb.life <= 0) {
        _feedbacks.removeAt(i);
        continue;
      }
      fb.y -= 42.0 * dt;
    }

    if (_phase == GamePhase.ready) {
      final double idleSpeed = _baseSpeed * 0.52;
      _worldScroll += idleSpeed * dt;
      _updateClouds(idleSpeed, dt);
      _birdY = _groundTop * 0.40 + math.sin(_elapsedTime * 5.0) * 9.0;
      _birdAngle = math.cos(_elapsedTime * 5.0) * 0.06;
      _wingPhase += dt * 11.0;
      return;
    }

    if (_phase == GamePhase.playing) {
      final double speed = _currentSpeed;
      _worldScroll += speed * dt;
      _updateClouds(speed, dt);
      _wingPhase += dt * (_birdVelocity < 0 ? 22.0 : 12.0);

      final double prevY = _birdY;
      _birdVelocity = math.min(
        GamePhysics.maxFallSpeed,
        _birdVelocity + GamePhysics.gravity * dt,
      );
      _birdY += _birdVelocity * dt;

      const double minY = GamePhysics.birdHitRadius + 6.0;
      if (_birdY < minY) {
        _birdY = minY;
        if (_birdVelocity < 0) {
          _birdVelocity = 0;
        }
      }

      // Persistent fading slipstream trail whenever the bird changes altitude
      final double altitudeChange = (_birdY - prevY).abs();
      final double verticalSpeed = _birdVelocity.abs();
      if (altitudeChange > 0.2 || verticalSpeed > 32.0) {
        final double emitRate = 24.0 + math.min(36.0, verticalSpeed * 0.085);
        _trailEmitAccum += dt * emitRate;
        final bool climbing = _birdVelocity < 0;
        while (_trailEmitAccum >= 1.0) {
          _trailEmitAccum -= 1.0;
          final double life = climbing
              ? 0.56 + _rng.nextDouble() * 0.16
              : 0.46 + _rng.nextDouble() * 0.14;
          final double tailOffsetX = -17.0 + (_rng.nextDouble() * 4.0 - 2.0);
          final double tailOffsetY =
              (climbing ? 4.0 : -1.0) + (_rng.nextDouble() * 6.0 - 3.0);
          _particles.add(
            FlapParticle(
              x: _birdX + tailOffsetX,
              y: _birdY + tailOffsetY,
              vx: -speed * (0.88 + _rng.nextDouble() * 0.14),
              vy: -_birdVelocity * 0.06 + (_rng.nextDouble() * 24.0 - 12.0),
              size: (climbing ? 5.2 : 4.2) +
                  math.min(2.8, verticalSpeed * 0.004) +
                  _rng.nextDouble() * 1.6,
              life: life,
              maxLife: life,
              color: climbing
                  ? (_rng.nextDouble() < 0.55
                      ? Colors.white.withValues(alpha: 0.9)
                      : _birdSkin.primaryLight)
                  : (_rng.nextDouble() < 0.65
                      ? _birdSkin.primaryLight
                      : Colors.white.withValues(alpha: 0.82)),
              kind: ParticleKind.trail,
              gravity: climbing ? 22.0 : -10.0,
              drag: 0.9,
            ),
          );

          if (verticalSpeed > 260.0 && _rng.nextDouble() < 0.24) {
            final double fLife = 0.5 + _rng.nextDouble() * 0.18;
            _particles.add(
              FlapParticle(
                x: _birdX - 18.0,
                y: _birdY + (_rng.nextDouble() * 8.0 - 4.0),
                vx: -speed * (0.76 + _rng.nextDouble() * 0.18),
                vy: -_birdVelocity * 0.1 + (_rng.nextDouble() * 34.0 - 17.0),
                size: 3.6 + _rng.nextDouble() * 1.8,
                life: fLife,
                maxLife: fLife,
                color: _birdSkin.primaryMid,
                kind: ParticleKind.feather,
                gravity: 40.0,
                drag: 1.0,
                rotation: _rng.nextDouble() * math.pi * 2,
                spin: (_rng.nextDouble() - 0.5) * 8.0,
              ),
            );
          }
        }
      }

      if (_birdVelocity < 90) {
        _birdAngle = (_birdAngle - dt * 6.5).clamp(-0.42, 1.32);
      } else {
        final double fallRatio =
            ((_birdVelocity - 90) / (GamePhysics.maxFallSpeed - 90))
                .clamp(0.0, 1.0);
        final double targetAngle = -0.14 + fallRatio * 1.44;
        _birdAngle += (targetAngle - _birdAngle) * math.min(1.0, dt * 8.0);
      }

      for (final PipePair pipe in _pipes) {
        pipe.x -= speed * dt;
        if (!pipe.passed && pipe.x + GamePhysics.pipeWidth / 2 < _birdX) {
          pipe.passed = true;
          _incrementScore(1);
          _sfx.play(GameSfx.score);
        }
      }
      _pipes.removeWhere((p) => p.x < -GamePhysics.pipeWidth - 40);

      for (final HeartPickup heart in _hearts) {
        heart.x -= speed * dt;
        if (!heart.collected) {
          final double hy =
              heart.baseY + math.sin(_elapsedTime * 4.2 + heart.phase) * 6.0;
          final double dx = heart.x - _birdX;
          final double dy = hy - _birdY;
          if (dx * dx + dy * dy <= 33 * 33) {
            _collectHeart(heart, hy);
          }
        }
      }
      _hearts.removeWhere((h) => h.collected || h.x < -40);

      if (_pipes.isEmpty) {
        _spawnPipe(math.max(_viewport.width + 60, _birdX + 340));
      } else {
        final double rightmostX = _pipes.last.x;
        if (rightmostX < _viewport.width - _pipeSpacing + 90) {
          _spawnPipe(rightmostX + _pipeSpacing);
        }
      }

      if (_birdY + GamePhysics.birdHitRadius >= _groundTop) {
        if (_mode.heartsEnabled && _heartsRemaining > 0 && _invulnTimer <= 0) {
          _consumeShield(fromGround: true);
        } else {
          _triggerCrash(hitGround: true);
        }
        return;
      }

      if (_invulnTimer <= 0 && _checkPipeCollision()) {
        if (_mode.heartsEnabled && _heartsRemaining > 0) {
          _consumeShield(fromGround: false);
        } else {
          _triggerCrash(hitGround: false);
        }
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

      _trailEmitAccum += dt * 26.0;
      while (_trailEmitAccum >= 1.0) {
        _trailEmitAccum -= 1.0;
        final double life = 0.42 + _rng.nextDouble() * 0.14;
        _particles.add(
          FlapParticle(
            x: _birdX + (_rng.nextDouble() * 10.0 - 5.0),
            y: _birdY - 6.0 + (_rng.nextDouble() * 6.0 - 3.0),
            vx: -55.0 + (_rng.nextDouble() * 50.0 - 25.0),
            vy: -65.0 - _rng.nextDouble() * 45.0,
            size: 4.5 + _rng.nextDouble() * 2.5,
            life: life,
            maxLife: life,
            color: _rng.nextBool() ? _birdSkin.primaryLight : Colors.white,
            kind: ParticleKind.trail,
            gravity: 25.0,
            drag: 1.5,
          ),
        );
      }

      final double floorY = _groundTop - GamePhysics.birdHitRadius;
      if (_birdY >= floorY) {
        _birdY = floorY;
        _finalizeGameOver();
      }
      return;
    }

    if (_phase == GamePhase.gameOver && _gameOverCooldown > 0) {
      _gameOverCooldown = math.max(0.0, _gameOverCooldown - dt);
    }
  }

  void _finalizeGameOver() {
    _phase = GamePhase.gameOver;
    _gameOverCooldown = 0.35;
  }

  void _incrementScore(int points) {
    _score += points;
    _scorePop = 1.0;
    if (_score > _bestScore) {
      _bestScore = _score;
      _isNewBest = true;
      _sfx.saveBestScore(_bestScore);
    }
  }

  void _collectHeart(HeartPickup heart, double hy) {
    heart.collected = true;
    _heartsCollected += 1;
    _sfx.play(GameSfx.heart);

    if (_heartsRemaining < GamePhysics.maxHearts) {
      _heartsRemaining += 1;
      _feedbacks.add(
        FloatingFeedback(
          x: heart.x,
          y: hy - 14,
          text: '+1 LIFE ♥',
          color: GameColors.heartRed,
          life: 0.95,
          maxLife: 0.95,
        ),
      );
    } else {
      _incrementScore(2);
      _feedbacks.add(
        FloatingFeedback(
          x: heart.x,
          y: hy - 14,
          text: '+2 BONUS',
          color: GameColors.accentGold,
          life: 0.95,
          maxLife: 0.95,
        ),
      );
    }

    for (int i = 0; i < 12; i++) {
      final double a = (math.pi * 2 / 12) * i;
      final double spd = 70 + _rng.nextDouble() * 85;
      _particles.add(
        FlapParticle(
          x: heart.x,
          y: hy,
          vx: math.cos(a) * spd,
          vy: math.sin(a) * spd - 30,
          size: 5 + _rng.nextDouble() * 3,
          life: 0.45,
          maxLife: 0.45,
          color: i.isEven ? GameColors.heartBright : Colors.white,
        ),
      );
    }
  }

  void _consumeShield({required bool fromGround}) {
    _heartsRemaining = math.max(0, _heartsRemaining - 1);
    _invulnTimer = 1.35;
    _flashAlpha = 0.45;
    _shakeTimer = 0.16;
    _sfx.play(GameSfx.shield);

    if (fromGround) {
      _birdY = _groundTop - GamePhysics.birdHitRadius - 12;
      _birdVelocity = GamePhysics.flapVelocity * 0.95;
      _birdAngle = -0.35;
    }

    _feedbacks.add(
      FloatingFeedback(
        x: _birdX,
        y: _birdY - 26,
        text: 'SHIELD!',
        color: GameColors.brandNavy,
        life: 0.95,
        maxLife: 0.95,
      ),
    );

    for (int i = 0; i < 12; i++) {
      final double a = (math.pi * 2 / 12) * i;
      _particles.add(
        FlapParticle(
          x: _birdX,
          y: _birdY,
          vx: math.cos(a) * 120,
          vy: math.sin(a) * 120,
          size: 5,
          life: 0.4,
          maxLife: 0.4,
          color: i.isEven ? GameColors.heartBright : _birdSkin.primaryLight,
        ),
      );
    }
  }

  void _updateClouds(double speed, double dt) {
    final double w = math.max(420.0, _viewport.width);
    for (final SkyCloud cloud in _clouds) {
      cloud.x -= speed * cloud.speedFactor * dt;
      if (cloud.x < -140) {
        cloud.x = w + 140 + _rng.nextDouble() * 80;
        cloud.y = 68 + _rng.nextDouble() * 88;
      }
    }
  }

  void _spawnPipe(double x) {
    _pipesSpawnedCount += 1;

    final ObstacleKind kind;
    if (_pipesSpawnedCount >= 3 && _pipesSpawnedCount % 3 == 0) {
      kind = ObstacleKind.hoverPropellerGate;
    } else if (_pipesSpawnedCount >= 4 && _pipesSpawnedCount % 4 == 0) {
      kind = ObstacleKind.beaconTower;
    } else {
      kind = ObstacleKind.emeraldCylinder;
    }

    final double hoverAmplitude =
        kind == ObstacleKind.hoverPropellerGate ? 20.0 : 0.0;
    final double gap = _mode.pipeGap;
    final double margin = 68.0 + gap / 2 + hoverAmplitude;
    final double minY = margin;
    final double maxY = math.max(minY + 10.0, _groundTop - margin);

    double gapY;
    if (_lastGapY == null) {
      gapY = minY + _rng.nextDouble() * (maxY - minY);
    } else {
      const double maxDelta = 155.0;
      final double lo = math.max(minY, _lastGapY! - maxDelta);
      final double hi = math.min(maxY, _lastGapY! + maxDelta);
      gapY = lo + _rng.nextDouble() * math.max(1.0, hi - lo);
    }
    _lastGapY = gapY;

    final double phase = _rng.nextDouble() * math.pi * 2;
    _pipes.add(
      PipePair(
        x: x,
        baseGapCenterY: gapY,
        gapHeight: gap,
        kind: kind,
        hoverAmplitude: hoverAmplitude,
        hoverSpeed: 2.2,
        phase: phase,
      ),
    );

    if (_mode.heartsEnabled && _pipesSpawnedCount % 2 == 1) {
      _hearts.add(
        HeartPickup(
          x: x + GamePhysics.pipeWidth / 2,
          baseY: gapY,
          phase: _rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  bool _checkPipeCollision() {
    final double bx = _birdX;
    final double by = _birdY;
    const double r = GamePhysics.birdHitRadius;

    for (final PipePair pipe in _pipes) {
      if (pipe.x - GamePhysics.pipeCapOverhang > bx + r ||
          pipe.x + GamePhysics.pipeWidth + GamePhysics.pipeCapOverhang <
              bx - r) {
        continue;
      }

      final double topBottom = pipe.topPipeBottomAt(_elapsedTime);
      final double bottomTop = pipe.bottomPipeTopAt(_elapsedTime);

      if (topBottom > 0) {
        final Rect topShaft = Rect.fromLTWH(
          pipe.x,
          -220,
          GamePhysics.pipeWidth,
          topBottom + 220,
        );
        final Rect topCap = Rect.fromLTWH(
          pipe.x - GamePhysics.pipeCapOverhang,
          topBottom - GamePhysics.pipeCapHeight,
          GamePhysics.pipeWidth + GamePhysics.pipeCapOverhang * 2,
          GamePhysics.pipeCapHeight,
        );
        if (_circleIntersectsRect(bx, by, r, topShaft) ||
            _circleIntersectsRect(bx, by, r, topCap)) {
          return true;
        }
      }

      if (bottomTop < _groundTop) {
        final Rect bottomShaft = Rect.fromLTWH(
          pipe.x,
          bottomTop,
          GamePhysics.pipeWidth,
          _groundTop - bottomTop,
        );
        final Rect bottomCap = Rect.fromLTWH(
          pipe.x - GamePhysics.pipeCapOverhang,
          bottomTop,
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

  void _triggerCrash({required bool hitGround}) {
    _sfx.play(GameSfx.hit);
    _flashAlpha = 0.72;
    _shakeTimer = 0.22;

    for (int i = 0; i < 14; i++) {
      final double angle = _rng.nextDouble() * math.pi * 2;
      final double spd = 75 + _rng.nextDouble() * 170;
      _particles.add(
        FlapParticle(
          x: _birdX,
          y: _birdY,
          vx: math.cos(angle) * spd,
          vy: math.sin(angle) * spd - 60,
          size: 4.5 + _rng.nextDouble() * 4,
          life: 0.45 + _rng.nextDouble() * 0.25,
          maxLife: 0.7,
          color: i.isEven ? _birdSkin.primaryMid : _birdSkin.hatCrown,
        ),
      );
    }

    final double floorY = _groundTop - GamePhysics.birdHitRadius;
    if (hitGround || _birdY >= floorY - 2) {
      _birdY = floorY;
      _finalizeGameOver();
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
        _startNewRunImmediately();
      }
      return;
    }

    setState(() {
      if (_phase == GamePhase.ready) {
        _phase = GamePhase.playing;
        _score = 0;
        _heartsCollected = 0;
        _heartsRemaining = _mode.heartsEnabled ? 1 : 0;
        _pipesSpawnedCount = 0;
        _invulnTimer = 0.0;
        _isNewBest = false;
        _pipes.clear();
        _hearts.clear();
        _feedbacks.clear();
        _lastGapY = null;
        _trailEmitAccum = 0.0;
        _spawnPipe(math.max(_viewport.width * 0.85, _birdX + 340));
      }

      _birdVelocity = GamePhysics.flapVelocity;
      _birdAngle = -0.42;
      _flapSquash = 1.0;
      _hatBounce = 1.0;

      final double worldSpeed = _currentSpeed;
      for (int i = 0; i < 6; i++) {
        final double life = 0.52 + _rng.nextDouble() * 0.2;
        _particles.add(
          FlapParticle(
            x: _birdX - 16 - i * 2.5 + (_rng.nextDouble() * 6 - 3),
            y: _birdY + 5 + (_rng.nextDouble() * 8 - 4),
            vx: -worldSpeed * (0.82 + _rng.nextDouble() * 0.22),
            vy: 35 + _rng.nextDouble() * 65,
            size: 5.5 + _rng.nextDouble() * 3.5,
            life: life,
            maxLife: life,
            color: i.isEven
                ? Colors.white.withValues(alpha: 0.92)
                : _birdSkin.primaryLight,
            kind: ParticleKind.trail,
            gravity: 55.0,
            drag: 1.15,
          ),
        );
      }

      for (int i = 0; i < 3; i++) {
        final double life = 0.58 + _rng.nextDouble() * 0.18;
        _particles.add(
          FlapParticle(
            x: _birdX - 18 + (_rng.nextDouble() * 6 - 3),
            y: _birdY + 3 + (_rng.nextDouble() * 8 - 4),
            vx: -worldSpeed * (0.68 + _rng.nextDouble() * 0.24),
            vy: 18 + _rng.nextDouble() * 70,
            size: 4.5 + _rng.nextDouble() * 2.2,
            life: life,
            maxLife: life,
            color: i == 0
                ? Colors.white
                : (i == 1 ? _birdSkin.primaryLight : _birdSkin.primaryMid),
            kind: ParticleKind.feather,
            gravity: 88.0,
            drag: 1.0,
            rotation: _rng.nextDouble() * math.pi * 2,
            spin: (_rng.nextDouble() - 0.5) * 9.0,
          ),
        );
      }
    });
    _sfx.play(GameSfx.flap);
  }

  void _startNewRunImmediately() {
    _sfx.play(GameSfx.swoosh);
    setState(() {
      _phase = GamePhase.ready;
      _score = 0;
      _heartsCollected = 0;
      _heartsRemaining = _mode.heartsEnabled ? 1 : 0;
      _pipesSpawnedCount = 0;
      _invulnTimer = 0.0;
      _flapSquash = 0.0;
      _hatBounce = 0.0;
      _scorePop = 0.0;
      _isNewBest = false;
      _pipes.clear();
      _hearts.clear();
      _particles.clear();
      _feedbacks.clear();
      _lastGapY = null;
      _birdVelocity = 0.0;
      _birdAngle = 0.0;
      _birdY = _groundTop * 0.40;
      _trailEmitAccum = 0.0;
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
        _startNewRunImmediately();
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
        _startNewRunImmediately();
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
                      wingPhase: _wingPhase,
                      flapSquash: _flapSquash,
                      hatBounce: _hatBounce,
                      birdSkin: _birdSkin,
                      invulnTimer: _invulnTimer,
                      pipes: _pipes,
                      hearts: _hearts,
                      clouds: _clouds,
                      particles: _particles,
                      feedbacks: _feedbacks,
                      flashAlpha: _flashAlpha,
                      shakeOffset: _shakeOffset,
                    ),
                  ),
                ),

                if (_phase == GamePhase.playing ||
                    _phase == GamePhase.dying ||
                    _phase == GamePhase.paused)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: SafeArea(
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: GameColors.panelBorder.withValues(alpha: 0.18),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x260F2744),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _mode.label,
                                style: const TextStyle(
                                  color: GameColors.brandNavy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_mode.accelerates) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${_speedMultiplier.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                    color: GameColors.accentSky,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                              if (_mode.heartsEnabled) ...[
                                const SizedBox(width: 10),
                                Container(
                                  width: 1,
                                  height: 16,
                                  color: GameColors.brandNavy
                                      .withValues(alpha: 0.18),
                                ),
                                const SizedBox(width: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    GamePhysics.maxHearts,
                                    (int index) {
                                      final bool filled =
                                          index < _heartsRemaining;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 1.5),
                                        child: Icon(
                                          filled
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 18,
                                          color: filled
                                              ? GameColors.heartRed
                                              : GameColors.brandNavy
                                                  .withValues(alpha: 0.28),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_phase == GamePhase.playing ||
                    _phase == GamePhase.dying ||
                    _phase == GamePhase.paused)
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.scale(
                          scale: 1.0 + _scorePop * 0.26,
                          child: _OutlinedText(
                            text: '$_score',
                            fontSize: 54,
                            strokeWidth: 7,
                            fillColor: GameColors.scoreRed,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

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

                if (_phase == GamePhase.ready) _buildReadyOverlay(),
                if (_phase == GamePhase.paused) _buildPausedOverlay(),
                if (_phase == GamePhase.gameOver) _buildGameOverOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildReadyOverlay() {
    final double titleFloat = math.sin(_elapsedTime * 2.5) * 4.0;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: math.max(16.0, _groundTop * 0.05),
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, titleFloat),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x420E2544),
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const ColoredBox(
                                  color: GameColors.skyTop,
                                  child: Icon(
                                    Icons.flutter_dash,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const _OutlinedText(
                            text: 'TAP FLYING BIRD',
                            fontSize: 33,
                            strokeWidth: 7,
                            fillColor: GameColors.scoreRed,
                            strokeColor: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    if (_bestScore > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'All-Time Best · $_bestScore',
                        style: const TextStyle(
                          color: GameColors.brandNavy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: GamePhysics.groundHeight + 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BirdSkinSelector(
                  selected: _birdSkin,
                  onSelected: (BirdSkin skin) {
                    _sfx.play(GameSfx.swoosh);
                    setState(() {
                      _birdSkin = skin;
                    });
                    _focusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 8),
                _ModeSelector(
                  selected: _mode,
                  onSelected: (GameMode mode) {
                    _sfx.play(GameSfx.swoosh);
                    setState(() {
                      _mode = mode;
                    });
                    _focusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 6),
                IgnorePointer(
                  child: Text(
                    _mode.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: GameColors.brandNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: GameColors.brandNavy,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF0A1B36),
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'TAP OR PRESS SPACE TO FLY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
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
      color: GameColors.brandNavy.withValues(alpha: 0.36),
      alignment: Alignment.center,
      child: _Modern3DCard(
        width: 306,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Paused',
              style: TextStyle(
                color: GameColors.brandNavy,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TactileButton(
                    label: 'Resume',
                    color: GameColors.pipeMid,
                    shadowColor: GameColors.pipeShadowRight,
                    onPressed: _togglePause,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TactileButton(
                    label: 'Restart',
                    color: GameColors.accentCoral,
                    shadowColor: GameColors.accentCoralDark,
                    onPressed: _startNewRunImmediately,
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
    final MedalTier medal = MedalTierConfig.fromScore(_score);

    return Container(
      color: GameColors.brandNavy.withValues(alpha: 0.34),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _OutlinedText(
            text: 'GAME OVER',
            fontSize: 40,
            strokeWidth: 7,
            fillColor: GameColors.scoreRed,
            strokeColor: Colors.white,
          ),
          const SizedBox(height: 16),
          _Modern3DCard(
            width: 348,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_mode.label} · ${_birdSkin.label}',
                      style: const TextStyle(
                        color: GameColors.accentSky,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '2130 Group',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'MEDAL',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _MedalBadge(tier: medal),
                        const SizedBox(height: 6),
                        Text(
                          medal.label,
                          style: const TextStyle(
                            color: GameColors.brandNavy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'SCORE',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            '$_score',
                            style: const TextStyle(
                              color: GameColors.brandNavy,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                                    color: GameColors.accentCoral,
                                    borderRadius: BorderRadius.circular(4),
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
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$_bestScore',
                            style: const TextStyle(
                              color: GameColors.brandNavy,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          if (_mode.heartsEnabled) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Hearts Collected · $_heartsCollected',
                              style: const TextStyle(
                                color: GameColors.heartRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TactileButton(
                        label: 'Play Again',
                        color: GameColors.accentCoral,
                        shadowColor: GameColors.accentCoralDark,
                        onPressed: _startNewRunImmediately,
                      ),
                    ),
                  ],
                ),
              ],
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
    required this.strokeColor,
  });

  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color fillColor;
  final Color strokeColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.4,
      height: 1.05,
    );

    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(0, 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF0E2544).withValues(alpha: 0.28),
            ),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(color: fillColor),
        ),
      ],
    );
  }
}

class _HudIconButton extends StatefulWidget {
  const _HudIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_HudIconButton> createState() => _HudIconButtonState();
}

class _HudIconButtonState extends State<_HudIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.88)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.88, end: 1.14)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.14, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 32,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Tooltip(
        message: widget.tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: GameColors.panelBorder.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1E0F2744),
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: GameColors.brandNavy,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BirdSkinSelector extends StatelessWidget {
  const _BirdSkinSelector({
    required this.selected,
    required this.onSelected,
  });

  final BirdSkin selected;
  final ValueChanged<BirdSkin> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GameColors.panelBorder.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F2744),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: BirdSkin.values.map((BirdSkin skin) {
          final bool active = skin == selected;
          return Material(
            color: active ? GameColors.brandNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onSelected(skin),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 28,
                      child: CustomPaint(
                        painter: BirdPreviewPainter(skin: skin),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      skin.label,
                      style: TextStyle(
                        color: active ? Colors.white : GameColors.brandNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.selected,
    required this.onSelected,
  });

  final GameMode selected;
  final ValueChanged<GameMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GameColors.panelBorder.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F2744),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: GameMode.values.map((GameMode mode) {
          final bool active = mode == selected;
          const Color activeColor = GameColors.accentSky;
          return Material(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onSelected(mode),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  mode.label,
                  style: TextStyle(
                    color: active ? Colors.white : GameColors.brandNavy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

class _Modern3DCard extends StatelessWidget {
  const _Modern3DCard({
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: GameColors.panelSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GameColors.panelBorder.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400F2744),
            offset: Offset(0, 7),
          ),
          BoxShadow(
            color: Color(0x280F2744),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TactileButton extends StatelessWidget {
  const _TactileButton({
    required this.label,
    required this.color,
    required this.shadowColor,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color shadowColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
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
        fill = const Color(0xFFE2E8F0);
        shine = const Color(0xFFE2E8F0);
      case MedalTier.bronze:
        fill = const Color(0xFFCD7F32);
        shine = const Color(0xFFE7A96D);
      case MedalTier.silver:
        fill = const Color(0xFFB8C2CE);
        shine = const Color(0xFFF1F5F9);
      case MedalTier.gold:
        fill = const Color(0xFFF59E0B);
        shine = const Color(0xFFFDE68A);
      case MedalTier.platinum:
        fill = const Color(0xFF38BDF8);
        shine = Colors.white;
    }

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(
          color: tier == MedalTier.none
              ? const Color(0xFFCBD5E1)
              : GameColors.brandNavy.withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F2744),
            offset: Offset(0, 4),
          ),
        ],
        gradient: tier == MedalTier.none
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [shine, fill],
              ),
      ),
      child: tier == MedalTier.none
          ? const Icon(
              Icons.emoji_events_outlined,
              color: Color(0xFF94A3B8),
              size: 28,
            )
          : const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 32,
            ),
    );
  }
}
