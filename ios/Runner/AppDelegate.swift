import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var sfxBuffers: [String: Data] = [:]
  private var activePlayers: [AVAudioPlayer] = []
  private var bgmPlayer: AVAudioPlayer?
  private var isMuted = false
  private var bgmRequested = false
  private var appInForeground = true

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureAudioSession()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    appInForeground = false
    syncBgmPlayback()
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    appInForeground = true
    configureAudioSession()
    syncBgmPlayback()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlappySfxPlugin") {
      let channel = FlutterMethodChannel(
        name: "com.flyingbird.game/sfx",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleAudioCall(call: call, result: result)
      }
    }
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      // Ignore audio session activation errors on simulators/restricted environments
    }
  }

  private func handleAudioCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preload":
      if let map = call.arguments as? [String: FlutterStandardTypedData] {
        for (name, typedData) in map {
          sfxBuffers[name] = typedData.data
        }
        if bgmRequested && !isMuted && appInForeground {
          syncBgmPlayback()
        }
      }
      result(true)

    case "play":
      guard let args = call.arguments as? [String: Any],
            let name = args["name"] as? String else {
        result(nil)
        return
      }
      let volume = Float((args["volume"] as? Double) ?? 1.0)
      let rate = Float((args["rate"] as? Double) ?? 1.0)
      playSfx(name: name, volume: volume, rate: rate)
      result(nil)

    case "startBgm":
      bgmRequested = true
      syncBgmPlayback()
      result(nil)

    case "pauseBgm":
      bgmRequested = false
      syncBgmPlayback()
      result(nil)

    case "stopBgm":
      bgmRequested = false
      syncBgmPlayback(resetPosition: true)
      result(nil)

    case "setMuted":
      let args = call.arguments as? [String: Any]
      isMuted = (args?["muted"] as? Bool) ?? false
      syncBgmPlayback()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func playSfx(name: String, volume: Float, rate: Float) {
    guard !isMuted, let data = sfxBuffers[name] else { return }
    activePlayers.removeAll { !$0.isPlaying }
    if activePlayers.count >= 10 {
      activePlayers.first?.stop()
      activePlayers.removeFirst()
    }
    do {
      let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
      player.volume = min(max(volume, 0.0), 1.0)
      if abs(rate - 1.0) > 0.01 {
        player.enableRate = true
        player.rate = min(max(rate, 0.5), 2.0)
      }
      player.prepareToPlay()
      player.play()
      activePlayers.append(player)
    } catch {
      // Ignore malformed audio data
    }
  }

  private func syncBgmPlayback(resetPosition: Bool = false) {
    let shouldPlay = bgmRequested && !isMuted && appInForeground
    if !shouldPlay {
      if bgmPlayer?.isPlaying == true {
        bgmPlayer?.pause()
      }
      if resetPosition {
        bgmPlayer?.currentTime = 0
      }
      return
    }

    if let existing = bgmPlayer {
      if !existing.isPlaying {
        existing.volume = 0.28
        existing.play()
      }
      return
    }

    guard let data = sfxBuffers["bgm"] else { return }
    do {
      let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
      player.numberOfLoops = -1
      player.volume = 0.28
      player.prepareToPlay()
      player.play()
      bgmPlayer = player
    } catch {
      // Ignore audio initialization errors
    }
  }
}
