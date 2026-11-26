import { BirdSkin } from './types';

export type SoundType =
  | 'flap'
  | 'score'
  | 'milestone'
  | 'heart'
  | 'shield'
  | 'hit'
  | 'die'
  | 'swoosh';

const SKIN_PITCH_SCALE: Record<BirdSkin, number> = {
  skyCap: 1.0,
  solarAce: 0.9,
  emeraldJet: 1.12,
};

// Cmaj7 -> Am7 -> Fmaj7 -> G6 daytime sky arcade groove (120 BPM, 0.25s per eighth note)
const BGM_BARS: ReadonlyArray<{ bass: number; arp: readonly number[] }> = [
  { bass: 130.81, arp: [523.25, 659.25, 783.99, 987.77, 783.99, 659.25, 523.25, 783.99] },
  { bass: 110.0, arp: [440.0, 523.25, 659.25, 783.99, 659.25, 523.25, 440.0, 659.25] },
  { bass: 174.61, arp: [523.25, 698.46, 880.0, 1046.5, 880.0, 698.46, 523.25, 880.0] },
  { bass: 196.0, arp: [587.33, 783.99, 987.77, 1174.66, 987.77, 783.99, 659.25, 783.99] },
];

class WebSoundEngine {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private sfxBus: GainNode | null = null;
  private bgmBus: GainNode | null = null;
  private noiseBuffer: AudioBuffer | null = null;
  private skin: BirdSkin = 'skyCap';
  private _muted = false;
  private _paused = false;
  private bgmWanted = false;
  private bgmTimer: number | null = null;
  private bgmStep = 0;
  private bgmNextTime = 0;
  private unlockBound = false;
  private audioUnlocked = false;

  constructor() {
    this.bindMobileUnlock();
  }

  public get muted(): boolean {
    return this._muted;
  }

  public set muted(value: boolean) {
    this._muted = value;
    if (this.masterGain && this.ctx) {
      this.masterGain.gain.setTargetAtTime(
        value ? 0 : 0.92,
        this.ctx.currentTime,
        0.015
      );
    }
    this.syncBgmLoop();
  }

  public setPaused(paused: boolean): void {
    this._paused = paused;
    this.syncBgmLoop();
  }

  public setSkin(skin: BirdSkin): void {
    this.skin = skin;
  }

  private configureAudioSession(): void {
    if (typeof navigator === 'undefined') return;
    try {
      const nav = navigator as unknown as {
        audioSession?: { type: string };
      };
      if (nav.audioSession && nav.audioSession.type !== 'playback') {
        nav.audioSession.type = 'playback';
      }
    } catch {
      // Ignore unsupported audioSession APIs
    }
  }

  private bindMobileUnlock(): void {
    if (typeof window === 'undefined' || this.unlockBound) return;
    this.unlockBound = true;

    const unlock = () => {
      this.configureAudioSession();
      const ctx = this.ensureContext();
      if (!ctx) return;
      if (ctx.state !== 'running') {
        ctx.resume().catch(() => {});
      }
      if (!this.audioUnlocked) {
        try {
          // 1-sample silent buffer inside user gesture unlocks iOS Safari & Android Chrome WebAudio
          const silent = ctx.createBuffer(1, 1, ctx.sampleRate);
          const src = ctx.createBufferSource();
          const silentGain = ctx.createGain();
          silentGain.gain.value = 0;
          src.buffer = silent;
          src.connect(silentGain);
          silentGain.connect(ctx.destination);
          src.start(0);
          this.audioUnlocked = true;
        } catch {
          // Ignore unlock errors
        }
      }
      this.syncBgmLoop();
    };

    const events = ['pointerdown', 'touchstart', 'touchend', 'mousedown', 'keydown'];
    for (const evt of events) {
      window.addEventListener(evt, unlock, { capture: true, passive: true });
    }

    document.addEventListener('visibilitychange', () => {
      this.syncBgmLoop();
    });
    window.addEventListener('pagehide', () => {
      this.stopBgmScheduler();
    });
  }

