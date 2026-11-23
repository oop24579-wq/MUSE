package com.shortdrama.watch

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Rational
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

class MainActivity : FlutterFragmentActivity() {

    // Round 5: latest playback state reported from Dart — used to
    // decide whether leaving the app should enter Picture-in-Picture.
    private var pipPlaying = false
    private var pipAspect = 9.0 / 16.0

    private var mediaChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // hero_drama/media_controls — brightness / volume / PiP bridge
        // for PlayerPlatformService (Dart). Every handler is defensive:
        // a failure here must never crash playback.
        val media = MethodChannel(messenger, "hero_drama/media_controls")
        mediaChannel = media
        media.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getBrightness" -> result.success(getBrightness())
                    "setBrightness" -> {
                        val value = (call.argument<Double>("value") ?: 0.5)
                            .toFloat().coerceIn(0f, 1f)
                        val attrs = window.attributes
                        attrs.screenBrightness = value
                        window.attributes = attrs
                        result.success(null)
                    }
                    "getVolume" -> result.success(getVolume())
                    "setVolume" -> {
                        val value = (call.argument<Double>("value") ?: 0.5)
                            .coerceIn(0.0, 1.0)
                        setVolume(value)
                        result.success(null)
                    }
                    "setPlaybackState" -> {
                        pipPlaying = call.argument<Boolean>("playing") ?: false
                        pipAspect = call.argument<Double>("aspectRatio")
                            ?: (9.0 / 16.0)
                        result.success(null)
                    }
                    "enterPip" -> result.success(enterPipMode())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("media_controls", e.message, null)
            }
        }

        // herodrama/content_protection — FLAG_SECURE for screenshot /
        // screen-recording protection (round 5). iOS reports capture
        // state instead; on Android isCaptured is always false.
        MethodChannel(messenger, "herodrama/content_protection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        } else {
                            window.clearFlags(
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        }
                        result.success(true)
                    }
                    "isCaptured" -> result.success(false)
                    else -> result.notImplemented()
                }
            }
    }

    private fun getBrightness(): Double {
        val attr = window.attributes.screenBrightness
        if (attr >= 0f) return attr.toDouble()
        return try {
            val system = Settings.System.getInt(
                contentResolver, Settings.System.SCREEN_BRIGHTNESS
            )
            system / 255.0
        } catch (e: Exception) {
            0.5
        }
    }

    private fun audioManager(): AudioManager =
        getSystemService(AUDIO_SERVICE) as AudioManager

    private fun getVolume(): Double {
        val am = audioManager()
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        return am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }

    private fun setVolume(value: Double) {
        val am = audioManager()
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val index = (value * max).roundToInt().coerceIn(0, max)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, index, 0)
    }

    private fun enterPipMode(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            // Android only accepts aspect ratios between ~0.418 and ~2.39.
            val aspect = pipAspect.coerceIn(0.41841, 2.39024)
            val rational = Rational((aspect * 10000).toInt(), 10000)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rational)
                .build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Leaving the app mid-playback (Home / recents) drops the
        // video into PiP instead of just pausing it in the background.
        if (pipPlaying) enterPipMode()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        // Dart pauses on lifecycle-paused unless it knows PiP is
        // active — keep it informed.
        try {
            mediaChannel?.invokeMethod(
                "pipModeChanged",
                mapOf("inPip" to isInPictureInPictureMode)
            )
        } catch (e: Exception) {
            // Best-effort only.
        }
    }
}
