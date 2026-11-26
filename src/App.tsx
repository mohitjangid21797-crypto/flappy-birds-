import { useCallback, useEffect, useRef, useState } from 'react';
import {
  OfflineIndicator,
  PWAInstallButton,
} from './components/PWAInstallButton';
import { loadBestScore, saveBestScore, soundEngine } from './game/sfx';
import { drawCool3DBird, renderFlappyScene } from './game/renderer3d';
import {
  BIRD_SKINS,
  BirdSkin,
  FlapParticle,
  FloatingFeedback,
  GAME_MODES,
  GameMode,
  GamePhase,
  getMedalFromScore,
  getPipeBoundsAt,
  HeartPickup,
  ObstacleKind,
  PHYSICS,
  PipePair,
  SkyCloud,
} from './game/types';

function BirdThumbnail({ skin }: { skin: BirdSkin }) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const w = 34;
    const h = 28;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    drawCool3DBird(ctx, {
      x: w * 0.47,
      y: h * 0.56,
      angle: -0.08,
      wingPhase: 0.6,
      flapSquash: 0,
      hatBounce: 0,
      elapsedTime: 1,
      skin: BIRD_SKINS[skin],
      scale: 0.64,
    });
  }, [skin]);

  return (
    <canvas
      ref={canvasRef}
      style={{ width: 34, height: 28 }}
      aria-hidden="true"
    />
  );
}

interface UiSnapshot {
  phase: GamePhase;
  mode: GameMode;
  skin: BirdSkin;
  score: number;
  bestScore: number;
  heartsRemaining: number;
  heartsCollected: number;
  isNewBest: boolean;
  muted: boolean;
  speedMultiplier: number;
  scorePop: number;
}

