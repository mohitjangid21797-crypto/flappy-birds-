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
import { Starfield } from './starfield';

const skyStarfield = new Starfield();

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
  bokehAlpha?: number;
  sessionDuration?: number;
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
  const nightProgress = computeNightProgress(s.sessionDuration ?? s.elapsedTime);

  drawDaySkyAndSun(ctx, s.width, groundTop, s.elapsedTime, nightProgress);
  skyStarfield.render(
    ctx,
    s.width,
    groundTop,
    s.elapsedTime,
    s.worldScroll,
    0.22 + 0.78 * nightProgress
  );
  drawClouds(ctx, s.clouds, nightProgress);
  drawGroupSkyBrand(ctx, s.width, groundTop, s.elapsedTime, s.worldScroll);
  drawSkyBokehAndSparkles(
    ctx,
    s.width,
    groundTop,
    s.elapsedTime,
    s.worldScroll,
    s.bokehAlpha ?? 0
  );
  drawPastelHills(ctx, s.width, groundTop, s.worldScroll, nightProgress);
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

function lerpHexColor(hexA: string, hexB: string, t: number): string {
  const k = Math.max(0, Math.min(1, t));
  const a = parseInt(hexA.slice(1), 16);
  const b = parseInt(hexB.slice(1), 16);
  const ar = (a >> 16) & 0xff;
  const ag = (a >> 8) & 0xff;
  const ab = a & 0xff;
  const br = (b >> 16) & 0xff;
  const bg = (b >> 8) & 0xff;
  const bb = b & 0xff;
  const r = Math.round(ar + (br - ar) * k);
  const g = Math.round(ag + (bg - ag) * k);
  const bl = Math.round(ab + (bb - ab) * k);
  return `rgb(${r}, ${g}, ${bl})`;
}

function lerpThreeStageColor(
  dayHex: string,
  duskHex: string,
  nightHex: string,
  t: number
): string {
  if (t <= 0.45) {
    return lerpHexColor(dayHex, duskHex, t / 0.45);
  }
  return lerpHexColor(duskHex, nightHex, (t - 0.45) / 0.55);
}

function computeNightProgress(sessionDuration: number): number {
  const raw = Math.max(0, Math.min(1, sessionDuration / 60));
  return raw * raw * (3 - 2 * raw);
}

