import {
  BIRD_SKINS,
  BirdSkin,
  FlapParticle,
  FloatingFeedback,
  getPipeBoundsAt,
  HeartPickup,
  ObstacleKind,
  PHYSICS,
  PipePair,
  SkinPalette,
  SkyCloud,
} from './types';

export interface SceneRenderState {
  width: number;
  height: number;
  elapsedTime: number;
  worldScroll: number;
  birdX: number;
  birdY: number;
  birdAngle: number;
  wingPhase: number;
  flapSquash: number;
  hatBounce: number;
  birdSkin: BirdSkin;
  invulnTimer: number;
  pipes: PipePair[];
  hearts: HeartPickup[];
  clouds: SkyCloud[];
  particles: FlapParticle[];
  feedbacks: FloatingFeedback[];
  flashAlpha: number;
  shakeX: number;
  shakeY: number;
}

export function renderFlappyScene(
  ctx: CanvasRenderingContext2D,
  s: SceneRenderState
): void {
  ctx.save();
  if (s.shakeX !== 0 || s.shakeY !== 0) {
    ctx.translate(s.shakeX, s.shakeY);
  }

  const groundTop = s.height - PHYSICS.groundHeight;

  drawDaySkyAndSun(ctx, s.width, groundTop, s.elapsedTime);
  drawClouds(ctx, s.clouds);
  drawAnimatedGroupBanner(ctx, s.width, groundTop, s.elapsedTime, s.worldScroll);
  drawPastelHills(ctx, s.width, groundTop, s.worldScroll);
  drawPipes3D(ctx, s.pipes, groundTop, s.elapsedTime);
  drawHearts3D(ctx, s.hearts, s.elapsedTime);
  drawGroundTiles(ctx, s.width, groundTop, s.worldScroll);
  drawParticles(ctx, s.particles);

  const blinkingHide =
    s.invulnTimer > 0 && Math.floor(s.invulnTimer * 18) % 2 === 1;
  if (s.invulnTimer > 0) {
    drawShieldRing(ctx, s.birdX, s.birdY, s.elapsedTime);
  }
  if (!blinkingHide) {
    drawCool3DBird(ctx, {
      x: s.birdX,
      y: s.birdY,
      angle: s.birdAngle,
      wingPhase: s.wingPhase,
      flapSquash: s.flapSquash,
      hatBounce: s.hatBounce,
      elapsedTime: s.elapsedTime,
      skin: BIRD_SKINS[s.birdSkin],
      scale: 1,
    });
  }

  drawFloatingFeedbacks(ctx, s.feedbacks);

  if (s.flashAlpha > 0.001) {
    ctx.fillStyle = `rgba(255, 255, 255, ${Math.min(0.8, s.flashAlpha)})`;
    ctx.fillRect(0, 0, s.width, s.height);
  }

  ctx.restore();
}

function drawDaySkyAndSun(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  elapsedTime: number
): void {
  const skyGrad = ctx.createLinearGradient(0, 0, 0, groundTop);
  skyGrad.addColorStop(0, '#56C8FA');
  skyGrad.addColorStop(0.55, '#9EE3FD');
  skyGrad.addColorStop(1, '#E5F8FF');
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, width, groundTop);

  const sunX = width * 0.14;
  const sunY = 78;

  ctx.save();
  ctx.translate(sunX, sunY);
  ctx.rotate(elapsedTime * 0.14);
  ctx.fillStyle = 'rgba(255, 231, 97, 0.18)';
  for (let i = 0; i < 8; i++) {
    ctx.save();
    ctx.rotate((Math.PI / 4) * i);
    ctx.beginPath();
    ctx.moveTo(-10, 0);
    ctx.lineTo(-24, -145);
    ctx.lineTo(24, -145);
    ctx.lineTo(10, 0);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
  ctx.restore();

  const pulse = 1 + 0.06 * Math.sin(elapsedTime * 2.2);
  ctx.fillStyle = 'rgba(255, 231, 97, 0.30)';
  ctx.beginPath();
  ctx.arc(sunX, sunY, 48 * pulse, 0, Math.PI * 2);
  ctx.fill();

  const sunCore = ctx.createRadialGradient(
    sunX - 8,
    sunY - 8,
    2,
    sunX,
    sunY,
    28
  );
  sunCore.addColorStop(0, '#FFFFFF');
  sunCore.addColorStop(0.5, '#FFF8BA');
  sunCore.addColorStop(1, '#FFE761');
  ctx.fillStyle = sunCore;
  ctx.beginPath();
  ctx.arc(sunX, sunY, 28, 0, Math.PI * 2);
  ctx.fill();
}

