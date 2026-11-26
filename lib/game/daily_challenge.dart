import 'dart:convert';

import 'game_config.dart';

class SeededRng {
  SeededRng(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  double nextDouble() {
    // 32-bit LCG safe across both Dart VM and Dart2JS/DDC
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _state / 4294967296.0;
  }

  int nextInt(int max) => (nextDouble() * max).floor().clamp(0, max - 1);
}

class DailyRunEntry {
  const DailyRunEntry({
    required this.id,
    required this.score,
    required this.heartsCollected,
    required this.skin,
    required this.timestampMs,
  });

  final String id;
  final int score;
  final int heartsCollected;
  final BirdSkin skin;
  final int timestampMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'score': score,
        'heartsCollected': heartsCollected,
        'skin': skin.name,
        'timestampMs': timestampMs,
      };

  factory DailyRunEntry.fromJson(Map<String, dynamic> json) {
    final String skinName = (json['skin'] as String?) ?? 'skyCap';
    final BirdSkin skin = BirdSkin.values.firstWhere(
      (s) => s.name == skinName,
      orElse: () => BirdSkin.skyCap,
    );
    return DailyRunEntry(
      id: (json['id'] as String?) ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      heartsCollected: (json['heartsCollected'] as num?)?.toInt() ?? 0,
      skin: skin,
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyChallengeStorage {
  const DailyChallengeStorage({
    required this.dateKey,
    required this.bestScore,
    required this.attempts,
    required this.runs,
  });

  final String dateKey;
  final int bestScore;
  final int attempts;
  final List<DailyRunEntry> runs;

  factory DailyChallengeStorage.empty(String dateKey) => DailyChallengeStorage(
        dateKey: dateKey,
        bestScore: 0,
        attempts: 0,
        runs: const [],
      );

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'bestScore': bestScore,
        'attempts': attempts,
        'runs': runs.map((r) => r.toJson()).toList(),
      };

  static DailyChallengeStorage fromRawJson(String? raw, String dateKey) {
    if (raw == null || raw.isEmpty) {
      return DailyChallengeStorage.empty(dateKey);
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['dateKey'] != dateKey) {
        return DailyChallengeStorage.empty(dateKey);
      }
      final List<dynamic> rawRuns = (decoded['runs'] as List<dynamic>?) ?? [];
      return DailyChallengeStorage(
        dateKey: dateKey,
        bestScore: (decoded['bestScore'] as num?)?.toInt() ?? 0,
        attempts: (decoded['attempts'] as num?)?.toInt() ?? 0,
        runs: rawRuns
            .whereType<Map<String, dynamic>>()
            .map(DailyRunEntry.fromJson)
            .toList(),
      );
    } catch (_) {
      return DailyChallengeStorage.empty(dateKey);
    }
  }
}

class DailyCourseProfile {
  const DailyCourseProfile({
    required this.dateKey,
    required this.seed,
    required this.title,
    required this.pipeSpeed,
    required this.pipeGap,
    required this.pipeSpacing,
  });

  final String dateKey;
  final int seed;
  final String title;
  final double pipeSpeed;
  final double pipeGap;
  final double pipeSpacing;
}

class DailyLeaderboardRow {
  const DailyLeaderboardRow({
    required this.id,
    required this.rank,
    required this.name,
    required this.score,
    required this.isPlayer,
    required this.isPlayerBest,
    required this.subtitle,
    this.skin,
  });

  final String id;
  final int rank;
  final String name;
  final int score;
  final bool isPlayer;
  final bool isPlayerBest;
  final String subtitle;
  final BirdSkin? skin;
}

class DailyChallengeService {
  static const List<String> _courseTitles = [
    'Emerald Gauntlet',
    'Propeller Canyon',
    'Beacon Blitz',
    'Pastel Horizon',
    'Skyline Drift',
    'Cloud Runner',
    'Golden Gate Run',
  ];

