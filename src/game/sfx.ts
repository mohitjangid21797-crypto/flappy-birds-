export type SoundType =
  | 'flap'
  | 'score'
  | 'heart'
  | 'shield'
  | 'hit'
  | 'die'
  | 'swoosh';

class WebSoundEngine {
  private ctx: AudioContext | null = null;
  public muted = false;

  private getContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext?: typeof AudioContext })
          .webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  public play(type: SoundType): void {
    if (this.muted) return;
    const ctx = this.getContext();
    if (!ctx) return;

    const now = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);

    if (type === 'flap') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(360, now);
      osc.frequency.exponentialRampToValueAtTime(620, now + 0.08);
      gain.gain.setValueAtTime(0.11, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);
      osc.start(now);
      osc.stop(now + 0.09);
    } else if (type === 'score') {
      osc.type = 'square';
      osc.frequency.setValueAtTime(660, now);
      osc.frequency.setValueAtTime(990, now + 0.06);
      gain.gain.setValueAtTime(0.07, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
      osc.start(now);
      osc.stop(now + 0.18);
    } else if (type === 'heart') {
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(523, now);
      osc.frequency.setValueAtTime(659, now + 0.06);
      osc.frequency.setValueAtTime(784, now + 0.12);
      osc.frequency.setValueAtTime(1046, now + 0.18);
      gain.gain.setValueAtTime(0.13, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.28);
      osc.start(now);
      osc.stop(now + 0.28);
    } else if (type === 'shield') {
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(480, now);
      osc.frequency.exponentialRampToValueAtTime(220, now + 0.2);
      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);
      osc.start(now);
      osc.stop(now + 0.22);
    } else if (type === 'hit') {
      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(170, now);
      osc.frequency.exponentialRampToValueAtTime(48, now + 0.16);
      gain.gain.setValueAtTime(0.15, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.17);
      osc.start(now);
      osc.stop(now + 0.17);
    } else if (type === 'die') {
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(320, now + 0.05);
      osc.frequency.exponentialRampToValueAtTime(110, now + 0.28);
      gain.gain.setValueAtTime(0.1, now + 0.05);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.29);
      osc.start(now + 0.05);
      osc.stop(now + 0.29);
    } else if (type === 'swoosh') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(240, now);
      osc.frequency.exponentialRampToValueAtTime(420, now + 0.07);
      gain.gain.setValueAtTime(0.06, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
      osc.start(now);
      osc.stop(now + 0.08);
    }
  }
}

export const soundEngine = new WebSoundEngine();

export function loadBestScore(): number {
  try {
    const raw = window.localStorage.getItem('flappy_best_score');
    return raw ? parseInt(raw, 10) || 0 : 0;
  } catch {
    return 0;
  }
}

export function saveBestScore(score: number): void {
  try {
    window.localStorage.setItem('flappy_best_score', String(score));
  } catch {
    // Ignore storage quota errors
  }
}
