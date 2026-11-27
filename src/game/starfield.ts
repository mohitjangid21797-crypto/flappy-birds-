export interface StarSpec {
  seedX: number;
  seedY: number;
  radius: number;
  twinkleSpeed: number;
  phase: number;
  layer: 'far' | 'mid';
  tint: 'white' | 'cool' | 'warm';
}

export class Starfield {
  private readonly stars: readonly StarSpec[];
  private readonly farParallax = 0.024;
  private readonly midParallax = 0.048;

  constructor(farCount = 46, midCount = 20) {
    const items: StarSpec[] = [];
    const tints: ReadonlyArray<StarSpec['tint']> = ['white', 'cool', 'warm'];

    for (let i = 0; i < farCount; i++) {
      items.push({
        seedX: (i * 0.6180339887 + 0.07) % 1,
        seedY: (i * 0.3819660113 + 0.11) % 1,
        radius: 1.0 + (i % 3) * 0.45,
        twinkleSpeed: 2.8 + (i % 5) * 0.7,
        phase: i * 1.73,
        layer: 'far',
        tint: tints[i % 4 === 0 ? 2 : i % 3 === 0 ? 1 : 0],
      });
    }

    for (let i = 0; i < midCount; i++) {
      items.push({
        seedX: (i * 0.7548776662 + 0.23) % 1,
        seedY: (i * 0.569840291 + 0.05) % 1,
        radius: 3.1 + (i % 3) * 0.95,
        twinkleSpeed: 3.6 + (i % 4) * 0.9,
        phase: i * 2.47,
        layer: 'mid',
        tint: i % 3 === 0 ? 'cool' : i % 2 === 0 ? 'white' : 'warm',
      });
    }

    this.stars = items;
  }

  public render(
    ctx: CanvasRenderingContext2D,
    width: number,
    groundTop: number,
    elapsedTime: number,
    worldScroll: number,
    intensity = 1
  ): void {
    if (groundTop <= 80 || intensity <= 0.01) return;

    ctx.save();
    const starBandHeight = groundTop * 0.80;
    const span = width + 60;

    for (const star of this.stars) {
      const isFar = star.layer === 'far';
      const parallax = isFar ? this.farParallax : this.midParallax;
      const drift = isFar ? 1.4 : 2.6;
      const rawX =
        star.seedX * span - (worldScroll * parallax + elapsedTime * drift);
      const x = (((rawX % span) + span) % span) - 30;
      const y =
        12 + star.seedY * (starBandHeight * (isFar ? 0.88 : 0.78));
      const altFade = Math.max(0.22, 1 - (y / starBandHeight) * 0.68) * intensity;

      const primaryWave =
        0.5 + 0.5 * Math.sin(elapsedTime * star.twinkleSpeed + star.phase);
      const shimmerWave =
        0.5 +
        0.5 *
          Math.sin(elapsedTime * star.twinkleSpeed * 1.9 + star.phase * 1.4);

      if (isFar) {
        const flicker = 0.28 + 0.72 * Math.pow(primaryWave * 0.7 + shimmerWave * 0.3, 1.35);
        const alpha = Math.min(0.96, (0.36 + flicker * 0.62) * altFade);
        if (alpha <= 0.02) continue;

        const r = star.radius * (0.85 + flicker * 0.3);
        ctx.fillStyle = this.rgbaFor(star.tint, alpha);
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fill();
      } else {
        const flicker = Math.pow(primaryWave * 0.65 + shimmerWave * 0.35, 1.45);
        const alpha = Math.min(0.98, (0.36 + flicker * 0.66) * altFade);
        if (alpha <= 0.02) continue;

        const arm = star.radius + flicker * 1.8;
        const halo = ctx.createRadialGradient(x, y, 0, x, y, arm * 2.5);
        halo.addColorStop(0, this.rgbaFor(star.tint, alpha * 0.72));
        halo.addColorStop(0.45, this.rgbaFor(star.tint, alpha * 0.25));
        halo.addColorStop(1, 'rgba(255, 255, 255, 0)');
        ctx.fillStyle = halo;
        ctx.beginPath();
        ctx.arc(x, y, arm * 2.5, 0, Math.PI * 2);
        ctx.fill();

        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(elapsedTime * 0.32 + star.phase);
        ctx.fillStyle = this.rgbaFor(star.tint, alpha);
        const inner = arm * 0.24;
        ctx.beginPath();
        ctx.moveTo(0, -arm);
        ctx.quadraticCurveTo(inner, -inner, arm, 0);
        ctx.quadraticCurveTo(inner, inner, 0, arm);
        ctx.quadraticCurveTo(-inner, inner, -arm, 0);
        ctx.quadraticCurveTo(-inner, -inner, 0, -arm);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
      }
    }

    ctx.restore();
  }

  private rgbaFor(tint: StarSpec['tint'], alpha: number): string {
    const a = Math.max(0, Math.min(1, alpha)).toFixed(3);
    if (tint === 'warm') return `rgba(255, 238, 178, ${a})`;
    if (tint === 'cool') return `rgba(182, 232, 255, ${a})`;
    return `rgba(255, 255, 255, ${a})`;
  }
}