  private ensureContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext?: typeof AudioContext })
          .webkitAudioContext;
      if (!AudioCtx) return null;

      const ctx = new AudioCtx({ latencyHint: 'interactive' });
      const compressor = ctx.createDynamicsCompressor();
      compressor.threshold.setValueAtTime(-12, ctx.currentTime);
      compressor.knee.setValueAtTime(16, ctx.currentTime);
      compressor.ratio.setValueAtTime(6, ctx.currentTime);
      compressor.attack.setValueAtTime(0.003, ctx.currentTime);
      compressor.release.setValueAtTime(0.12, ctx.currentTime);

      const master = ctx.createGain();
      master.gain.setValueAtTime(this._muted ? 0 : 0.92, ctx.currentTime);

      const sfx = ctx.createGain();
      sfx.gain.setValueAtTime(1.0, ctx.currentTime);

      const bgm = ctx.createGain();
      bgm.gain.setValueAtTime(0.28, ctx.currentTime);

      sfx.connect(compressor);
      bgm.connect(compressor);
      compressor.connect(master);
      master.connect(ctx.destination);

      this.ctx = ctx;
      this.masterGain = master;
      this.sfxBus = sfx;
      this.bgmBus = bgm;
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
    bus: GainNode,
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
    gain.gain.setValueAtTime(0.0008, now);
    gain.gain.linearRampToValueAtTime(
      peakGain,
      now + Math.min(0.012, duration * 0.25)
    );
    gain.gain.exponentialRampToValueAtTime(0.0008, now + duration);

    src.connect(filter);
    filter.connect(gain);
    gain.connect(bus);
    src.start(now);
    src.stop(now + duration);
  }

  private playTone(
    ctx: AudioContext,
    bus: GainNode,
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

    gain.gain.setValueAtTime(0.0008, startTime);
    gain.gain.linearRampToValueAtTime(
      peakGain,
      startTime + Math.min(0.01, duration * 0.22)
    );
    gain.gain.exponentialRampToValueAtTime(0.0008, startTime + duration);

    osc.connect(gain);
    gain.connect(bus);
    osc.start(startTime);
    osc.stop(startTime + duration);
  }

  private playMarimbaNote(
    ctx: AudioContext,
    bus: GainNode,
    startTime: number,
    duration: number,
    freq: number,
    peakGain: number
  ): void {
    this.playTone(
      ctx,
      bus,
      startTime,
      duration,
      freq * 0.995,
      freq * 1.004,
      freq,
      peakGain,
      'sine'
    );
    this.playTone(
      ctx,
      bus,
      startTime,
      duration * 0.45,
      freq * 2,
      freq * 2,
      freq * 2,
      peakGain * 0.26,
      'triangle'
    );
  }

  private playSquawk(
    ctx: AudioContext,
    bus: GainNode,
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
      Math.max(60, startFreq * 1.12),
      startTime + duration * 0.2
    );
    osc.frequency.exponentialRampToValueAtTime(
      Math.max(60, endFreq),
      startTime + duration
    );

    filter.type = 'bandpass';
    filter.Q.setValueAtTime(2.6, startTime);
    filter.frequency.setValueAtTime(startFreq * 1.65, startTime);
    filter.frequency.exponentialRampToValueAtTime(
      Math.max(180, endFreq * 1.35),
      startTime + duration
    );

    gain.gain.setValueAtTime(0.0008, startTime);
    gain.gain.linearRampToValueAtTime(peakGain, startTime + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0008, startTime + duration);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(bus);
    osc.start(startTime);
    osc.stop(startTime + duration);
  }

  private stopBgmScheduler(): void {
    if (this.bgmTimer !== null) {
      window.clearInterval(this.bgmTimer);
      this.bgmTimer = null;
    }
  }

  private syncBgmLoop(): void {
    const isHidden = typeof document !== 'undefined' && document.hidden;
    const shouldPlay =
      this.bgmWanted && !this._muted && !this._paused && !isHidden;

    if (!shouldPlay) {
      this.stopBgmScheduler();
      return;
    }

    const ctx = this.ensureContext();
    if (!ctx || ctx.state !== 'running') return;
    if (this.bgmTimer !== null) return;

    this.bgmNextTime = ctx.currentTime + 0.05;
    this.bgmTimer = window.setInterval(() => {
      this.scheduleBgmWindow();
    }, 90);
  }

  private scheduleBgmWindow(): void {
    const ctx = this.ctx;
    const bus = this.bgmBus;
    if (!ctx || !bus || ctx.state !== 'running' || this._muted || this._paused) {
      return;
    }

    const stepDur = 0.25; // 120 BPM eighth note
    while (this.bgmNextTime < ctx.currentTime + 0.28) {
      const barIdx = Math.floor(this.bgmStep / 8) % BGM_BARS.length;
      const stepInBar = this.bgmStep % 8;
      const bar = BGM_BARS[barIdx];
      const t = this.bgmNextTime;

      // Sunny marimba arpeggio
      const arpFreq = bar.arp[stepInBar];
      this.playMarimbaNote(
        ctx,
        bus,
        t,
        0.2,
        arpFreq,
        stepInBar % 2 === 0 ? 0.14 : 0.095
      );

      // Warm bass pulse on beats 1, 2-and, 3, 4-and
      if (stepInBar === 0 || stepInBar === 3 || stepInBar === 4 || stepInBar === 7) {
        this.playTone(
          ctx,
          bus,
          t,
          0.22,
          bar.bass,
          bar.bass,
          bar.bass * 0.99,
          stepInBar === 0 || stepInBar === 4 ? 0.18 : 0.12,
          'sine'
        );
      }

      // Soft offbeat shaker shimmer
      if (stepInBar % 2 === 1) {
        this.playFilteredNoise(ctx, bus, t, 0.035, 'bandpass', 5400, 7400, 0.03, 2.0);
      }

      this.bgmNextTime += stepDur;
      this.bgmStep = (this.bgmStep + 1) % (BGM_BARS.length * 8);
    }
  }

  public startBgm(reset = true): void {
    if (reset) {
      this.bgmStep = 0;
    }
    this.bgmWanted = true;
    this._paused = false;
    this.configureAudioSession();
    const ctx = this.ensureContext();
    if (!ctx) return;
    if (ctx.state !== 'running') {
      ctx
        .resume()
        .then(() => {
          this.syncBgmLoop();
        })
        .catch(() => {});
      return;
    }
    this.syncBgmLoop();
  }

  public stopBgm(): void {
    this.bgmWanted = false;
    this._paused = false;
    this.bgmStep = 0;
    this.stopBgmScheduler();
  }

  public play(type: SoundType): void {
    if (this._muted) return;

    this.configureAudioSession();
    const ctx = this.ensureContext();
    if (!ctx || !this.sfxBus) return;

    if (ctx.state !== 'running') {
      ctx
        .resume()
        .then(() => {
          this.syncBgmLoop();
          this.triggerSound(ctx, type);
        })
        .catch(() => {});
      return;
    }

    this.syncBgmLoop();
    this.triggerSound(ctx, type);
  }

  private triggerSound(ctx: AudioContext, type: SoundType): void {
    const bus = this.sfxBus;
    if (!bus || this._muted) return;

    const now = ctx.currentTime;
    const pitch = SKIN_PITCH_SCALE[this.skin];
    const jitter = 0.97 + Math.random() * 0.06;

    if (type === 'flap') {
      this.playFilteredNoise(ctx, bus, now, 0.075, 'bandpass', 850, 2600, 0.14, 1.6);
      this.playMarimbaNote(ctx, bus, now + 0.004, 0.085, 987.77 * pitch * jitter, 0.24);
      this.playTone(
        ctx,
        bus,
        now + 0.008,
        0.065,
        1396.91 * pitch * jitter,
        2093 * pitch * jitter,
        1661.22 * pitch * jitter,
        0.09,
        'triangle'
      );
    } else if (type === 'score') {
      this.playMarimbaNote(ctx, bus, now, 0.09, 987.77 * pitch, 0.24);
      this.playMarimbaNote(ctx, bus, now + 0.068, 0.19, 1318.51 * pitch, 0.30);
      this.playTone(
        ctx,
        bus,
        now + 0.07,
        0.14,
        2637.02 * pitch,
        2680 * pitch,
        2637.02 * pitch,
        0.08,
        'sine',
        18,
        14
      );
    } else if (type === 'milestone') {
      const notes = [659.25, 830.61, 987.77, 1318.51];
      notes.forEach((freq, idx) => {
        const t = now + idx * 0.065;
        const f = freq * pitch;
        this.playMarimbaNote(ctx, bus, t, idx === 3 ? 0.25 : 0.12, f, 0.25);
        this.playTone(ctx, bus, t, 0.12, f * 2, f * 2.02, f * 2, 0.07, 'sine');
      });
    } else if (type === 'heart') {
      const notes = [1046.5, 1318.51, 1567.98, 2093.0];
      notes.forEach((freq, idx) => {
        const t = now + idx * 0.052;
        const f = freq * pitch;
        this.playMarimbaNote(ctx, bus, t, 0.14, f, 0.22);
      });
    } else if (type === 'shield') {
      this.playFilteredNoise(ctx, bus, now, 0.15, 'bandpass', 2200, 620, 0.18, 1.5);
      this.playSquawk(ctx, bus, now, 0.14, 783.99 * pitch, 987.77 * pitch, 0.18);
      this.playMarimbaNote(ctx, bus, now + 0.05, 0.24, 1567.98 * pitch, 0.24);
      this.playTone(
        ctx,
        bus,
        now + 0.06,
        0.22,
        1975.53 * pitch,
        2349.32 * pitch,
        1975.53 * pitch,
        0.09,
        'sine',
        24,
        18
      );
    } else if (type === 'hit') {
      this.playFilteredNoise(ctx, bus, now, 0.13, 'lowpass', 1850, 190, 0.34);
      this.playTone(ctx, bus, now, 0.16, 175, 120, 42, 0.42, 'sine');
      this.playSquawk(ctx, bus, now + 0.008, 0.18, 620 * pitch, 195 * pitch, 0.22);
    } else if (type === 'die') {
      const dnotes = [
        [0.02, 880.0, 0.11],
        [0.11, 698.46, 0.11],
        [0.2, 587.33, 0.12],
        [0.29, 440.0, 0.18],
      ] as const;
      for (const [offset, freq, dur] of dnotes) {
        const f = freq * pitch;
        this.playTone(ctx, bus, now + offset, dur, f * 1.03, f, f * 0.88, 0.21, 'triangle', 14, 10);
        this.playTone(ctx, bus, now + offset, dur, f * 0.5, f * 0.48, f * 0.42, 0.11, 'sine');
      }
    } else if (type === 'swoosh') {
      this.playFilteredNoise(ctx, bus, now, 0.11, 'bandpass', 520, 2100, 0.12, 1.4);
      this.playMarimbaNote(ctx, bus, now + 0.01, 0.08, 880 * pitch * jitter, 0.16);
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
