import { BirdSkin } from './types';

export interface DailyRunEntry {
  id: string;
  score: number;
  heartsCollected: number;
  skin: BirdSkin;
  timestamp: number;
}

export interface DailyChallengeStorage {
  dateKey: string;
  bestScore: number;
  attempts: number;
  runs: DailyRunEntry[];
}

export interface DailyCourseProfile {
  dateKey: string;
  seed: number;
  title: string;
  pipeSpeed: number;
  pipeGap: number;
  pipeSpacing: number;
}

export interface DailyLeaderboardRow {
  id: string;
  rank: number;
  name: string;
  score: number;
  isPlayer: boolean;
  isPlayerBest: boolean;
  skin?: BirdSkin;
  heartsCollected?: number;
  subtitle: string;
}

const DAILY_STORAGE_KEY = 'flappy_daily_leaderboard_v1';

const COURSE_TITLES = [
  'Emerald Gauntlet',
  'Propeller Canyon',
  'Beacon Blitz',
  'Pastel Horizon',
  'Skyline Drift',
  'Cloud Runner',
  'Golden Gate Run',
];

export function getDailyDateKey(now: Date = new Date()): string {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function getCountdownToReset(now: Date = new Date()): string {
  const nextMidnight = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate() + 1,
    0,
    0,
    0,
    0
  );
  const diffSec = Math.max(
    0,
    Math.floor((nextMidnight.getTime() - now.getTime()) / 1000)
  );
  const h = String(Math.floor(diffSec / 3600)).padStart(2, '0');
  const m = String(Math.floor((diffSec % 3600) / 60)).padStart(2, '0');
  const s = String(diffSec % 60).padStart(2, '0');
  return `${h}:${m}:${s}`;
}

export function hashDateKey(dateKey: string): number {
  let hash = 2166136261;
  for (let i = 0; i < dateKey.length; i++) {
    hash ^= dateKey.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

export function createSeededRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function getDailyCourseProfile(
  dateKey: string = getDailyDateKey()
): DailyCourseProfile {
  const seed = hashDateKey(dateKey);
  const rng = createSeededRng(seed);
  const titleIndex = Math.floor(rng() * COURSE_TITLES.length);
  const speedOffset = Math.floor(rng() * 22);
  const gapOffset = Math.floor(rng() * 14);
  const spacingOffset = Math.floor(rng() * 18);

  return {
    dateKey,
    seed,
    title: COURSE_TITLES[titleIndex],
    pipeSpeed: 214 + speedOffset,
    pipeGap: 142 + gapOffset,
    pipeSpacing: 248 + spacingOffset,
  };
}

export function loadDailyStorage(
  dateKey: string = getDailyDateKey()
): DailyChallengeStorage {
  const empty: DailyChallengeStorage = {
    dateKey,
    bestScore: 0,
    attempts: 0,
    runs: [],
  };
  try {
    const raw = window.localStorage.getItem(DAILY_STORAGE_KEY);
    if (!raw) return empty;
    const parsed = JSON.parse(raw) as DailyChallengeStorage;
    if (!parsed || parsed.dateKey !== dateKey) {
      window.localStorage.setItem(DAILY_STORAGE_KEY, JSON.stringify(empty));
      return empty;
    }
    return {
      dateKey,
      bestScore: typeof parsed.bestScore === 'number' ? parsed.bestScore : 0,
      attempts: typeof parsed.attempts === 'number' ? parsed.attempts : 0,
      runs: Array.isArray(parsed.runs) ? parsed.runs : [],
    };
  } catch {
    return empty;
  }
}

export function recordDailyRun(
  entry: Omit<DailyRunEntry, 'id' | 'timestamp'>,
  dateKey: string = getDailyDateKey()
): { storage: DailyChallengeStorage; isNewDailyBest: boolean } {
  const current = loadDailyStorage(dateKey);
  const newRun: DailyRunEntry = {
    ...entry,
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    timestamp: Date.now(),
  };

  const updatedRuns = [newRun, ...current.runs]
    .sort((a, b) => b.score - a.score || b.timestamp - a.timestamp)
    .slice(0, 10);

  const isNewDailyBest = entry.score > current.bestScore;
  const updated: DailyChallengeStorage = {
    dateKey,
    bestScore: Math.max(current.bestScore, entry.score),
    attempts: current.attempts + 1,
    runs: updatedRuns,
  };

  try {
    window.localStorage.setItem(DAILY_STORAGE_KEY, JSON.stringify(updated));
  } catch {
    // Ignore storage quota errors
  }

  return { storage: updated, isNewDailyBest };
}

export function buildDailyLeaderboard(
  storage: DailyChallengeStorage
): DailyLeaderboardRow[] {
  const seed = hashDateKey(storage.dateKey);
  const rng = createSeededRng(seed ^ 0x9e3779b9);

  const benchmarks = [
    {
      id: 'target_champion',
      name: '2130 Ace Bot',
      score: 28 + Math.floor(rng() * 10),
      subtitle: 'Daily Champion Target',
    },
    {
      id: 'target_gold',
      name: 'Sky Captain Bot',
      score: 18 + Math.floor(rng() * 7),
      subtitle: 'Daily Gold Target',
    },
    {
      id: 'target_silver',
      name: 'Feather Pro Bot',
      score: 10 + Math.floor(rng() * 6),
      subtitle: 'Daily Silver Target',
    },
    {
      id: 'target_bronze',
      name: 'Rookie Wing Bot',
      score: 4 + Math.floor(rng() * 4),
      subtitle: 'Daily Starter Target',
    },
  ];

  interface RawRow {
    id: string;
    name: string;
    score: number;
    isPlayer: boolean;
    isPlayerBest: boolean;
    skin?: BirdSkin;
    heartsCollected?: number;
    subtitle: string;
  }

  const combined: RawRow[] = benchmarks.map((b) => ({
    ...b,
    isPlayer: false,
    isPlayerBest: false,
  }));

  if (storage.runs.length > 0) {
    storage.runs.slice(0, 5).forEach((run, idx) => {
      const isBest = idx === 0 && run.score === storage.bestScore;
      combined.push({
        id: run.id,
        name: isBest ? 'You (Daily Best)' : `You (Run #${idx + 1})`,
        score: run.score,
        isPlayer: true,
        isPlayerBest: isBest,
        skin: run.skin,
        heartsCollected: run.heartsCollected,
        subtitle: new Date(run.timestamp).toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit',
        }),
      });
    });
  }

  combined.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (a.isPlayer !== b.isPlayer) return a.isPlayer ? -1 : 1;
    return 0;
  });

  return combined.map((row, idx) => ({
    ...row,
    rank: idx + 1,
  }));
}