  static String getDailyDateKey([DateTime? now]) {
    final DateTime d = now ?? DateTime.now();
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String getCountdownToReset([DateTime? now]) {
    final DateTime d = now ?? DateTime.now();
    final DateTime nextMidnight = DateTime(d.year, d.month, d.day + 1);
    final int sec = nextMidnight.difference(d).inSeconds.clamp(0, 86400);
    final String h = (sec ~/ 3600).toString().padLeft(2, '0');
    final String m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final String s = (sec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static int hashDateKey(String dateKey) {
    int hash = 2166136261;
    for (int i = 0; i < dateKey.length; i++) {
      hash ^= dateKey.codeUnitAt(i);
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash;
  }

  static DailyCourseProfile getCourseProfile([String? dateKey]) {
    final String key = dateKey ?? getDailyDateKey();
    final int seed = hashDateKey(key);
    final SeededRng rng = SeededRng(seed);
    final String title = _courseTitles[rng.nextInt(_courseTitles.length)];
    final double speed = 214.0 + rng.nextInt(22);
    final double gap = 142.0 + rng.nextInt(14);
    final double spacing = 248.0 + rng.nextInt(18);
    return DailyCourseProfile(
      dateKey: key,
      seed: seed,
      title: title,
      pipeSpeed: speed,
      pipeGap: gap,
      pipeSpacing: spacing,
    );
  }

  static List<DailyLeaderboardRow> buildLeaderboard(
      DailyChallengeStorage storage) {
    final SeededRng rng = SeededRng(hashDateKey(storage.dateKey) ^ 0x9E3779B9);

    final List<DailyLeaderboardRow> combined = [
      DailyLeaderboardRow(
        id: 'target_champion',
        rank: 0,
        name: '2130 Ace Bot',
        score: 28 + rng.nextInt(10),
        isPlayer: false,
        isPlayerBest: false,
        subtitle: 'Daily Champion Target',
      ),
      DailyLeaderboardRow(
        id: 'target_gold',
        rank: 0,
        name: 'Sky Captain Bot',
        score: 18 + rng.nextInt(7),
        isPlayer: false,
        isPlayerBest: false,
        subtitle: 'Daily Gold Target',
      ),
      DailyLeaderboardRow(
        id: 'target_silver',
        rank: 0,
        name: 'Feather Pro Bot',
        score: 10 + rng.nextInt(6),
        isPlayer: false,
        isPlayerBest: false,
        subtitle: 'Daily Silver Target',
      ),
      DailyLeaderboardRow(
        id: 'target_bronze',
        rank: 0,
        name: 'Rookie Wing Bot',
        score: 4 + rng.nextInt(4),
        isPlayer: false,
        isPlayerBest: false,
        subtitle: 'Daily Starter Target',
      ),
    ];

    final List<DailyRunEntry> topRuns = storage.runs.take(5).toList();
    for (int i = 0; i < topRuns.length; i++) {
      final DailyRunEntry run = topRuns[i];
      final bool isBest = i == 0 && run.score == storage.bestScore;
      final DateTime dt =
          DateTime.fromMillisecondsSinceEpoch(run.timestampMs);
      final String timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      combined.add(
        DailyLeaderboardRow(
          id: run.id,
          rank: 0,
          name: isBest ? 'You (Daily Best)' : 'You (Run #${i + 1})',
          score: run.score,
          isPlayer: true,
          isPlayerBest: isBest,
          subtitle: '$timeStr · ${run.skin.label}',
          skin: run.skin,
        ),
      );
    }

    combined.sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      if (a.isPlayer != b.isPlayer) return a.isPlayer ? -1 : 1;
      return 0;
    });

    return [
      for (int i = 0; i < combined.length; i++)
        DailyLeaderboardRow(
          id: combined[i].id,
          rank: i + 1,
          name: combined[i].name,
          score: combined[i].score,
          isPlayer: combined[i].isPlayer,
          isPlayerBest: combined[i].isPlayerBest,
          subtitle: combined[i].subtitle,
          skin: combined[i].skin,
        ),
    ];
  }
}
