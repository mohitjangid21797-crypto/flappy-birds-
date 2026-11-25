import 'dart:js_interop';

@JS('flappySfx')
external void _jsPlayFlappySfx(JSString soundName);

@JS('flappyGetBestScore')
external int? _jsGetBestScore();

@JS('flappySetBestScore')
external void _jsSetBestScore(int score);

void playWebSfx(String soundName) {
  try {
    _jsPlayFlappySfx(soundName.toJS);
  } catch (_) {
    // Ignore audio context errors before user interaction.
  }
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
  } catch (_) {
    // Ignore storage quota or sandbox errors.
  }
}
