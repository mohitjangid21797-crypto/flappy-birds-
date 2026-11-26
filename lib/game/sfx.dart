import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sfx_stub.dart' if (dart.library.js_interop) 'sfx_web.dart';

enum GameSfx {
  flap,
  score,
  milestone,
  heart,
  shield,
  hit,
  die,
  swoosh,
}

class SoundController {
  static const MethodChannel _channel = MethodChannel('com.flyingbird.game/sfx');
  static const List<String> _assetNames = <String>[
    'flap',
    'score',
    'milestone',
    'heart',
    'shield',
    'hit',
    'die',
    'swoosh',
    'bgm',
  ];

  bool _muted = false;
  bool get muted => _muted;
  set muted(bool value) {
    if (_muted == value) return;
    _muted = value;
    if (kIsWeb) {
      setWebMuted(value);
      return;
    }
    _channel.invokeMethod<void>('setMuted', <String, Object>{
      'muted': value,
    }).catchError((_) {});
  }

  double _skinPitch = 1.0;
  bool _initialized = false;
  bool _bgmActive = false;
  bool _paused = false;

  void setSkinPitch(double pitch) {
    _skinPitch = pitch.clamp(0.75, 1.35);
  }

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      final Map<String, Uint8List> payload = <String, Uint8List>{};
      for (final String name in _assetNames) {
        try {
          final ByteData data = await rootBundle.load('assets/audio/$name.wav');
          payload[name] = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } catch (_) {}
      }
      if (payload.isNotEmpty) {
        await _channel.invokeMethod<void>('preload', payload);
        if (_bgmActive && !_muted && !_paused) {
          await _channel.invokeMethod<void>('startBgm');
        }
      }
    } catch (_) {
      // Ignore in widget tests or unsupported desktop hosts.
    }
  }

  void startBgm() {
    _bgmActive = true;
    _paused = false;
    if (kIsWeb) {
      setWebPaused(false);
      startWebBgm();
      return;
    }
    _channel.invokeMethod<void>('startBgm').catchError((_) {});
  }

  void stopBgm() {
    _bgmActive = false;
    _paused = false;
    if (kIsWeb) {
      stopWebBgm();
      return;
    }
    _channel.invokeMethod<void>('stopBgm').catchError((_) {});
  }

  void setPaused(bool paused) {
    if (_paused == paused) return;
    _paused = paused;
    if (kIsWeb) {
      setWebPaused(paused);
      return;
    }
    if (paused) {
      _channel.invokeMethod<void>('pauseBgm').catchError((_) {});
    } else if (_bgmActive && !_muted) {
      _channel.invokeMethod<void>('startBgm').catchError((_) {});
    }
  }

  void dispose() {
    _bgmActive = false;
    if (kIsWeb) {
      stopWebBgm();
      return;
    }
    _channel.invokeMethod<void>('stopBgm').catchError((_) {});
  }

  void play(GameSfx sfx) {
    if (_muted) return;

    if (kIsWeb) {
      playWebSfx(sfx.name, _skinPitch);
      return;
    }

    final double volume = _volumeFor(sfx);
    final double rate = _rateFor(sfx);
    _channel.invokeMethod<void>('play', <String, Object>{
      'name': sfx.name,
      'volume': volume,
      'rate': rate,
    }).catchError((_) {});

    switch (sfx) {
      case GameSfx.flap:
        HapticFeedback.lightImpact();
      case GameSfx.shield:
      case GameSfx.hit:
        HapticFeedback.heavyImpact();
      case GameSfx.die:
        HapticFeedback.mediumImpact();
      case GameSfx.swoosh:
        HapticFeedback.selectionClick();
      case GameSfx.score:
      case GameSfx.milestone:
      case GameSfx.heart:
        break;
    }
  }

  double _volumeFor(GameSfx sfx) {
    switch (sfx) {
      case GameSfx.flap:
        return 0.78;
      case GameSfx.score:
        return 0.88;
      case GameSfx.milestone:
        return 0.94;
      case GameSfx.heart:
        return 0.90;
      case GameSfx.shield:
        return 0.95;
      case GameSfx.hit:
        return 1.0;
      case GameSfx.die:
        return 0.90;
      case GameSfx.swoosh:
        return 0.70;
    }
  }

  double _rateFor(GameSfx sfx) {
    if (sfx == GameSfx.flap || sfx == GameSfx.swoosh) {
      return _skinPitch;
    }
    return 1.0;
  }

  int loadBestScore() => readWebBestScore() ?? 0;

  void saveBestScore(int score) => writeWebBestScore(score);
}
