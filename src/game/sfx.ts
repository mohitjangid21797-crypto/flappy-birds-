import { BirdSkin } from './types';

export type SoundType =
  | 'flap'
  | 'score'
  | 'heart'
  | 'shield'
  | 'hit'
  | 'die'
  | 'swoosh';

const SKIN_PITCH_SCALE: Record<BirdSkin, number> = {
  skyCap: 1.0,
  solarAce: 0.88,
  emeraldJet: 1.14,
};

class WebSoundEngine {
  private ctx: AudioContext | null = null;
  private noiseBuffer: AudioBuffer | null = null;
  private skin: BirdSkin = 'skyCap';
  public muted = false;

  public setSkin(skin: BirdSkin): void {
    this.skin = skin;
  }

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

  private getNoiseBuffer(ctx: AudioContext): AudioBuffer {
    if (this.noiseBuffer && this.noiseBuffer.sampleRate === ctx.sampleRate) {
      return this.noiseBuffer;
    }
    const length = Math.floor(ctx.sampleRate * 0.4);
    const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < length; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    this.noiseBuffer = buffer;
    return buffer;
  }

  private playFilteredNoise(
    ctx: AudioContext,
    now: number,
    duration: number,
    filterType: BiquadFilterType,
    startFreq: number,
    endFreq: number,
    peakGain: number,
    q = 1.2
  ): void {
    const src = ctx.createBufferSource();
    src.buffer = this.getNoiseBuffer(ctx);

    const filter = ctx.createBiquadFilter();
    filter.type = filterType;
    filter.Q.setValueAtTime(q, now);
    filter.frequency.setValueAtTime(startFreq, now);
    filter.frequency.exponentialRampToValueAtTime(
      Math.max(40, endFreq),
      now + duration
    );

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.001, now);
    gain.gain.linearRampToValueAtTime(
      peakGain,
      now + Math.min(0.014, duration * 0.28)
    );
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