function drawDaySkyAndSun(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  elapsedTime: number,
  nightProgress: number
): void {
  const skyGrad = ctx.createLinearGradient(0, 0, 0, groundTop);
  skyGrad.addColorStop(
    0,
    lerpThreeStageColor('#56C8FA', '#304C9E', '#0D1137', nightProgress)
  );
  skyGrad.addColorStop(
    0.38,
    lerpThreeStageColor('#86DAFC', '#4C4B9E', '#1E1B4B', nightProgress)
  );
  skyGrad.addColorStop(
    0.72,
    lerpThreeStageColor('#BCEDFF', '#7A4FA3', '#331859', nightProgress)
  );
  skyGrad.addColorStop(
    1,
    lerpThreeStageColor('#E5F8FF', '#B97FC9', '#4C1D6E', nightProgress)
  );
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, width, groundTop);

  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, width, groundTop);
  ctx.clip();

  // Sun sets smoothly down toward the horizon as night begins
  const sunAlpha = Math.max(0, Math.min(1, 1 - nightProgress / 0.52));
  if (sunAlpha > 0.01) {
    const sunX = width * 0.14;
    const sunY = 78 + (1 - sunAlpha) * 150;

    ctx.save();
    ctx.globalAlpha = sunAlpha;

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
    ctx.restore();
  }

  // Luminous crescent moon rises in place of the sun during twilight and night
  const moonT = Math.max(0, Math.min(1, (nightProgress - 0.34) / 0.44));
  const moonRise = moonT * moonT * (3 - 2 * moonT);
  if (moonRise > 0.01) {
    const moonX = width * 0.14;
    const moonY = 78 + (1 - moonRise) * 140;
    const R = 28;
    const dx = 11;
    const dy = -6;
    const r = 23.5;

    ctx.save();
    ctx.globalAlpha = moonRise;

    // Soft layered moonlight glow
    const moonPulse = 1 + 0.05 * Math.sin(elapsedTime * 1.8);
    const outerGlow = ctx.createRadialGradient(
      moonX,
      moonY,
      R * 0.4,
      moonX,
      moonY,
      58 * moonPulse
    );
    outerGlow.addColorStop(0, 'rgba(224, 231, 255, 0.34)');
    outerGlow.addColorStop(0.55, 'rgba(167, 139, 250, 0.14)');
    outerGlow.addColorStop(1, 'rgba(167, 139, 250, 0)');
    ctx.fillStyle = outerGlow;
    ctx.beginPath();
    ctx.arc(moonX, moonY, 58 * moonPulse, 0, Math.PI * 2);
    ctx.fill();

    // Subtle shadowed side of the moon sphere for 3D depth
    ctx.fillStyle = 'rgba(49, 46, 129, 0.34)';
    ctx.beginPath();
    ctx.arc(moonX, moonY, R - 0.5, 0, Math.PI * 2);
    ctx.fill();

    // Exact geometric crescent path (Circle(0,0,R) minus Circle(dx,dy,r))
    const d = Math.hypot(dx, dy);
    const theta = Math.atan2(dy, dx);
    const a1 = Math.acos((R * R + d * d - r * r) / (2 * R * d));
    const ang1 = theta + a1;
    const ang2 = theta - a1;
    const b1 = Math.atan2(R * Math.sin(ang1) - dy, R * Math.cos(ang1) - dx);
    const b2 = Math.atan2(R * Math.sin(ang2) - dy, R * Math.cos(ang2) - dx);

    const crescentPath = new Path2D();
    crescentPath.arc(moonX, moonY, R, ang1, ang2, false);
    crescentPath.arc(moonX + dx, moonY + dy, r, b2, b1, true);
    crescentPath.closePath();

    const moonGrad = ctx.createRadialGradient(
      moonX - 10,
      moonY - 8,
      2,
      moonX - 4,
      moonY,
      R * 1.15
    );
    moonGrad.addColorStop(0, '#FFFFFF');
    moonGrad.addColorStop(0.6, '#EEF2FF');
    moonGrad.addColorStop(1, '#C7D2FE');
    ctx.fillStyle = moonGrad;
    ctx.fill(crescentPath);

    // Delicate lunar craters clipped inside the bright crescent
    ctx.save();
    ctx.clip(crescentPath);
    ctx.fillStyle = 'rgba(129, 140, 248, 0.24)';
    const craters: Array<[number, number, number]> = [
      [-16, -4, 4.2],
      [-11, 12, 3.0],
      [-21, 8, 2.1],
    ];
    for (const [cx, cy, cr] of craters) {
      ctx.beginPath();
      ctx.arc(moonX + cx, moonY + cy, cr, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    ctx.restore();
  }

  ctx.restore();
}

function drawClouds(
  ctx: CanvasRenderingContext2D,
  clouds: SkyCloud[],
  nightProgress: number
): void {
  const haloColor = lerpThreeStageColor(
    '#B8E6FA',
    '#796EB8',
    '#3B3478',
    nightProgress
  );
  const fillColor = lerpThreeStageColor(
    '#FFFFFF',
    '#E5E0FA',
    '#C9C8F0',
    nightProgress
  );

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

    ctx.fillStyle = haloColor;
    for (const [px, py, pr] of puffs) {
      ctx.beginPath();
      ctx.arc(px, py, pr + 8, 0, Math.PI * 2);
      ctx.fill();
    }
    drawRoundedRect(ctx, -88, 12, 190, 26, 13);
    ctx.fill();

    ctx.fillStyle = fillColor;
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

function drawGroupSkyBrand(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  elapsedTime: number,
  worldScroll: number
): void {
  const fontSize = Math.max(15.5, Math.min(28, width * 0.044));
  const prefixText = "Let's Play with ";
  const brandText = '2130 Group';

  const prefixFont = `700 ${fontSize.toFixed(1)}px "Plus Jakarta Sans", "Outfit", system-ui, sans-serif`;
  const brandFont = `900 ${(fontSize * 1.06).toFixed(1)}px "Outfit", "Plus Jakarta Sans", system-ui, sans-serif`;

  ctx.save();
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';

  ctx.font = prefixFont;
  const prefixWidth = ctx.measureText(prefixText).width;

  ctx.font = brandFont;
  const brandWidth = ctx.measureText(brandText).width;

  const totalTextWidth = prefixWidth + brandWidth;
  const blockWidth = totalTextWidth + 32;

  const span = width + blockWidth + 120;
  const progress =
    (elapsedTime * 24 + worldScroll * 0.035 + span * 0.5) % span;
  const driftX = width + blockWidth * 0.5 + 60 - progress;

  const baseSkyY = Math.max(122, Math.min(groundTop * 0.36, groundTop - 185));
  const floatY = Math.sin(elapsedTime * 1.2) * 7.5;
  const breathScale = 1 + 0.014 * Math.sin(elapsedTime * 1.5);

  const edgePad = 70;
  const leftFade = Math.max(
    0,
    Math.min(1, (driftX + totalTextWidth * 0.4) / edgePad)
  );
  const rightFade = Math.max(
    0,
    Math.min(1, (width - driftX + totalTextWidth * 0.4) / edgePad)
  );
  const fadeAlpha =
    (0.78 + 0.1 * Math.sin(elapsedTime * 1.4)) * Math.min(leftFade, rightFade);
  if (fadeAlpha <= 0.01) {
    ctx.restore();
    return;
  }

  ctx.translate(driftX, baseSkyY + floatY);
  ctx.scale(breathScale, breathScale);
  ctx.globalAlpha = fadeAlpha;

  const startX = -totalTextWidth * 0.5;
  const brandStartX = startX + prefixWidth;
  const textY = 0;
  const ruleY = fontSize * 0.78;

  // Soft drop shadow + crisp white halo for the full continuous line
  ctx.save();
  ctx.shadowColor = 'rgba(15, 39, 68, 0.18)';
  ctx.shadowBlur = 9;
  ctx.shadowOffsetY = 2.5;
  ctx.lineWidth = 3.2;
  ctx.lineJoin = 'round';
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.82)';

  ctx.font = prefixFont;
  ctx.strokeText(prefixText, startX, textY);
  ctx.font = brandFont;
  ctx.strokeText(brandText, brandStartX, textY);
  ctx.restore();

  // Prefix fill: cool deep ocean slate-blue
  ctx.font = prefixFont;
  ctx.fillStyle = '#0F3A66';
  ctx.fillText(prefixText, startX, textY);

  // Brand fill: animated sapphire -> cyan -> teal -> gold gradient
  ctx.font = brandFont;
  const sweep = (Math.sin(elapsedTime * 1.25) * 0.5 + 0.5) * 0.5;
  const grad = ctx.createLinearGradient(
    brandStartX,
    textY - fontSize * 0.45,
    brandStartX + brandWidth,
    textY + fontSize * 0.45
  );
  grad.addColorStop(0, '#1E3A8A');
  grad.addColorStop(Math.max(0.08, 0.25 + sweep * 0.35), '#0284C7');
  grad.addColorStop(Math.min(0.86, 0.52 + sweep * 0.42), '#0D9488');
  grad.addColorStop(Math.min(0.96, 0.76 + sweep * 0.3), '#F59E0B');
  grad.addColorStop(1, '#1D4ED8');
  ctx.fillStyle = grad;
  ctx.fillText(brandText, brandStartX, textY);

  // Travelling specular light band gliding smoothly across the continuous line
  const glintCenter = ((elapsedTime * 0.42) % 1.8) - 0.4;
  if (glintCenter >= -0.2 && glintCenter <= 1.2) {
    const sheenGrad = ctx.createLinearGradient(
      startX,
      0,
      startX + totalTextWidth,
      0
    );
    const s0 = Math.max(0, Math.min(1, glintCenter - 0.14));
    const s1 = Math.max(0, Math.min(1, glintCenter));
    const s2 = Math.max(0, Math.min(1, glintCenter + 0.14));
    sheenGrad.addColorStop(s0, 'rgba(255, 255, 255, 0)');
    sheenGrad.addColorStop(s1, 'rgba(255, 255, 255, 0.52)');
    sheenGrad.addColorStop(s2, 'rgba(255, 255, 255, 0)');
    ctx.fillStyle = sheenGrad;
    ctx.font = prefixFont;
    ctx.fillText(prefixText, startX, textY);
    ctx.font = brandFont;
    ctx.fillText(brandText, brandStartX, textY);
  }

  // Sleek animated horizontal accent rule underneath the continuous line
  const lineHalf = Math.min(width * 0.36, totalTextWidth * 0.52);
  const lineGrad = ctx.createLinearGradient(-lineHalf, ruleY, lineHalf, ruleY);
  lineGrad.addColorStop(0, 'rgba(2, 132, 199, 0)');
  lineGrad.addColorStop(0.28, 'rgba(2, 132, 199, 0.55)');
  lineGrad.addColorStop(0.5, 'rgba(245, 158, 11, 0.78)');
  lineGrad.addColorStop(0.72, 'rgba(13, 148, 136, 0.55)');
  lineGrad.addColorStop(1, 'rgba(2, 132, 199, 0)');

  ctx.strokeStyle = lineGrad;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(-lineHalf, ruleY);
  ctx.lineTo(lineHalf, ruleY);
  ctx.stroke();

  const orbX = Math.sin(elapsedTime * 1.45) * (lineHalf * 0.65);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.92)';
  ctx.beginPath();
  ctx.arc(orbX, ruleY, 2.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.restore();
}

const BOKEH_MOTE_COUNT = 12;
const SPARKLE_MOTE_COUNT = 10;

function drawSkyBokehAndSparkles(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  elapsedTime: number,
  worldScroll: number,
  intensity: number
): void {
  if (intensity <= 0.005 || groundTop <= 60) return;

  ctx.save();
  ctx.beginPath();
  ctx.rect(0, 0, width, groundTop);
  ctx.clip();

  const span = width + 110;
  const usableHeight = Math.max(80, groundTop - 36);

  // Soft sunlit bokeh discs drifting slowly in the upper-mid sky
  for (let i = 0; i < BOKEH_MOTE_COUNT; i++) {
    const seedA = (i * 0.6180339887) % 1;
    const seedB = ((i * 0.3819660113) + 0.17) % 1;
    const radius = 10 + (i % 4) * 5.2 + seedB * 3.0;
    const driftSpeed = 6.5 + (i % 5) * 2.1;
    const rawX = seedA * span - (elapsedTime * driftSpeed + worldScroll * 0.048);
    const x = (((rawX % span) + span) % span) - 55;
    const baseY = 26 + seedB * (usableHeight * 0.82);
    const y = baseY + Math.sin(elapsedTime * (0.38 + (i % 3) * 0.12) + i * 1.37) * 14;
    const breathe = 0.68 + 0.32 * Math.sin(elapsedTime * 1.15 + i * 2.1);
    const alpha = intensity * breathe * (i % 3 === 0 ? 0.22 : 0.16);

    const grad = ctx.createRadialGradient(x, y, 0, x, y, radius);
    if (i % 3 === 0) {
      grad.addColorStop(0, `rgba(255, 250, 214, ${(alpha * 1.15).toFixed(3)})`);
      grad.addColorStop(0.65, `rgba(255, 244, 178, ${(alpha * 0.55).toFixed(3)})`);
      grad.addColorStop(1, 'rgba(255, 244, 178, 0)');
    } else {
      grad.addColorStop(0, `rgba(255, 255, 255, ${(alpha * 1.2).toFixed(3)})`);
      grad.addColorStop(0.68, `rgba(224, 247, 255, ${(alpha * 0.52).toFixed(3)})`);
      grad.addColorStop(1, 'rgba(224, 247, 255, 0)');
    }

    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();

    if (radius >= 16) {
      ctx.strokeStyle = `rgba(255, 255, 255, ${(alpha * 0.42).toFixed(3)})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(x, y, radius * 0.86, 0, Math.PI * 2);
      ctx.stroke();
    }
  }

  // Delicate 4-point sky sparkles with soft twinkle pulse
  for (let i = 0; i < SPARKLE_MOTE_COUNT; i++) {
    const seedA = ((i * 0.7548776662) + 0.31) % 1;
    const seedB = ((i * 0.569840291) + 0.09) % 1;
    const driftSpeed = 9.0 + (i % 4) * 2.6;
    const rawX = seedA * span - (elapsedTime * driftSpeed + worldScroll * 0.072);
    const x = (((rawX % span) + span) % span) - 55;
    const baseY = 22 + seedB * (usableHeight * 0.78);
    const y = baseY + Math.cos(elapsedTime * (0.55 + (i % 3) * 0.14) + i * 1.9) * 10;

    const pulseRaw = 0.5 + 0.5 * Math.sin(elapsedTime * (1.8 + (i % 3) * 0.5) + i * 2.4);
    const twinkle = pulseRaw * pulseRaw;
    const alpha = intensity * (0.12 + twinkle * 0.42);
    const arm = (3.4 + (i % 3) * 1.45) * (0.78 + twinkle * 0.34);

    // Subtle soft glow behind sparkle
    const glow = ctx.createRadialGradient(x, y, 0, x, y, arm * 1.9);
    glow.addColorStop(0, `rgba(255, 255, 255, ${(alpha * 0.55).toFixed(3)})`);
    glow.addColorStop(1, 'rgba(255, 255, 255, 0)');
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(x, y, arm * 1.9, 0, Math.PI * 2);
    ctx.fill();

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(elapsedTime * 0.25 + i * 0.4);
    ctx.fillStyle =
      i % 2 === 0
        ? `rgba(255, 255, 255, ${alpha.toFixed(3)})`
        : `rgba(255, 246, 189, ${alpha.toFixed(3)})`;

    const inner = arm * 0.26;
    ctx.beginPath();
    ctx.moveTo(0, -arm);
    ctx.quadraticCurveTo(inner * 0.65, -inner * 0.65, arm, 0);
    ctx.quadraticCurveTo(inner * 0.65, inner * 0.65, 0, arm);
    ctx.quadraticCurveTo(-inner * 0.65, inner * 0.65, -arm, 0);
    ctx.quadraticCurveTo(-inner * 0.65, -inner * 0.65, 0, -arm);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  ctx.restore();
}

function drawPastelHills(
  ctx: CanvasRenderingContext2D,
  width: number,
  groundTop: number,
  worldScroll: number,
  nightProgress: number
): void {
  const backColor = lerpThreeStageColor(
    '#FADDE6',
    '#8A639E',
    '#3B215C',
    nightProgress
  );
  const frontColor = lerpThreeStageColor(
    '#F5C3D3',
    '#6B4387',
    '#291347',
    nightProgress
  );
  drawHillWave(ctx, width, groundTop, 152, 52, 480, worldScroll * 0.16, backColor);
  drawHillWave(
    ctx,
    width,
    groundTop,
    84,
    34,
    390,
    worldScroll * 0.28 + 140,
    frontColor
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
