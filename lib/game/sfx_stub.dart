void playWebSfx(String soundName, [double pitch = 1.0]) {
  // No-op on non-web platforms; native MethodChannel handles mobile audio.
}

void setWebMuted(bool muted) {}

void setWebPaused(bool paused) {}

void startWebBgm() {}

void stopWebBgm() {}

int? readWebBestScore() => null;

void writeWebBestScore(int score) {}
