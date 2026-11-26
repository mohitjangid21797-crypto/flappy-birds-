package com.flyingbird.game

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private var soundPool: SoundPool? = null
    private val soundIds = ConcurrentHashMap<String, Int>()
    private val loadedIds = ConcurrentHashMap.newKeySet<Int>()
    private var bgmFile: File? = null
    private var bgmPlayer: MediaPlayer? = null
    private var isMuted = false
    private var bgmRequested = false
    private var appInForeground = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureSoundPool()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flyingbird.game/sfx"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "preload" -> {
                    val map = call.arguments as? Map<*, *>
                    if (map != null) {
                        preloadSounds(map)
                    }
                    result.success(true)
                }
                "play" -> {
                    val name = call.argument<String>("name") ?: ""
                    val volume = (call.argument<Double>("volume") ?: 1.0)
                        .toFloat()
                        .coerceIn(0f, 1f)
                    val rate = (call.argument<Double>("rate") ?: 1.0)
                        .toFloat()
                        .coerceIn(0.5f, 2.0f)
                    playSfx(name, volume, rate)
                    result.success(null)
                }
                "startBgm" -> {
                    bgmRequested = true
                    syncBgmPlayback()
                    result.success(null)
                }
                "pauseBgm" -> {
                    bgmRequested = false
                    syncBgmPlayback()
                    result.success(null)
                }
                "stopBgm" -> {
                    bgmRequested = false
                    syncBgmPlayback(resetPosition = true)
                    result.success(null)
                }
                "setMuted" -> {
                    isMuted = call.argument<Boolean>("muted") ?: false
                    syncBgmPlayback()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureSoundPool() {
        if (soundPool != null) return
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder()
            .setMaxStreams(10)
            .setAudioAttributes(attrs)
            .build()
            .apply {
                setOnLoadCompleteListener { _, sampleId, status ->
                    if (status == 0) {
                        loadedIds.add(sampleId)
                    }
                }
            }
    }

    private fun preloadSounds(map: Map<*, *>) {
        ensureSoundPool()
        val pool = soundPool ?: return
        for ((rawKey, rawVal) in map) {
            val name = rawKey as? String ?: continue
            val bytes = rawVal as? ByteArray ?: continue
            try {
                val outFile = File(cacheDir, "sfx_$name.wav")
                outFile.writeBytes(bytes)
                if (name == "bgm") {
                    bgmFile = outFile
                    if (bgmRequested && !isMuted && appInForeground) {
                        runOnUiThread { syncBgmPlayback() }
                    }
                } else {
                    val id = pool.load(outFile.absolutePath, 1)
                    if (id != 0) {
                        soundIds[name] = id
                    }
                }
            } catch (_: Throwable) {
            }
        }
    }

    private fun playSfx(name: String, volume: Float, rate: Float) {
        if (isMuted) return
        val pool = soundPool ?: return
        val id = soundIds[name] ?: return
        if (loadedIds.contains(id) || id != 0) {
            pool.play(id, volume, volume, 1, 0, rate)
        }
    }

    private fun syncBgmPlayback(resetPosition: Boolean = false) {
        val shouldPlay = bgmRequested && !isMuted && appInForeground
        if (!shouldPlay) {
            try {
                if (bgmPlayer?.isPlaying == true) {
                    bgmPlayer?.pause()
                }
                if (resetPosition) {
                    bgmPlayer?.seekTo(0)
                }
            } catch (_: Throwable) {
            }
            return
        }

        val file = bgmFile ?: return
        try {
            val existing = bgmPlayer
            if (existing != null) {
                if (!existing.isPlaying) {
                    existing.setVolume(0.32f, 0.32f)
                    existing.start()
                }
                return
            }

            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val player = MediaPlayer().apply {
                setAudioAttributes(attrs)
                setDataSource(file.absolutePath)
                isLooping = true
                setVolume(0.32f, 0.32f)
                prepare()
            }
            bgmPlayer = player
            if (bgmRequested && !isMuted && appInForeground) {
                player.start()
            }
        } catch (_: Throwable) {
        }
    }

    override fun onPause() {
        appInForeground = false
        syncBgmPlayback()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        appInForeground = true
        syncBgmPlayback()
    }

    override fun onDestroy() {
        try {
            bgmPlayer?.stop()
            bgmPlayer?.release()
        } catch (_: Throwable) {
        }
        bgmPlayer = null
        try {
            soundPool?.release()
        } catch (_: Throwable) {
        }
        soundPool = null
        soundIds.clear()
        loadedIds.clear()
        super.onDestroy()
    }
}
