export type GamePhase = 'ready' | 'playing' | 'paused' | 'dying' | 'gameOver';

export type GameMode = 'heartRun' | 'dailyChallenge' | 'classic' | 'speedUp';

export type BirdSkin = 'skyCap' | 'solarAce' | 'emeraldJet';

export type ObstacleKind =
  | 'emeraldCylinder'
  | 'hoverPropellerGate'
  | 'beaconTower';

export type MedalTier = 'NONE' | 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM';

export interface ModeConfig {
  id: GameMode;
  label: string;
  subtitle: string;
  pipeSpeed: number;
  pipeGap: number;
  pipeSpacing: number;
  heartsEnabled: boolean;
  accelerates: boolean;
  isDaily: boolean;
}

export const GAME_MODES: Record<GameMode, ModeConfig> = {
  heartRun: {
    id: 'heartRun',
    label: 'Heart Run',
    subtitle: '3D moving gates & collectible hearts for extra shield lives',
    pipeSpeed: 215,
    pipeGap: 156,
    pipeSpacing: 268,
    heartsEnabled: true,
    accelerates: false,
    isDaily: false,
  },
  dailyChallenge: {
    id: 'dailyChallenge',
    label: 'Daily Challenge',
    subtitle: 'Fixed 24h obstacle layout · Compete for the daily leaderboard',
    pipeSpeed: 220,
    pipeGap: 148,
    pipeSpacing: 256,
    heartsEnabled: true,
    accelerates: false,
    isDaily: true,
  },
  classic: {
    id: 'classic',
    label: 'Classic',
    subtitle: 'Pure 1-life arcade run through 3D sky pillars',
    pipeSpeed: 220,
    pipeGap: 148,
    pipeSpacing: 256,
    heartsEnabled: false,
    accelerates: false,
    isDaily: false,
  },
  speedUp: {
    id: 'speedUp',
    label: 'Speed Up',
    subtitle: 'Speed ramps up with every point + collectible shield hearts',
    pipeSpeed: 210,
    pipeGap: 152,
    pipeSpacing: 262,
    heartsEnabled: true,
    accelerates: true,
    isDaily: false,
  },
};

export interface SkinPalette {
  id: BirdSkin;
  label: string;
  primaryLight: string;
  primaryMid: string;
  primaryDark: string;
  hatCrown: string;
  hatShade: string;
}

export const BIRD_SKINS: Record<BirdSkin, SkinPalette> = {
  skyCap: {
    id: 'skyCap',
    label: 'Sky Cap',
    primaryLight: '#A8ECFF',
    primaryMid: '#42C2FA',
    primaryDark: '#177BB8',
    hatCrown: '#A8703C',
    hatShade: '#6B411C',
  },
  solarAce: {
    id: 'solarAce',
    label: 'Solar Ace',
    primaryLight: '#FFF099',
    primaryMid: '#F59E0B',
    primaryDark: '#B45309',
    hatCrown: '#334155',
    hatShade: '#1E293B',
  },
  emeraldJet: {
    id: 'emeraldJet',
    label: 'Emerald Jet',
    primaryLight: '#A7F3D0',
    primaryMid: '#10B981',
    primaryDark: '#047857',
    hatCrown: '#B91C1C',
    hatShade: '#7F1D1D',
  },
};

export const PHYSICS = {
  gravity: 1480,
  flapVelocity: -455,
  maxFallSpeed: 620,
  groundHeight: 82,
  birdHitRadius: 15,
  pipeWidth: 72,
  pipeCapOverhang: 6,
  pipeCapHeight: 28,
  obstacle3dDepth: 12,
  maxHearts: 3,
};

export interface PipePair {
  x: number;
  baseGapCenterY: number;
  gapHeight: number;
  kind: ObstacleKind;
  hoverAmplitude: number;
  hoverSpeed: number;
  phase: number;
  passed: boolean;
}

export interface HeartPickup {
  x: number;
  baseY: number;
  phase: number;
  collected: boolean;
}

export interface SkyCloud {
  x: number;
  y: number;
  scale: number;
  speedFactor: number;
}

export type ParticleKind = 'burst' | 'trail' | 'feather';

export interface FlapParticle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: number;
  life: number;
  maxLife: number;
  color: string;
  kind?: ParticleKind;
  gravity?: number;
  drag?: number;
  rotation?: number;
  spin?: number;
}

export interface FloatingFeedback {
  x: number;
  y: number;
  text: string;
  color: string;
  life: number;
  maxLife: number;
}

export function getPipeBoundsAt(
  pipe: PipePair,
  elapsedTime: number
): { topBottom: number; bottomTop: number; gapCenterY: number } {
  const offset =
    pipe.hoverAmplitude > 0.01
      ? Math.sin(elapsedTime * pipe.hoverSpeed + pipe.phase) *
        pipe.hoverAmplitude
      : 0;
  const gapCenterY = pipe.baseGapCenterY + offset;
  return {
    gapCenterY,
    topBottom: gapCenterY - pipe.gapHeight / 2,
    bottomTop: gapCenterY + pipe.gapHeight / 2,
  };
}

export function getMedalFromScore(score: number): MedalTier {
  if (score >= 40) return 'PLATINUM';
  if (score >= 30) return 'GOLD';
  if (score >= 20) return 'SILVER';
  if (score >= 10) return 'BRONZE';
  return 'NONE';
}
