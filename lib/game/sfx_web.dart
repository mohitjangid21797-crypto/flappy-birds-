import 'dart:js_interop';

@JS('flappySfx')
external void _jsPlayFlappySfx(JSString soundName, JSNumber pitch);

@JS('flappySetMuted')
external void _jsSetMuted(JSBoolean muted);

@JS('flappySetPaused')
external void _jsSetPaused(JSBoolean paused);

@JS('flappyStartBgm')
external void _jsStartBgm();

@JS('flappyStopBgm')
external void _jsStopBgm();

@JS('flappyGetBestScore')
external int? _jsGetBestScore();

@JS('flappySetBestScore')
external void _jsSetBestScore(int score);

void playWebSfx(String soundName, [double pitch = 1.0]) {
  try {
    _jsPlayFlappySfx(soundName.toJS, pitch.toJS);
  } catch (_) {}
}

void setWebMuted(bool muted) {
  try {
    _jsSetMuted(muted.toJS);
  } catch (_) {}
}

void setWebPaused(bool paused) {
  try {
    _jsSetPaused(paused.toJS);
  } catch (_) {}
}

void startWebBgm() {
  try {
    _jsStartBgm();
  } catch (_) {}
}

void stopWebBgm() {
  try {
    _jsStopBgm();
  } catch (_) {}
}

int? readWebBestScore() {
  try {
    return _jsGetBestScore();
  } catch (_) {
    return null;
  }
}

void writeWebBestScore(int score) {
  try {
    _jsSetBestScore(score);
  } catch (_) {}
}