function drawClouds(ctx: CanvasRenderingContext2D, clouds: SkyCloud[]): void {
  for (const c of clouds) {
    ctx.save();
    ctx.translate(c.x, c.y);
    ctx.scale(c.scale, c.scale);

    const puffs = [
      [-62, 16, 20],
      [-32, 4, 28],
      [8, -10, 38],
      [48, 2, 26],
      [76, 16, 18],
    ];

    ctx.fillStyle = '#B8E6FA';
    for (const [px, py, pr] of puffs) {
      ctx.beginPath();
      ctx.arc(px, py, pr + 8, 0, Math.PI * 2);
      ctx.fill();
    }
    drawRoundedRect(ctx, -88, 12, 190, 26, 13);
    ctx.fill();

    ctx.fillStyle = '#FFFFFF';
    for (const [px, py, pr] of puffs) {
      ctx.beginPath();
      ctx.arc(px, py, pr, 0, Math.PI * 2);
      ctx.fill();
    }
    drawRoundedRect(ctx, -82, 16, 178, 18, 9);
    ctx.fill();

    ctx.restore();
  }
}

function drawAnimatedGroupBanner(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  elapsedTime: number,
  worldScroll: number
): void {
  const label = "Let's Play With 2130 Group";
  const skyMidY = groundTop * 0.35;
  const bobY = Math.sin(elapsedTime * 1.9) * 10;
  const span = width + 540;
  const bannerX =
    width + 270 - ((elapsedTime * 48 + worldScroll * 0.08) % span);
  const bannerY = skyMidY + bobY;

  ctx.save();
  ctx.translate(bannerX, bannerY);

  const shimmer = 0.72 + 0.28 * Math.sin(elapsedTime * 3.0);
  ctx.fillStyle = `rgba(255, 255, 255, ${0.36 * shimmer})`;
  drawRoundedRect(ctx, -192, -23, 384, 46, 23);
  ctx.fill();

  ctx.fillStyle = `rgba(255, 248, 186, ${0.9 * shimmer})`;
  for (const dx of [-206, 206]) {
    const sy = Math.sin(elapsedTime * 3.8 + dx) * 6;
    ctx.beginPath();
    ctx.arc(dx, sy, 4, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(dx - 7, sy - 1.1, 14, 2.2);
    ctx.fillRect(dx - 1.1, sy - 7, 2.2, 14);
  }

  ctx.font = '900 22px system-ui, -apple-system, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.lineJoin = 'round';
  ctx.lineWidth = 4.5;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
  ctx.strokeText(label, 0, 0);
  ctx.fillStyle = 'rgba(21, 50, 91, 0.62)';
  ctx.fillText(label, 0, 0);

  ctx.restore();
}

function drawPastelHills(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  worldScroll: number
): void {
  drawHillWave(ctx, width, groundTop, 152, 52, 480, worldScroll * 0.16, '#FADDE6');
  drawHillWave(
    ctx,
    width,
    groundTop,
    84,
    34,
    390,
    worldScroll * 0.28 + 140,
    '#F5C3D3'
  );
}

function drawHillWave(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  baseHeight: number,
  amplitude: number,
  wavelength: number,
  scroll: number,
  color: string
): void {
  ctx.beginPath();
  ctx.moveTo(-20, groundTop);
  const phase = (scroll / wavelength) * Math.PI * 2;
  for (let x = -20; x <= width + 20; x += 16) {
    const y =
      groundTop -
      baseHeight -
      Math.sin((x / wavelength) * Math.PI * 2 + phase) * amplitude;
    ctx.lineTo(x, y);
  }
  ctx.lineTo(width + 20, groundTop);
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();
}

function drawPipes3D(
  ctx: CanvasRenderingContext2D,
  pipes: PipePair[],
  groundTop: number,
  elapsedTime: number
): void {
  for (const pipe of pipes) {
    const { topBottom, bottomTop } = getPipeBoundsAt(pipe, elapsedTime);
    if (topBottom > 0) {
      drawSingle3DObstacle(
        ctx,
        pipe.x,
        -12,
        topBottom,
        true,
        pipe.kind,
        pipe.phase,
        elapsedTime
      );
    }
    if (bottomTop < groundTop) {
      drawSingle3DObstacle(
        ctx,
        pipe.x,
        bottomTop,
        groundTop,
        false,
        pipe.kind,
        pipe.phase,
        elapsedTime
      );
    }
  }
}

function drawSingle3DObstacle(
  ctx: CanvasRenderingContext2D,
  x: number,
  top: number,
  bottom: number,
  capAtBottom: boolean,
  kind: ObstacleKind,
  phase: number,
  elapsedTime: number
): void {
  const w = PHYSICS.pipeWidth;
  const overhang = PHYSICS.pipeCapOverhang;
  const capH = PHYSICS.pipeCapHeight;
  const depth = PHYSICS.obstacle3dDepth;
  const skewY = 6;

  let colors: string[];
  let sideShadow: string;
  let rimAccent: string;
  let borderColor: string;

  if (kind === 'emeraldCylinder') {
    colors = ['#47721E', '#7FB836', '#DCFA8E', '#7FB836', '#365915'];
    sideShadow = '#2B4D12';
    rimAccent = '#DCFA8E';
    borderColor = '#1A2D0C';
  } else if (kind === 'hoverPropellerGate') {
    colors = ['#1D4ED8', '#3B82F6', '#93C5FD', '#3B82F6', '#1D4ED8'];
    sideShadow = '#172554';
    rimAccent = '#FBBF24';
    borderColor = '#0F172A';
  } else {
    colors = ['#9F1239', '#E11D48', '#FDA4AF', '#E11D48', '#9F1239'];
    sideShadow = '#4C0519';
    rimAccent = '#FBBF24';
    borderColor = '#2D0612';
  }

  const sh = bottom - top;
  const capX = x - overhang;
  const capW = w + overhang * 2;
  const capY = capAtBottom ? bottom - capH : top;

  // Cast shadow
  ctx.fillStyle = 'rgba(15, 23, 42, 0.10)';
  ctx.fillRect(x + depth + 4, top + 2, w, sh);

  // 3D Extruded side face on shaft
  ctx.beginPath();
  ctx.moveTo(x + w, top);
  ctx.lineTo(x + w + depth, top - skewY);
  ctx.lineTo(x + w + depth, bottom - skewY);
  ctx.lineTo(x + w, bottom);
  ctx.closePath();
  ctx.fillStyle = sideShadow;
  ctx.fill();

  // Front cylindrical face on shaft
  paintCylinderRect(ctx, x, top, w, sh, colors);

  // Animated shine sweep
  ctx.save();
  ctx.beginPath();
  ctx.rect(x, top, w, sh);
  ctx.clip();
  const sweepPos = ((elapsedTime * 90 + phase * 60) % (sh + 120)) - 60;
  ctx.fillStyle = 'rgba(255, 255, 255, 0.22)';
  ctx.fillRect(x, top + sweepPos, w, 18);

  if (kind === 'beaconTower') {
    ctx.fillStyle = 'rgba(251, 191, 36, 0.75)';
    for (let ry = top + 38; ry < bottom - 38; ry += 56) {
      ctx.fillRect(x + 2, ry, w - 4, 5);
    }
  }
  ctx.restore();

  // 3D Extruded side face on cap
  ctx.beginPath();
  ctx.moveTo(capX + capW, capY);
  ctx.lineTo(capX + capW + depth, capY - skewY);
  ctx.lineTo(capX + capW + depth, capY + capH - skewY);
  ctx.lineTo(capX + capW, capY + capH);
  ctx.closePath();
  ctx.fillStyle = sideShadow;
  ctx.fill();

  paintCylinderRect(ctx, capX, capY, capW, capH, colors);

  // 3D Elliptical hollow rim at pipe mouth
  const mouthY = capAtBottom ? capY + capH : capY;
  const mouthCX = capX + capW / 2 + 2;
  const mouthRX = (capW - 4) / 2;
  const mouthRY = 5.5;

  ctx.fillStyle = rimAccent;
  ctx.beginPath();
  ctx.ellipse(mouthCX, mouthY, mouthRX, mouthRY, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#0B1910';
  ctx.beginPath();
  ctx.ellipse(
    mouthCX,
    mouthY,
    Math.max(4, mouthRX - 3),
    Math.max(2, mouthRY - 2.5),
    0,
    0,
    Math.PI * 2
  );
  ctx.fill();

  ctx.strokeStyle = borderColor;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(mouthCX, mouthY, mouthRX, mouthRY, 0, 0, Math.PI * 2);
  ctx.stroke();

  // Borders
  ctx.strokeStyle = borderColor;
  ctx.lineWidth = 2.2;
  ctx.lineJoin = 'round';
  ctx.strokeRect(x, top, w, sh);
  ctx.beginPath();
  ctx.moveTo(x + w, top);
  ctx.lineTo(x + w + depth, top - skewY);
  ctx.lineTo(x + w + depth, bottom - skewY);
  ctx.lineTo(x + w, bottom);
  ctx.closePath();
  ctx.stroke();

  ctx.strokeRect(capX, capY, capW, capH);
  ctx.beginPath();
  ctx.moveTo(capX + capW, capY);
  ctx.lineTo(capX + capW + depth, capY - skewY);
  ctx.lineTo(capX + capW + depth, capY + capH - skewY);
  ctx.lineTo(capX + capW, capY + capH);
  ctx.closePath();
  ctx.stroke();

  if (kind === 'hoverPropellerGate') {
    const propY = capAtBottom ? capY + 8 : capY + capH - 8;
    drawSpinningPropeller3D(
      ctx,
      capX + capW / 2,
      propY,
      elapsedTime * 11 + phase
    );
  } else if (kind === 'beaconTower') {
    const orbY = capAtBottom ? capY + 10 : capY + capH - 10;
    const orbX = capX + capW / 2;
    const glow = 0.55 + 0.45 * Math.sin(elapsedTime * 6.5 + phase);
    ctx.fillStyle = `rgba(251, 191, 36, ${0.35 * glow})`;
    ctx.beginPath();
    ctx.arc(orbX, orbY, 11, 0, Math.PI * 2);
    ctx.fill();

    const orbGrad = ctx.createRadialGradient(
      orbX - 2,
      orbY - 2,
      1,
      orbX,
      orbY,
      6
    );
    orbGrad.addColorStop(0, '#FFFFFF');
    orbGrad.addColorStop(0.5, '#FBBF24');
    orbGrad.addColorStop(1, '#B45309');
    ctx.fillStyle = orbGrad;
    ctx.beginPath();
    ctx.arc(orbX, orbY, 6, 0, Math.PI * 2);
    ctx.fill();
  }
}

function paintCylinderRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  colors: string[]
): void {
  const grad = ctx.createLinearGradient(x, 0, x + w, 0);
  grad.addColorStop(0, colors[0]);
  grad.addColorStop(0.2, colors[1]);
  grad.addColorStop(0.36, colors[2]);
  grad.addColorStop(0.68, colors[3]);
  grad.addColorStop(1, colors[4]);
  ctx.fillStyle = grad;
  ctx.fillRect(x, y, w, h);
}

function drawSpinningPropeller3D(
  ctx: CanvasRenderingContext2D,
  cx: number,
  cy: number,
  angle: number
): void {
  const bladeW = Math.abs(Math.cos(angle)) * 24 + 4;
  const grad = ctx.createLinearGradient(cx - bladeW, cy, cx + bladeW, cy);
  grad.addColorStop(0, '#B45309');
  grad.addColorStop(0.5, '#FBBF24');
  grad.addColorStop(1, '#FFFFFF');
  ctx.fillStyle = grad;

  ctx.beginPath();
  ctx.ellipse(cx - bladeW * 0.55, cy, bladeW / 2, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(cx + bladeW * 0.55, cy, bladeW / 2, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#0F172A';
  ctx.beginPath();
  ctx.arc(cx, cy, 5, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = 'rgba(255,255,255,0.8)';
  ctx.beginPath();
  ctx.arc(cx - 1.2, cy - 1.2, 2, 0, Math.PI * 2);
  ctx.fill();
}

function drawHearts3D(
  ctx: CanvasRenderingContext2D,
  hearts: HeartPickup[],
  elapsedTime: number
): void {
  for (const h of hearts) {
    if (h.collected) continue;
    const y = h.baseY + Math.sin(elapsedTime * 4.2 + h.phase) * 6;
    const pulse = 1 + 0.08 * Math.sin(elapsedTime * 6.0 + h.phase);
    const spinX = 0.74 + 0.26 * Math.cos(elapsedTime * 3.4 + h.phase);

    ctx.save();
    ctx.translate(h.x, y);
    ctx.scale(pulse * spinX, pulse);

    ctx.fillStyle = 'rgba(255, 128, 150, 0.28)';
    ctx.beginPath();
    ctx.arc(0, 0, 22, 0, Math.PI * 2);
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(0, 14);
    ctx.bezierCurveTo(-19, 2, -19, -15, -8, -15);
    ctx.bezierCurveTo(-2, -15, 0, -8, 0, -7);
    ctx.bezierCurveTo(0, -8, 2, -15, 8, -15);
    ctx.bezierCurveTo(19, -15, 19, 2, 0, 14);
    ctx.closePath();

    const grad = ctx.createRadialGradient(-6, -7, 1, 0, 0, 18);
    grad.addColorStop(0, '#FFFFFF');
    grad.addColorStop(0.22, '#FF8096');
    grad.addColorStop(0.62, '#E5253A');
    grad.addColorStop(1, '#9E0F21');
    ctx.fillStyle = grad;
    ctx.fill();

    ctx.strokeStyle = '#4A0810';
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.restore();
  }
}

function drawGroundTiles(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  worldScroll: number
): void {
  const tileWidth = 64;
  const offset = worldScroll % tileWidth;

  ctx.fillStyle = '#8C5D32';
  ctx.fillRect(0, groundTop + 18, width, 16);
  ctx.fillStyle = '#CFA774';
  ctx.fillRect(0, groundTop + 34, width, 24);
  ctx.fillStyle = '#6B421D';
  ctx.fillRect(0, groundTop + 58, width, PHYSICS.groundHeight - 58);

  for (let x = -offset - tileWidth; x < width + tileWidth; x += tileWidth) {
    ctx.beginPath();
    ctx.moveTo(x, groundTop);
    ctx.lineTo(x + tileWidth, groundTop);
    ctx.lineTo(x + tileWidth, groundTop + 19);
    ctx.lineTo(x + tileWidth * 0.78, groundTop + 26);
    ctx.lineTo(x + tileWidth * 0.56, groundTop + 17);
    ctx.lineTo(x + tileWidth * 0.34, groundTop + 26);
    ctx.lineTo(x + tileWidth * 0.14, groundTop + 18);
    ctx.lineTo(x, groundTop + 22);
    ctx.closePath();

    ctx.save();
    ctx.translate(0, 3);
    ctx.fillStyle = 'rgba(0, 0, 0, 0.25)';
    ctx.fill();
    ctx.restore();

    ctx.fillStyle = '#18CA00';
    ctx.fill();

    ctx.fillStyle = '#0A8F00';
    ctx.fillRect(x + 2, groundTop + 2, tileWidth - 4, 4);

    ctx.fillStyle = '#472A10';
    ctx.beginPath();
    ctx.arc(x + 16, groundTop + 67, 2.5, 0, Math.PI * 2);
    ctx.arc(x + 34, groundTop + 73, 2, 0, Math.PI * 2);
    ctx.arc(x + 50, groundTop + 65, 2.8, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#1A140E';
    ctx.fillRect(x, groundTop, 3.2, PHYSICS.groundHeight);
  }

  ctx.fillStyle = '#1A140E';
  ctx.fillRect(0, groundTop, width, 3);
}

function drawParticles(
  ctx: CanvasRenderingContext2D,
  particles: FlapParticle[]
): void {
  for (const pt of particles) {
    const progress = Math.max(0, Math.min(1, pt.life / pt.maxLife));
    const kind = pt.kind ?? 'burst';

    ctx.save();
    if (kind === 'trail') {
      const fade = Math.pow(progress, 1.35);
      const radius = pt.size * (0.28 + 0.55 * progress);

      ctx.globalAlpha = fade * 0.28;
      ctx.fillStyle = pt.color;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, radius * 1.85, 0, Math.PI * 2);
      ctx.fill();

      ctx.globalAlpha = fade * 0.9;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, radius, 0, Math.PI * 2);
      ctx.fill();
    } else if (kind === 'feather') {
      const fade = Math.pow(progress, 1.15);
      const radius = pt.size * (0.45 + 0.55 * progress);
      ctx.translate(pt.x, pt.y);
      ctx.rotate(pt.rotation ?? 0);
      ctx.globalAlpha = fade * 0.92;
      ctx.fillStyle = pt.color;
      ctx.beginPath();
      ctx.ellipse(0, 0, radius * 1.45, radius * 0.58, 0, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.globalAlpha = progress;
      ctx.fillStyle = pt.color;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, pt.size * (0.3 + 0.35 * progress), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
}

function drawShieldRing(
  ctx: CanvasRenderingContext2D,
  bx: number,
  by: number,
  elapsedTime: number
): void {
  const pulse = 1 + 0.08 * Math.sin(elapsedTime * 16);
  ctx.fillStyle = 'rgba(255, 128, 150, 0.28)';
  ctx.beginPath();
  ctx.arc(bx, by, 29 * pulse, 0, Math.PI * 2);
  ctx.fill();

  ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
  ctx.lineWidth = 2.6;
  ctx.beginPath();
  ctx.arc(bx, by, 29 * pulse, 0, Math.PI * 2);
  ctx.stroke();
}

export function drawCool3DBird(
  ctx: CanvasRenderingContext2D,
  opts: {
    x: number;
    y: number;
    angle: number;
    wingPhase: number;
    flapSquash: number;
    hatBounce: number;
    elapsedTime: number;
    skin: SkinPalette;
    scale: number;
  }
): void {
  const {
    x,
    y,
    angle,
    wingPhase,
    flapSquash,
    hatBounce,
    elapsedTime,
    skin,
    scale,
  } = opts;

  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  ctx.rotate(angle);

  const sx = 1 + flapSquash * 0.14;
  const sy = 1 - flapSquash * 0.12;
  ctx.scale(sx, sy);

  ctx.strokeStyle = '#141820';
  ctx.lineWidth = 2.2;
  ctx.lineJoin = 'round';

  // 1. 3D Fanned tail feathers
  const tailFlutter = Math.sin(wingPhase) * 2.5;
  ctx.beginPath();
  ctx.moveTo(-16, 0);
  ctx.lineTo(-28, -7 + tailFlutter * 0.5);
  ctx.lineTo(-22, 1);
  ctx.lineTo(-29, 5 + tailFlutter);
  ctx.lineTo(-21, 8);
  ctx.lineTo(-25, 14 + tailFlutter * 0.4);
  ctx.lineTo(-14, 9);
  ctx.closePath();
  ctx.fillStyle = skin.primaryDark;
  ctx.fill();
  ctx.stroke();

  // 2. Volumetric 3D body
  const bodyGrad = ctx.createRadialGradient(-6, -8, 2, 0.5, 1.5, 20);
  bodyGrad.addColorStop(0, '#FFFFFF');
  bodyGrad.addColorStop(0.24, skin.primaryLight);
  bodyGrad.addColorStop(0.65, skin.primaryMid);
  bodyGrad.addColorStop(1, skin.primaryDark);
  ctx.fillStyle = bodyGrad;
  ctx.beginPath();
  ctx.ellipse(0.5, 1.5, 18.5, 15.5, 0, 0, Math.PI * 2);
  ctx.fill();

  // Rim-light arc
  ctx.save();
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(
    0.5,
    1.5,
    16,
    13,
    0,
    Math.PI * 1.05,
    Math.PI * 1.6,
    false
  );
  ctx.stroke();
  ctx.restore();

  ctx.strokeStyle = '#141820';
  ctx.lineWidth = 2.2;
  ctx.beginPath();
  ctx.ellipse(0.5, 1.5, 18.5, 15.5, 0, 0, Math.PI * 2);
  ctx.stroke();

  // 3. 3D Blinking Eye
  const isBlinking = elapsedTime % 3.4 > 3.27;
  if (isBlinking) {
    ctx.beginPath();
    ctx.moveTo(2, -3);
    ctx.lineTo(14.5, -3);
    ctx.stroke();
  } else {
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.ellipse(8.25, -3.25, 6.25, 5.25, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#141820';
    ctx.beginPath();
    ctx.arc(9.2, -2.8, 2.6, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(10, -3.8, 1.0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = skin.primaryMid;
    ctx.fillRect(1, -9.5, 14, 4);
    ctx.beginPath();
    ctx.moveTo(1, -5.5);
    ctx.lineTo(15, -5.5);
    ctx.stroke();
  }

  // 4. 3D Shaded Orange Beak
  const beakGrad = ctx.createLinearGradient(13, -3, 13, 5);
  beakGrad.addColorStop(0, '#FFD873');
  beakGrad.addColorStop(1, '#FFB424');
  ctx.beginPath();
  ctx.moveTo(13, -1);
  ctx.quadraticCurveTo(28, -2.5, 27, 3.5);
  ctx.lineTo(13, 4.5);
  ctx.closePath();
  ctx.fillStyle = beakGrad;
  ctx.fill();
  ctx.stroke();

  ctx.beginPath();
  ctx.moveTo(13, 4.5);
  ctx.lineTo(26, 4.5);
  ctx.quadraticCurveTo(23.5, 10.5, 12, 8.8);
  ctx.closePath();
  ctx.fillStyle = '#E26800';
  ctx.fill();
  ctx.stroke();

  // 5. 3D Foreshortened Flapping Wing + cast shadow
  const wingWave = Math.sin(wingPhase);
  const wingScaleY = 0.55 + 0.45 * Math.abs(wingWave);
  const wingOffsetY = wingWave * 5;
  const wingTilt = wingWave * 0.45;

  ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
  ctx.beginPath();
  ctx.ellipse(-3, 6.5 + wingOffsetY * 0.25, 8.5, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.translate(-4, 3.5 + wingOffsetY * 0.5);
  ctx.rotate(wingTilt);
  ctx.scale(1, wingScaleY);
  ctx.beginPath();
  ctx.moveTo(-10, -4);
  ctx.quadraticCurveTo(3, -7, 7, 2);
  ctx.quadraticCurveTo(2, 11, -9, 9);
  ctx.quadraticCurveTo(-14, 2, -10, -4);
  ctx.closePath();
  const wingGrad = ctx.createLinearGradient(-12, -6, 6, 10);
  wingGrad.addColorStop(0, '#FFFFFF');
  wingGrad.addColorStop(0.5, skin.primaryLight);
  wingGrad.addColorStop(1, skin.primaryMid);
  ctx.fillStyle = wingGrad;
  ctx.fill();
  ctx.stroke();
  ctx.restore();

  // 6. 3D Hat with bounce lag & forehead shadow
  ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
  ctx.beginPath();
  ctx.ellipse(2, -12, 11, 2.5, 0, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.translate(2, -13.5 - hatBounce * 5.5);
  ctx.rotate(0.12 - hatBounce * 0.14);

  const hatGrad = ctx.createLinearGradient(-10.5, 0, 10.5, 0);
  hatGrad.addColorStop(0.4, skin.hatCrown);
  hatGrad.addColorStop(1, skin.hatShade);
  ctx.fillStyle = hatGrad;
  drawTopRoundedRect(ctx, -10.5, -12, 21, 12, 4.5);
  ctx.fill();

  ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-8, -10);
  ctx.lineTo(-8, -4.5);
  ctx.stroke();

  ctx.fillStyle = '#281B12';
  ctx.fillRect(-10.5, -4, 21, 4);

  ctx.strokeStyle = '#141820';
  ctx.lineWidth = 2.2;
  drawTopRoundedRect(ctx, -10.5, -12, 21, 12, 4.5);
  ctx.stroke();

  ctx.fillStyle = skin.hatShade;
  drawRoundedRect(ctx, -16, -2, 32, 5.2, 2.6);
  ctx.fill();
  ctx.stroke();

  ctx.restore();
  ctx.restore();
}

function drawFloatingFeedbacks(
  ctx: CanvasRenderingContext2D,
  feedbacks: FloatingFeedback[]
): void {
  for (const fb of feedbacks) {
    const alpha = Math.max(0, Math.min(1, fb.life / fb.maxLife));
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.font = '900 18px system-ui, -apple-system, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor = 'rgba(255, 255, 255, 0.9)';
    ctx.shadowBlur = 4;
    ctx.fillStyle = fb.color;
    ctx.fillText(fb.text, fb.x, fb.y);
    ctx.restore();
  }
}

function drawRoundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
): void {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

function drawTopRoundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
): void {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, [r, r, 0, 0]);
}