export function App() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  const [mutePopping, setMutePopping] = useState(false);
  const mutePopTimerRef = useRef<number | null>(null);

  const [ui, setUi] = useState<UiSnapshot>(() => ({
    phase: 'ready',
    mode: 'heartRun',
    skin: 'skyCap',
    score: 0,
    bestScore: loadBestScore(),
    heartsRemaining: 1,
    heartsCollected: 0,
    isNewBest: false,
    muted: false,
    speedMultiplier: 1,
    scorePop: 0,
  }));

  const stateRef = useRef({
    width: 800,
    height: 600,
    elapsedTime: 0,
    worldScroll: 0,
    phase: 'ready' as GamePhase,
    mode: 'heartRun' as GameMode,
    skin: 'skyCap' as BirdSkin,
    birdY: 240,
    birdVelocity: 0,
    birdAngle: 0,
    wingPhase: 0,
    flapSquash: 0,
    hatBounce: 0,
    scorePop: 0,
    score: 0,
    bestScore: loadBestScore(),
    heartsRemaining: 1,
    heartsCollected: 0,
    pipesSpawnedCount: 0,
    isNewBest: false,
    invulnTimer: 0,
    gameOverCooldown: 0,
    flashAlpha: 0,
    shakeTimer: 0,
    shakeX: 0,
    shakeY: 0,
    pipes: [] as PipePair[],
    hearts: [] as HeartPickup[],
    clouds: [
      { x: 160, y: 110, scale: 1.05, speedFactor: 0.14 },
      { x: 470, y: 82, scale: 0.85, speedFactor: 0.1 },
      { x: 780, y: 132, scale: 1.15, speedFactor: 0.16 },
    ] as SkyCloud[],
    particles: [] as FlapParticle[],
    feedbacks: [] as FloatingFeedback[],
    lastGapY: null as number | null,
    prevBirdY: 240,
    trailEmitAccum: 0,
  });

  const syncUi = useCallback(() => {
    const s = stateRef.current;
    const cfg = GAME_MODES[s.mode];
    const currentSpeed = cfg.accelerates
      ? cfg.pipeSpeed + Math.min(120, s.score * 4)
      : cfg.pipeSpeed;
    setUi({
      phase: s.phase,
      mode: s.mode,
      skin: s.skin,
      score: s.score,
      bestScore: s.bestScore,
      heartsRemaining: s.heartsRemaining,
      heartsCollected: s.heartsCollected,
      isNewBest: s.isNewBest,
      muted: soundEngine.muted,
      speedMultiplier: currentSpeed / cfg.pipeSpeed,
      scorePop: s.scorePop,
    });
  }, []);

  const getGroundTop = (h: number) => Math.max(220, h - PHYSICS.groundHeight);
  const getBirdX = (w: number) => Math.max(84, Math.min(220, w * 0.26));

  const spawnPipe = useCallback((x: number) => {
    const s = stateRef.current;
    const cfg = GAME_MODES[s.mode];
    const groundTop = getGroundTop(s.height);

    s.pipesSpawnedCount += 1;
    let kind: ObstacleKind = 'emeraldCylinder';
    if (s.pipesSpawnedCount >= 3 && s.pipesSpawnedCount % 3 === 0) {
      kind = 'hoverPropellerGate';
    } else if (s.pipesSpawnedCount >= 4 && s.pipesSpawnedCount % 4 === 0) {
      kind = 'beaconTower';
    }

    const hoverAmplitude = kind === 'hoverPropellerGate' ? 20 : 0;
    const gap = cfg.pipeGap;
    const margin = 68 + gap / 2 + hoverAmplitude;
    const minY = margin;
    const maxY = Math.max(minY + 10, groundTop - margin);

    let gapY: number;
    if (s.lastGapY === null) {
      gapY = minY + Math.random() * (maxY - minY);
    } else {
      const maxDelta = 155;
      const lo = Math.max(minY, s.lastGapY - maxDelta);
      const hi = Math.min(maxY, s.lastGapY + maxDelta);
      gapY = lo + Math.random() * Math.max(1, hi - lo);
    }
    s.lastGapY = gapY;

    const phase = Math.random() * Math.PI * 2;
    s.pipes.push({
      x,
      baseGapCenterY: gapY,
      gapHeight: gap,
      kind,
      hoverAmplitude,
      hoverSpeed: 2.2,
      phase,
      passed: false,
    });

    if (cfg.heartsEnabled && s.pipesSpawnedCount % 2 === 1) {
      s.hearts.push({
        x: x + PHYSICS.pipeWidth / 2,
        baseY: gapY,
        phase: Math.random() * Math.PI * 2,
        collected: false,
      });
    }
  }, []);

  const startNewRunImmediately = useCallback(() => {
    const s = stateRef.current;
    const cfg = GAME_MODES[s.mode];
    const groundTop = getGroundTop(s.height);
    soundEngine.stopBgm();
    soundEngine.play('swoosh');

    s.phase = 'ready';
    s.score = 0;
    s.heartsCollected = 0;
    s.heartsRemaining = cfg.heartsEnabled ? 1 : 0;
    s.pipesSpawnedCount = 0;
    s.invulnTimer = 0;
    s.flapSquash = 0;
    s.hatBounce = 0;
    s.scorePop = 0;
    s.isNewBest = false;
    s.pipes = [];
    s.hearts = [];
    s.particles = [];
    s.feedbacks = [];
    s.lastGapY = null;
    s.birdVelocity = 0;
    s.birdAngle = 0;
    s.birdY = groundTop * 0.4;
    s.prevBirdY = s.birdY;
    s.trailEmitAccum = 0;
    s.flashAlpha = 0;
    s.shakeTimer = 0;
    syncUi();
  }, [syncUi]);

  const flap = useCallback(() => {
    const s = stateRef.current;
    if (s.phase === 'paused' || s.phase === 'dying') return;

    if (s.phase === 'gameOver') {
      if (s.gameOverCooldown <= 0) {
        startNewRunImmediately();
      }
      return;
    }

    const birdX = getBirdX(s.width);
    const cfg = GAME_MODES[s.mode];

    if (s.phase === 'ready') {
      s.phase = 'playing';
      s.score = 0;
      s.heartsCollected = 0;
      s.heartsRemaining = cfg.heartsEnabled ? 1 : 0;
      s.pipesSpawnedCount = 0;
      s.invulnTimer = 0;
      s.isNewBest = false;
      s.pipes = [];
      s.hearts = [];
      s.feedbacks = [];
      s.lastGapY = null;
      s.prevBirdY = s.birdY;
      s.trailEmitAccum = 0;
      spawnPipe(Math.max(s.width * 0.85, birdX + 340));
      soundEngine.startBgm(true);
    }

    s.birdVelocity = PHYSICS.flapVelocity;
    s.birdAngle = -0.42;
    s.flapSquash = 1.0;
    s.hatBounce = 1.0;

    const skin = BIRD_SKINS[s.skin];
    const worldSpeed = cfg.accelerates
      ? cfg.pipeSpeed + Math.min(120, s.score * 4)
      : cfg.pipeSpeed;

    // Wing-beat slipstream trail burst that lingers along the bird's flight curve
    for (let i = 0; i < 6; i++) {
      const life = 0.52 + Math.random() * 0.2;
      s.particles.push({
        x: birdX - 16 - i * 2.5 + (Math.random() * 6 - 3),
        y: s.birdY + 5 + (Math.random() * 8 - 4),
        vx: -worldSpeed * (0.82 + Math.random() * 0.22),
        vy: 35 + Math.random() * 65,
        size: 5.5 + Math.random() * 3.5,
        life,
        maxLife: life,
        color: i % 2 === 0 ? 'rgba(255, 255, 255, 0.92)' : skin.primaryLight,
        kind: 'trail',
        gravity: 55,
        drag: 1.15,
      });
    }

    // Tumbling feather wisps kicked off by the flap
    for (let i = 0; i < 3; i++) {
      const life = 0.58 + Math.random() * 0.18;
      s.particles.push({
        x: birdX - 18 + (Math.random() * 6 - 3),
        y: s.birdY + 3 + (Math.random() * 8 - 4),
        vx: -worldSpeed * (0.68 + Math.random() * 0.24),
        vy: 18 + Math.random() * 70,
        size: 4.5 + Math.random() * 2.2,
        life,
        maxLife: life,
        color: i === 0 ? '#FFFFFF' : i === 1 ? skin.primaryLight : skin.primaryMid,
        kind: 'feather',
        gravity: 88,
        drag: 1.0,
        rotation: Math.random() * Math.PI * 2,
        spin: (Math.random() - 0.5) * 9,
      });
    }

    soundEngine.play('flap');
    syncUi();
  }, [spawnPipe, startNewRunImmediately, syncUi]);

  const togglePause = useCallback(() => {
    const s = stateRef.current;
    if (s.phase === 'playing') {
      s.phase = 'paused';
      soundEngine.setPaused(true);
      syncUi();
    } else if (s.phase === 'paused') {
      s.phase = 'playing';
      soundEngine.setPaused(false);
      syncUi();
    }
  }, [syncUi]);

  useEffect(() => {
    return () => {
      if (mutePopTimerRef.current !== null) {
        window.clearTimeout(mutePopTimerRef.current);
      }
    };
  }, []);

  const toggleMute = useCallback(() => {
    soundEngine.muted = !soundEngine.muted;
    if (!soundEngine.muted) {
      soundEngine.play('swoosh');
    }
    if (mutePopTimerRef.current !== null) {
      window.clearTimeout(mutePopTimerRef.current);
    }
    setMutePopping(true);
    mutePopTimerRef.current = window.setTimeout(() => {
      setMutePopping(false);
      mutePopTimerRef.current = null;
    }, 170);
    syncUi();
  }, [syncUi]);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.repeat) return;
      const s = stateRef.current;
      if (e.code === 'Space' || e.code === 'ArrowUp' || e.code === 'KeyW') {
        e.preventDefault();
        if (s.phase === 'gameOver' && s.gameOverCooldown <= 0) {
          startNewRunImmediately();
        } else {
          flap();
        }
      } else if (e.code === 'KeyP' || e.code === 'Escape') {
        if (s.phase === 'playing' || s.phase === 'paused') {
          e.preventDefault();
          togglePause();
        }
      } else if (e.code === 'KeyR' || e.code === 'Enter') {
        if (s.phase === 'gameOver' || s.phase === 'paused') {
          e.preventDefault();
          startNewRunImmediately();
        }
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [flap, startNewRunImmediately, togglePause]);

  useEffect(() => {
    const resize = () => {
      const container = containerRef.current;
      const canvas = canvasRef.current;
      if (!container || !canvas) return;
      const rect = container.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.floor(rect.width * dpr));
      canvas.height = Math.max(1, Math.floor(rect.height * dpr));
      stateRef.current.width = rect.width;
      stateRef.current.height = rect.height;
    };
    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, []);

  useEffect(() => {
    let rafId = 0;
    let lastTime = performance.now();

    const circleIntersectsRect = (
      cx: number,
      cy: number,
      r: number,
      rx: number,
      ry: number,
      rw: number,
      rh: number
    ) => {
      const closestX = Math.max(rx, Math.min(cx, rx + rw));
      const closestY = Math.max(ry, Math.min(cy, ry + rh));
      const dx = cx - closestX;
      const dy = cy - closestY;
      return dx * dx + dy * dy < r * r;
    };

    const finalizeGameOver = () => {
      const s = stateRef.current;
      s.phase = 'gameOver';
      s.gameOverCooldown = 0.35;
      soundEngine.stopBgm();
      syncUi();
    };

    const incrementScore = (points: number) => {
      const s = stateRef.current;
      s.score += points;
      s.scorePop = 1;
      if (s.score > s.bestScore) {
        s.bestScore = s.score;
        s.isNewBest = true;
        saveBestScore(s.bestScore);
      }
    };

    const consumeShield = (fromGround: boolean) => {
      const s = stateRef.current;
      const groundTop = getGroundTop(s.height);
      const birdX = getBirdX(s.width);

      s.heartsRemaining = Math.max(0, s.heartsRemaining - 1);
      s.invulnTimer = 1.35;
      s.flashAlpha = 0.45;
      s.shakeTimer = 0.16;
      soundEngine.play('shield');

      if (fromGround) {
        s.birdY = groundTop - PHYSICS.birdHitRadius - 12;
        s.birdVelocity = PHYSICS.flapVelocity * 0.95;
        s.birdAngle = -0.35;
      }

      s.feedbacks.push({
        x: birdX,
        y: s.birdY - 26,
        text: 'SHIELD!',
        color: '#15325B',
        life: 0.95,
        maxLife: 0.95,
      });

      const skin = BIRD_SKINS[s.skin];
      for (let i = 0; i < 12; i++) {
        const a = ((Math.PI * 2) / 12) * i;
        s.particles.push({
          x: birdX,
          y: s.birdY,
          vx: Math.cos(a) * 120,
          vy: Math.sin(a) * 120,
          size: 5,
          life: 0.4,
          maxLife: 0.4,
          color: i % 2 === 0 ? '#FF8096' : skin.primaryLight,
        });
      }
      syncUi();
    };

    const triggerCrash = (hitGround: boolean) => {
      const s = stateRef.current;
      const groundTop = getGroundTop(s.height);
      const birdX = getBirdX(s.width);
      const skin = BIRD_SKINS[s.skin];

      soundEngine.stopBgm();
      soundEngine.play('hit');
      s.flashAlpha = 0.72;
      s.shakeTimer = 0.22;

      for (let i = 0; i < 14; i++) {
        const angle = Math.random() * Math.PI * 2;
        const spd = 75 + Math.random() * 170;
        s.particles.push({
          x: birdX,
          y: s.birdY,
          vx: Math.cos(angle) * spd,
          vy: Math.sin(angle) * spd - 60,
          size: 4.5 + Math.random() * 4,
          life: 0.45 + Math.random() * 0.25,
          maxLife: 0.7,
          color: i % 2 === 0 ? skin.primaryMid : skin.hatCrown,
        });
      }

      const floorY = groundTop - PHYSICS.birdHitRadius;
      if (hitGround || s.birdY >= floorY - 2) {
        s.birdY = floorY;
        finalizeGameOver();
      } else {
        s.birdVelocity = -120;
        s.phase = 'dying';
        soundEngine.play('die');
        syncUi();
      }
    };

    const frame = (now: number) => {
      const dt = Math.min(0.033, Math.max(0, (now - lastTime) / 1000));
      lastTime = now;

      const s = stateRef.current;
      const cfg = GAME_MODES[s.mode];
      const groundTop = getGroundTop(s.height);
      const birdX = getBirdX(s.width);
      const baseSpeed = cfg.pipeSpeed;
      const spacing = cfg.pipeSpacing;

      if (s.phase !== 'paused') {
        s.elapsedTime += dt;
        if (s.invulnTimer > 0) s.invulnTimer = Math.max(0, s.invulnTimer - dt);
        if (s.flapSquash > 0) s.flapSquash = Math.max(0, s.flapSquash - dt * 5.2);
        if (s.hatBounce > 0) s.hatBounce = Math.max(0, s.hatBounce - dt * 4);
        if (s.scorePop > 0) {
          s.scorePop = Math.max(0, s.scorePop - dt * 4.5);
          syncUi();
        }
        if (s.flashAlpha > 0) s.flashAlpha = Math.max(0, s.flashAlpha - dt * 5);
        if (s.shakeTimer > 0) {
          s.shakeTimer = Math.max(0, s.shakeTimer - dt);
          const mag = (s.shakeTimer / 0.22) * 7;
          s.shakeX = (Math.random() * 2 - 1) * mag;
          s.shakeY = (Math.random() * 2 - 1) * mag;
        } else {
          s.shakeX = 0;
          s.shakeY = 0;
        }

        for (let i = s.particles.length - 1; i >= 0; i--) {
          const p = s.particles[i];
          p.life -= dt;
          if (p.life <= 0) {
            s.particles.splice(i, 1);
            continue;
          }
          if (p.drag) {
            const damp = Math.exp(-p.drag * dt);
            p.vx *= damp;
            p.vy *= damp;
          }
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          p.vy += (p.gravity ?? 320) * dt;
          if (p.spin) {
            p.rotation = (p.rotation ?? 0) + p.spin * dt;
          }
        }
        if (s.particles.length > 200) {
          s.particles.splice(0, s.particles.length - 200);
        }

        for (let i = s.feedbacks.length - 1; i >= 0; i--) {
          const fb = s.feedbacks[i];
          fb.life -= dt;
          if (fb.life <= 0) {
            s.feedbacks.splice(i, 1);
            continue;
          }
          fb.y -= 42 * dt;
        }

        if (s.phase === 'ready') {
          const idleSpeed = baseSpeed * 0.52;
          s.worldScroll += idleSpeed * dt;
          for (const c of s.clouds) {
            c.x -= idleSpeed * c.speedFactor * dt;
            if (c.x < -140) {
              c.x = Math.max(420, s.width) + 140 + Math.random() * 80;
              c.y = 68 + Math.random() * 88;
            }
          }
          s.birdY = groundTop * 0.4 + Math.sin(s.elapsedTime * 5) * 9;
          s.birdAngle = Math.cos(s.elapsedTime * 5) * 0.06;
          s.wingPhase += dt * 11;
          s.prevBirdY = s.birdY;
        } else if (s.phase === 'playing') {
          const speed = cfg.accelerates
            ? baseSpeed + Math.min(120, s.score * 4)
            : baseSpeed;
          s.worldScroll += speed * dt;
          for (const c of s.clouds) {
            c.x -= speed * c.speedFactor * dt;
            if (c.x < -140) {
              c.x = Math.max(420, s.width) + 140 + Math.random() * 80;
              c.y = 68 + Math.random() * 88;
            }
          }
          s.wingPhase += dt * (s.birdVelocity < 0 ? 22 : 12);

          const prevY = s.birdY;
          s.birdVelocity = Math.min(
            PHYSICS.maxFallSpeed,
            s.birdVelocity + PHYSICS.gravity * dt
          );
          s.birdY += s.birdVelocity * dt;

          const minY = PHYSICS.birdHitRadius + 6;
          if (s.birdY < minY) {
            s.birdY = minY;
            if (s.birdVelocity < 0) s.birdVelocity = 0;
          }

          // Persistent fading slipstream trail whenever the bird changes altitude
          const altitudeChange = Math.abs(s.birdY - prevY);
          const verticalSpeed = Math.abs(s.birdVelocity);
          if (altitudeChange > 0.2 || verticalSpeed > 32) {
            const emitRate = 24 + Math.min(36, verticalSpeed * 0.085);
            s.trailEmitAccum += dt * emitRate;
            const skin = BIRD_SKINS[s.skin];
            const climbing = s.birdVelocity < 0;
            while (s.trailEmitAccum >= 1) {
              s.trailEmitAccum -= 1;
              const life = climbing
                ? 0.56 + Math.random() * 0.16
                : 0.46 + Math.random() * 0.14;
              const tailOffsetX = -17 + (Math.random() * 4 - 2);
              const tailOffsetY = (climbing ? 4 : -1) + (Math.random() * 6 - 3);
              s.particles.push({
                x: birdX + tailOffsetX,
                y: s.birdY + tailOffsetY,
                vx: -speed * (0.88 + Math.random() * 0.14),
                vy: -s.birdVelocity * 0.06 + (Math.random() * 24 - 12),
                size:
                  (climbing ? 5.2 : 4.2) +
                  Math.min(2.8, verticalSpeed * 0.004) +
                  Math.random() * 1.6,
                life,
                maxLife: life,
                color: climbing
                  ? Math.random() < 0.55
                    ? 'rgba(255, 255, 255, 0.9)'
                    : skin.primaryLight
                  : Math.random() < 0.65
                    ? skin.primaryLight
                    : 'rgba(255, 255, 255, 0.82)',
                kind: 'trail',
                gravity: climbing ? 22 : -10,
                drag: 0.9,
              });

              if (verticalSpeed > 260 && Math.random() < 0.24) {
                const fLife = 0.5 + Math.random() * 0.18;
                s.particles.push({
                  x: birdX - 18,
                  y: s.birdY + (Math.random() * 8 - 4),
                  vx: -speed * (0.76 + Math.random() * 0.18),
                  vy: -s.birdVelocity * 0.1 + (Math.random() * 34 - 17),
                  size: 3.6 + Math.random() * 1.8,
                  life: fLife,
                  maxLife: fLife,
                  color: skin.primaryMid,
                  kind: 'feather',
                  gravity: 40,
                  drag: 1.0,
                  rotation: Math.random() * Math.PI * 2,
                  spin: (Math.random() - 0.5) * 8,
                });
              }
            }
          }
          s.prevBirdY = s.birdY;

          if (s.birdVelocity < 90) {
            s.birdAngle = Math.max(-0.42, s.birdAngle - dt * 6.5);
          } else {
            const ratio = Math.min(
              1,
              Math.max(0, (s.birdVelocity - 90) / (PHYSICS.maxFallSpeed - 90))
            );
            const targetAngle = -0.14 + ratio * 1.44;
            s.birdAngle +=
              (targetAngle - s.birdAngle) * Math.min(1, dt * 8);
          }

          let scoreChanged = false;
          for (const pipe of s.pipes) {
            pipe.x -= speed * dt;
            if (!pipe.passed && pipe.x + PHYSICS.pipeWidth / 2 < birdX) {
              pipe.passed = true;
              incrementScore(1);
              soundEngine.play(
                s.score > 0 && s.score % 10 === 0 ? 'milestone' : 'score'
              );
              scoreChanged = true;
            }
          }
          s.pipes = s.pipes.filter((p) => p.x >= -PHYSICS.pipeWidth - 40);

          for (const h of s.hearts) {
            h.x -= speed * dt;
            if (!h.collected) {
              const hy =
                h.baseY + Math.sin(s.elapsedTime * 4.2 + h.phase) * 6;
              const dx = h.x - birdX;
              const dy = hy - s.birdY;
              if (dx * dx + dy * dy <= 33 * 33) {
                h.collected = true;
                s.heartsCollected += 1;
                soundEngine.play('heart');
                if (s.heartsRemaining < PHYSICS.maxHearts) {
                  s.heartsRemaining += 1;
                  s.feedbacks.push({
                    x: h.x,
                    y: hy - 14,
                    text: '+1 LIFE ♥',
                    color: '#E5253A',
                    life: 0.95,
                    maxLife: 0.95,
                  });
                } else {
                  incrementScore(2);
                  s.feedbacks.push({
                    x: h.x,
                    y: hy - 14,
                    text: '+2 BONUS',
                    color: '#F59E0B',
                    life: 0.95,
                    maxLife: 0.95,
                  });
                }
                for (let i = 0; i < 12; i++) {
                  const a = ((Math.PI * 2) / 12) * i;
                  const spd = 70 + Math.random() * 85;
                  s.particles.push({
                    x: h.x,
                    y: hy,
                    vx: Math.cos(a) * spd,
                    vy: Math.sin(a) * spd - 30,
                    size: 5 + Math.random() * 3,
                    life: 0.45,
                    maxLife: 0.45,
                    color: i % 2 === 0 ? '#FF8096' : '#FFFFFF',
                  });
                }
                scoreChanged = true;
              }
            }
          }
          s.hearts = s.hearts.filter((h) => !h.collected && h.x >= -40);

          if (s.pipes.length === 0) {
            spawnPipe(Math.max(s.width + 60, birdX + 340));
          } else {
            const rightmostX = s.pipes[s.pipes.length - 1].x;
            if (rightmostX < s.width - spacing + 90) {
              spawnPipe(rightmostX + spacing);
            }
          }

          if (scoreChanged) {
            syncUi();
          }

          if (s.birdY + PHYSICS.birdHitRadius >= groundTop) {
            if (cfg.heartsEnabled && s.heartsRemaining > 0 && s.invulnTimer <= 0) {
              consumeShield(true);
            } else {
              triggerCrash(true);
            }
          } else if (s.invulnTimer <= 0) {
            let hitPipe = false;
            const r = PHYSICS.birdHitRadius;
            for (const pipe of s.pipes) {
              if (
                pipe.x - PHYSICS.pipeCapOverhang > birdX + r ||
                pipe.x + PHYSICS.pipeWidth + PHYSICS.pipeCapOverhang <
                  birdX - r
              ) {
                continue;
              }
              const { topBottom, bottomTop } = getPipeBoundsAt(
                pipe,
                s.elapsedTime
              );
              if (topBottom > 0) {
                if (
                  circleIntersectsRect(
                    birdX,
                    s.birdY,
                    r,
                    pipe.x,
                    -220,
                    PHYSICS.pipeWidth,
                    topBottom + 220
                  ) ||
                  circleIntersectsRect(
                    birdX,
                    s.birdY,
                    r,
                    pipe.x - PHYSICS.pipeCapOverhang,
                    topBottom - PHYSICS.pipeCapHeight,
                    PHYSICS.pipeWidth + PHYSICS.pipeCapOverhang * 2,
                    PHYSICS.pipeCapHeight
                  )
                ) {
                  hitPipe = true;
                  break;
                }
              }
              if (bottomTop < groundTop) {
                if (
                  circleIntersectsRect(
                    birdX,
                    s.birdY,
                    r,
                    pipe.x,
                    bottomTop,
                    PHYSICS.pipeWidth,
                    groundTop - bottomTop
                  ) ||
                  circleIntersectsRect(
                    birdX,
                    s.birdY,
                    r,
                    pipe.x - PHYSICS.pipeCapOverhang,
                    bottomTop,
                    PHYSICS.pipeWidth + PHYSICS.pipeCapOverhang * 2,
                    PHYSICS.pipeCapHeight
                  )
                ) {
                  hitPipe = true;
                  break;
                }
              }
            }

            if (hitPipe) {
              if (cfg.heartsEnabled && s.heartsRemaining > 0) {
                consumeShield(false);
              } else {
                triggerCrash(false);
              }
            }
          }
        } else if (s.phase === 'dying') {
          s.birdVelocity = Math.min(
            PHYSICS.maxFallSpeed * 1.25,
            s.birdVelocity + PHYSICS.gravity * 1.15 * dt
          );
          s.birdY += s.birdVelocity * dt;
          s.birdAngle = Math.min(1.48, s.birdAngle + dt * 5.2);

          s.trailEmitAccum += dt * 26;
          const skin = BIRD_SKINS[s.skin];
          while (s.trailEmitAccum >= 1) {
            s.trailEmitAccum -= 1;
            const life = 0.42 + Math.random() * 0.14;
            s.particles.push({
              x: birdX + (Math.random() * 10 - 5),
              y: s.birdY - 6 + (Math.random() * 6 - 3),
              vx: -55 + (Math.random() * 50 - 25),
              vy: -65 - Math.random() * 45,
              size: 4.5 + Math.random() * 2.5,
              life,
              maxLife: life,
              color: Math.random() < 0.5 ? skin.primaryLight : '#FFFFFF',
              kind: 'trail',
              gravity: 25,
              drag: 1.5,
            });
          }

          const floorY = groundTop - PHYSICS.birdHitRadius;
          if (s.birdY >= floorY) {
            s.birdY = floorY;
            finalizeGameOver();
          }
        } else if (s.phase === 'gameOver' && s.gameOverCooldown > 0) {
          s.gameOverCooldown = Math.max(0, s.gameOverCooldown - dt);
        }
      }

      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          const dpr = window.devicePixelRatio || 1;
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          renderFlappyScene(ctx, {
            width: s.width,
            height: s.height,
            elapsedTime: s.elapsedTime,
            worldScroll: s.worldScroll,
            birdX,
            birdY: s.birdY,
            birdAngle: s.birdAngle,
            wingPhase: s.wingPhase,
            flapSquash: s.flapSquash,
            hatBounce: s.hatBounce,
            birdSkin: s.skin,
            invulnTimer: s.invulnTimer,
            pipes: s.pipes,
            hearts: s.hearts,
            clouds: s.clouds,
            particles: s.particles,
            feedbacks: s.feedbacks,
            flashAlpha: s.flashAlpha,
            shakeX: s.shakeX,
            shakeY: s.shakeY,
          });
        }
      }

      rafId = requestAnimationFrame(frame);
    };

    rafId = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(rafId);
  }, [spawnPipe, syncUi]);

  const activeModeCfg = GAME_MODES[ui.mode];
  const medal = getMedalFromScore(ui.score);

  return (
    <div
      ref={containerRef}
      className="relative w-screen h-screen overflow-hidden select-none bg-[#56C8FA]"
    >
      <canvas
        ref={canvasRef}
        onPointerDown={flap}
        className="block w-full h-full cursor-pointer touch-none"
      />

      <OfflineIndicator />

      {/* Top-Left Live HUD */}
      {(ui.phase === 'playing' ||
        ui.phase === 'dying' ||
        ui.phase === 'paused') && (
        <div className="pointer-events-none absolute top-4 left-4 flex items-center gap-2.5 px-3.5 py-2 rounded-2xl bg-white/92 border border-[#1E3A5F]/20 shadow-[0_4px_0_rgba(15,39,68,0.16)]">
          <span className="text-[13px] font-extrabold text-[#15325B]">
            {activeModeCfg.label}
          </span>
          {activeModeCfg.accelerates && (
            <span className="text-xs font-black text-[#0EA5E9] tabular-nums">
              {ui.speedMultiplier.toFixed(1)}x
            </span>
          )}
          {activeModeCfg.heartsEnabled && (
            <>
              <span className="w-px h-4 bg-[#15325B]/20" />
              <div className="flex items-center gap-0.5" aria-label="Lives">
                {Array.from({ length: PHYSICS.maxHearts }).map((_, idx) => {
                  const filled = idx < ui.heartsRemaining;
                  return (
                    <svg
                      key={idx}
                      viewBox="0 0 24 24"
                      className={`w-[18px] h-[18px] ${
                        filled ? 'text-[#E5253A]' : 'text-[#15325B]/25'
                      }`}
                      fill={filled ? 'currentColor' : 'none'}
                      stroke="currentColor"
                      strokeWidth="2"
                    >
                      <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                    </svg>
                  );
                })}
              </div>
            </>
          )}
        </div>
      )}

      {/* Top-Center 3D Popping Crimson Score */}
      {(ui.phase === 'playing' ||
        ui.phase === 'dying' ||
        ui.phase === 'paused') && (
        <div className="pointer-events-none absolute top-5 inset-x-0 flex justify-center">
          <span
            style={{
              transform: `scale(${1 + ui.scorePop * 0.25})`,
              WebkitTextStroke: '3px #FFFFFF',
              textShadow: '0 4px 0 rgba(14,37,68,0.28)',
            }}
            className="text-[54px] font-black leading-none tracking-wider text-[#E53E3E] tabular-nums"
          >
            {ui.score}
          </span>
        </div>
      )}

      {/* Top-Right Tactile HUD Controls */}
      <div className="absolute top-4 right-4 flex items-center gap-2">
        {ui.phase === 'ready' && <PWAInstallButton />}

        <button
          type="button"
          onClick={toggleMute}
          title={ui.muted ? 'Unmute Sound' : 'Mute Sound'}
          aria-label={ui.muted ? 'Unmute Sound' : 'Mute Sound'}
          className={`w-11 h-11 rounded-xl bg-white/95 border border-[#1E3A5F]/20 shadow-[0_3px_0_rgba(15,39,68,0.14)] flex items-center justify-center text-[#15325B] hover:bg-white transition-transform duration-150 ease-out active:scale-90 active:translate-y-0.5 cursor-pointer ${
            mutePopping ? 'scale-[1.15]' : 'scale-100 hover:scale-105'
          }`}
        >
          {ui.muted ? (
            <svg
              viewBox="0 0 24 24"
              className={`w-6 h-6 transition-transform duration-150 ${
                mutePopping ? 'scale-110' : 'scale-100'
              }`}
              fill="currentColor"
            >
              <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" />
            </svg>
          ) : (
            <svg
              viewBox="0 0 24 24"
              className={`w-6 h-6 transition-transform duration-150 ${
                mutePopping ? 'scale-110' : 'scale-100'
              }`}
              fill="currentColor"
            >
              <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" />
            </svg>
          )}
        </button>

        {(ui.phase === 'playing' || ui.phase === 'paused') && (
          <button
            type="button"
            onClick={togglePause}
            title={ui.phase === 'paused' ? 'Resume' : 'Pause'}
            aria-label={ui.phase === 'paused' ? 'Resume' : 'Pause'}
            className="w-11 h-11 rounded-xl bg-white/95 border border-[#1E3A5F]/20 shadow-[0_3px_0_rgba(15,39,68,0.14)] flex items-center justify-center text-[#15325B] hover:bg-white active:translate-y-0.5 cursor-pointer"
          >
            {ui.phase === 'paused' ? (
              <svg viewBox="0 0 24 24" className="w-6 h-6" fill="currentColor">
                <path d="M8 5v14l11-7z" />
              </svg>
            ) : (
              <svg viewBox="0 0 24 24" className="w-6 h-6" fill="currentColor">
                <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
              </svg>
            )}
          </button>
        )}
      </div>

      {/* Ready / Title Overlay */}
      {ui.phase === 'ready' && (
        <>
          <div className="pointer-events-none absolute top-[4%] inset-x-3 flex flex-col items-center text-center animate-[bounce_3.6s_ease-in-out_infinite]">
            <div className="flex items-center justify-center gap-2.5">
              <img
                src="/app-logo.png"
                alt="Tap Flying Bird logo"
                referrerPolicy="no-referrer"
                className="w-11 h-11 sm:w-13 sm:h-13 rounded-2xl border-2 border-white/95 shadow-[0_4px_0_rgba(14,37,68,0.26)] object-cover"
              />
              <h1
                style={{
                  WebkitTextStroke: '3px #FFFFFF',
                  textShadow: '0 4px 0 rgba(14,37,68,0.28)',
                }}
                className="text-[28px] sm:text-[38px] font-black leading-none tracking-wider text-[#E53E3E]"
              >
                TAP FLYING BIRD
              </h1>
            </div>

            {ui.bestScore > 0 && (
              <p className="mt-2 text-xs sm:text-sm font-extrabold text-[#15325B]">
                All-Time Best · {ui.bestScore}
              </p>
            )}
          </div>

          <div className="absolute bottom-[94px] inset-x-4 flex flex-col items-center gap-2">
            {/* Bird Skin Selector */}
            <div className="flex flex-wrap items-center justify-center gap-1 p-1 rounded-2xl bg-white/92 border border-[#1E3A5F]/20 shadow-[0_4px_0_rgba(15,39,68,0.14)]">
              {(Object.keys(BIRD_SKINS) as BirdSkin[]).map((skinKey) => {
                const active = ui.skin === skinKey;
                return (
                  <button
                    key={skinKey}
                    type="button"
                    onClick={() => {
                      soundEngine.setSkin(skinKey);
                      soundEngine.play('flap');
                      stateRef.current.skin = skinKey;
                      syncUi();
                    }}
                    className={`flex items-center gap-1.5 px-2.5 py-1.5 min-h-10 rounded-xl text-xs font-extrabold transition-colors cursor-pointer ${
                      active
                        ? 'bg-[#15325B] text-white'
                        : 'text-[#15325B] hover:bg-[#15325B]/5'
                    }`}
                  >
                    <BirdThumbnail skin={skinKey} />
                    <span>{BIRD_SKINS[skinKey].label}</span>
                  </button>
                );
              })}
            </div>

            {/* Game Mode Selector */}
            <div className="flex flex-wrap items-center justify-center gap-1 p-1 rounded-xl bg-white/92 border border-[#1E3A5F]/20 shadow-[0_4px_0_rgba(15,39,68,0.14)]">
              {(Object.keys(GAME_MODES) as GameMode[]).map((modeKey) => {
                const active = ui.mode === modeKey;
                return (
                  <button
                    key={modeKey}
                    type="button"
                    onClick={() => {
                      soundEngine.play('swoosh');
                      stateRef.current.mode = modeKey;
                      syncUi();
                    }}
                    className={`px-3 py-2 min-h-10 rounded-lg text-[12.5px] font-extrabold transition-colors cursor-pointer ${
                      active
                        ? 'bg-[#0EA5E9] text-white'
                        : 'text-[#15325B] hover:bg-[#0EA5E9]/10'
                    }`}
                  >
                    {GAME_MODES[modeKey].label}
                  </button>
                );
              })}
            </div>

            <p className="pointer-events-none text-xs font-bold text-[#15325B] text-center">
              {activeModeCfg.subtitle}
            </p>

            <div className="pointer-events-none px-5 py-2.5 rounded-xl bg-[#15325B] text-white text-[13px] font-extrabold tracking-widest shadow-[0_4px_0_#0A1B36]">
              TAP OR PRESS SPACE TO FLY
            </div>
          </div>
        </>
      )}

      {/* Paused Modal */}
      {ui.phase === 'paused' && (
        <div className="absolute inset-0 bg-[#15325B]/35 flex items-center justify-center p-5">
          <div className="w-[306px] p-5 rounded-[20px] bg-[#FCFDFF] border-2 border-[#1E3A5F]/20 shadow-[0_7px_0_rgba(15,39,68,0.25),0_14px_24px_rgba(15,39,68,0.2)] text-center">
            <h2 className="text-2xl font-black text-[#15325B]">
              Game Paused
            </h2>
            <div className="mt-5 flex gap-3">
              <button
                type="button"
                onClick={togglePause}
                className="flex-1 h-12 rounded-[14px] bg-[#7FB836] text-white font-black text-base shadow-[0_4px_0_#365915] active:translate-y-0.5 cursor-pointer"
              >
                Resume
              </button>
              <button
                type="button"
                onClick={startNewRunImmediately}
                className="flex-1 h-12 rounded-[14px] bg-[#E53E3E] text-white font-black text-base shadow-[0_4px_0_#B91C1C] active:translate-y-0.5 cursor-pointer"
              >
                Restart
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Game Over Modal */}
      {ui.phase === 'gameOver' && (
        <div className="absolute inset-0 bg-[#15325B]/35 flex flex-col items-center justify-center p-5">
          <h2
            style={{
              WebkitTextStroke: '3px #FFFFFF',
              textShadow: '0 4px 0 rgba(14,37,68,0.28)',
            }}
            className="text-[40px] font-black tracking-wider text-[#E53E3E] mb-4"
          >
            GAME OVER
          </h2>

          <div className="w-[348px] max-w-full p-5 rounded-[20px] bg-[#FCFDFF] border-2 border-[#1E3A5F]/20 shadow-[0_7px_0_rgba(15,39,68,0.25),0_14px_24px_rgba(15,39,68,0.2)]">
            <div className="flex items-center justify-between text-xs font-extrabold">
              <span className="text-[#0EA5E9]">
                {activeModeCfg.label} · {BIRD_SKINS[ui.skin].label}
              </span>
              <span className="text-[#64748B]">2130 Group</span>
            </div>

            <div className="mt-4 flex items-center justify-between">
              <div className="flex flex-col items-center">
                <span className="text-[11px] font-extrabold tracking-widest text-[#64748B]">
                  MEDAL
                </span>
                <div
                  className={`mt-2 w-[62px] h-[62px] rounded-full border-2 flex items-center justify-center shadow-[0_4px_0_rgba(15,39,68,0.16)] ${
                    medal === 'PLATINUM'
                      ? 'bg-gradient-to-br from-white to-[#38BDF8] border-[#15325B]/25 text-white'
                      : medal === 'GOLD'
                        ? 'bg-gradient-to-br from-[#FDE68A] to-[#F59E0B] border-[#15325B]/25 text-white'
                        : medal === 'SILVER'
                          ? 'bg-gradient-to-br from-[#F1F5F9] to-[#B8C2CE] border-[#15325B]/25 text-white'
                          : medal === 'BRONZE'
                            ? 'bg-gradient-to-br from-[#E7A96D] to-[#CD7F32] border-[#15325B]/25 text-white'
                            : 'bg-[#E2E8F0] border-[#CBD5E1] text-[#94A3B8]'
                  }`}
                >
                  <svg viewBox="0 0 24 24" className="w-8 h-8" fill="currentColor">
                    <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
                  </svg>
                </div>
                <span className="mt-1.5 text-[11px] font-extrabold text-[#15325B]">
                  {medal}
                </span>
              </div>

              <div className="flex flex-col items-end">
                <span className="text-[11px] font-extrabold tracking-widest text-[#64748B]">
                  SCORE
                </span>
                <span className="text-[32px] font-black leading-tight text-[#15325B] tabular-nums">
                  {ui.score}
                </span>

                <div className="mt-2 flex items-center gap-1.5">
                  {ui.isNewBest && (
                    <span className="px-1.5 py-0.5 rounded bg-[#E53E3E] text-white text-[10px] font-black">
                      NEW
                    </span>
                  )}
                  <span className="text-[11px] font-extrabold tracking-widest text-[#64748B]">
                    BEST
                  </span>
                </div>
                <span className="text-[28px] font-black leading-tight text-[#15325B] tabular-nums">
                  {ui.bestScore}
                </span>

                {activeModeCfg.heartsEnabled && (
                  <span className="mt-1 text-xs font-bold text-[#E5253A]">
                    Hearts Collected · {ui.heartsCollected}
                  </span>
                )}
              </div>
            </div>

            <div className="mt-5 flex gap-2.5">
              <button
                type="button"
                onClick={startNewRunImmediately}
                className="flex-1 h-12 rounded-[14px] bg-[#E53E3E] text-white font-black text-base tracking-wide shadow-[0_4px_0_#B91C1C] active:translate-y-0.5 cursor-pointer"
              >
                Play Again
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;
