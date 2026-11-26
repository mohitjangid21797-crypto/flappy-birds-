import 'dart:js_interop';

@JS('flappySfx')
external void _jsPlayFlappySfx(JSString soundName);

@JS('flappyGetBestScore')
external int? _jsGetBestScore();

@JS('flappySetBestScore')
external void _jsSetBestScore(int score);

@JS('flappyGetDailyBoard')
external String? _jsGetDailyBoard();

@JS('flappySetDailyBoard')
external void _jsSetDailyBoard(JSString json);

void playWebSfx(String soundName) {
  try {
    _jsPlayFlappySfx(soundName.toJS);
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

String? readWebDailyBoard() {
  try {
    return _jsGetDailyBoard();
  } catch (_) {
    return null;
  }
}

void writeWebDailyBoard(String json) {
  try {
    _jsSetDailyBoard(json.toJS);
  } catch (_) {}
}
