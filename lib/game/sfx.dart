import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'daily_challenge.dart';
import 'sfx_stub.dart' if (dart.library.js_interop) 'sfx_web.dart';

enum GameSfx {
  flap,
  score,
  heart,
  shield,
  hit,
  die,
  swoosh,
}

class SoundController {
  bool muted = false;

  void play(GameSfx sfx) {
    if (muted) return;
    if (kIsWeb) {
      playWebSfx(sfx.name);
      return;
    }
    switch (sfx) {
      case GameSfx.flap:
        HapticFeedback.lightImpact();
      case GameSfx.score:
      case GameSfx.heart:
        SystemSound.play(SystemSoundType.click);
      case GameSfx.shield:
      case GameSfx.hit:
        HapticFeedback.heavyImpact();
      case GameSfx.die:
        HapticFeedback.mediumImpact();
      case GameSfx.swoosh:
        HapticFeedback.selectionClick();
    }
  }

  int loadBestScore() => readWebBestScore() ?? 0;

  void saveBestScore(int score) => writeWebBestScore(score);

  DailyChallengeStorage loadDailyStorage(String dateKey) {
    return DailyChallengeStorage.fromRawJson(readWebDailyBoard(), dateKey);
  }

  void saveDailyStorage(DailyChallengeStorage storage) {
    writeWebDailyBoard(jsonEncode(storage.toJson()));
  }
}