    src.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    src.start(now);
    src.stop(now + duration);
  }

  private playBirdChirp(
    ctx: AudioContext,
    startTime: number,
    duration: number,
    startFreq: number,
    peakFreq: number,
    endFreq: number,
    peakGain: number,
    type: OscillatorType = 'sine',
    vibratoHz = 0,
    vibratoDepth = 0
  ): void {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;

    const peakTime = startTime + duration * 0.42;
    osc.frequency.setValueAtTime(Math.max(40, startFreq), startTime);
    osc.frequency.exponentialRampToValueAtTime(Math.max(40, peakFreq), peakTime);
    osc.frequency.exponentialRampToValueAtTime(
      Math.max(40, endFreq),
      startTime + duration
    );

    if (vibratoHz > 0 && vibratoDepth > 0) {
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      lfo.type = 'sine';
      lfo.frequency.setValueAtTime(vibratoHz, startTime);
      lfoGain.gain.setValueAtTime(vibratoDepth, startTime);
      lfo.connect(lfoGain);
      lfoGain.connect(osc.frequency);
      lfo.start(startTime);
      lfo.stop(startTime + duration);
    }

    gain.gain.setValueAtTime(0.001, startTime);
    gain.gain.linearRampToValueAtTime(
      peakGain,
      startTime + Math.min(0.012, duration * 0.25)
    );
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(startTime);
    osc.stop(startTime + duration);
  }

  private playBirdSquawk(
    ctx: AudioContext,
    startTime: number,
    duration: number,
    startFreq: number,
    endFreq: number,
    peakGain: number
  ): void {
    const osc = ctx.createOscillator();
    const filter = ctx.createBiquadFilter();
    const gain = ctx.createGain();

    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(startFreq, startTime);
    osc.frequency.exponentialRampToValueAtTime(
      Math.max(60, startFreq * 1.18),
      startTime + duration * 0.22
    );
    osc.frequency.exponentialRampToValueAtTime(
      Math.max(60, endFreq),
      startTime + duration
    );

    filter.type = 'bandpass';
    filter.Q.setValueAtTime(3.2, startTime);
    filter.frequency.setValueAtTime(startFreq * 1.65, startTime);
    filter.frequency.exponentialRampToValueAtTime(
      Math.max(180, endFreq * 1.4),
      startTime + duration
    );

    gain.gain.setValueAtTime(0.001, startTime);
    gain.gain.linearRampToValueAtTime(peakGain, startTime + 0.016);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    osc.start(startTime);
    osc.stop(startTime + duration);
  }

  public play(type: SoundType): void {
    if (this.muted) return;
    const ctx = this.getContext();
    if (!ctx) return;

    const now = ctx.currentTime;
    const pitch = SKIN_PITCH_SCALE[this.skin];
    const jitter = 0.95 + Math.random() * 0.1;

    if (type === 'flap') {
      // Crisp feather wing-flutter + cheerful bird "cheep!"
      this.playFilteredNoise(ctx, now, 0.07, 'bandpass', 920, 2400, 0.065, 1.5);
      this.playBirdChirp(
        ctx,
        now + 0.006,
        0.085,
        880 * pitch * jitter,
        1680 * pitch * jitter,
        1180 * pitch * jitter,
        0.09,
        'sine'
      );
      this.playBirdChirp(
        ctx,
        now + 0.01,
        0.065,
        1760 * pitch * jitter,
        2450 * pitch * jitter,
        1920 * pitch * jitter,
        0.028,
        'triangle'
      );
    } else if (type === 'score') {
      // Bright songbird double-tweet ("tweet-tweet!")
      this.playBirdChirp(
        ctx,
        now,
        0.065,
        1220 * pitch,
        1760 * pitch,
        1480 * pitch,
        0.085,
        'sine'
      );
      this.playBirdChirp(
        ctx,
        now + 0.07,
        0.13,
        1480 * pitch,
        2220 * pitch,
        1980 * pitch,
        0.1,
        'sine',
        26,
        35
      );
      this.playBirdChirp(
        ctx,
        now + 0.072,
        0.11,
        2960 * pitch,
        3520 * pitch,
        3120 * pitch,
        0.025,
        'triangle'
      );
    } else if (type === 'heart') {
      // Uplifting woodland canary 4-note trill
      const notes = [1046.5, 1318.5, 1568.0, 2093.0];
      notes.forEach((freq, idx) => {
        const t = now + idx * 0.048;
        const f = freq * pitch;
        this.playBirdChirp(
          ctx,
          t,
          0.11,
          f * 0.9,
          f * 1.12,
          f,
          0.08,
          'sine',
          28,
          28
        );
      });
    } else if (type === 'shield') {
      // Feathered wing burst + startled defensive bird trill
      this.playFilteredNoise(ctx, now, 0.14, 'bandpass', 1700, 620, 0.075, 1.4);
      this.playBirdSquawk(ctx, now, 0.14, 920 * pitch, 540 * pitch, 0.08);
      this.playBirdChirp(
        ctx,
        now + 0.07,
        0.14,
        1180 * pitch,
        1860 * pitch,
        1520 * pitch,
        0.075,
        'sine',
        32,
        40
      );
    } else if (type === 'hit') {
      // Hollow bonk + feather scatter + comical bird squawk
      this.playFilteredNoise(ctx, now, 0.13, 'lowpass', 1650, 220, 0.16);
      this.playBirdChirp(ctx, now, 0.14, 165, 120, 42, 0.18, 'sine');
      this.playBirdSquawk(ctx, now + 0.01, 0.17, 740 * pitch, 290 * pitch, 0.13);
    } else if (type === 'die') {
      // Dizzy descending bird whistle + tiny soft final peep
      this.playBirdChirp(
        ctx,
        now + 0.03,
        0.34,
        1420 * pitch,
        1180 * pitch,
        290 * pitch,
        0.095,
        'sine',
        18,
        55
      );
      this.playBirdChirp(
        ctx,
        now + 0.35,
        0.075,
        520 * pitch,
        460 * pitch,
        260 * pitch,
        0.055,
        'triangle'
      );
    } else if (type === 'swoosh') {
      // Airy wing-glide breeze + light bird flit chirp
      this.playFilteredNoise(ctx, now, 0.1, 'bandpass', 520, 1950, 0.05, 1.3);
      this.playBirdChirp(
        ctx,
        now + 0.01,
        0.07,
        920 * pitch * jitter,
        1380 * pitch * jitter,
        1140 * pitch * jitter,
        0.048,
        'sine'
      );
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
