package com.example.voice_remind

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val ALARM_CHANNEL = "com.example.voice_remind/alarm"
    private val AUDIO_CHANNEL = "com.example.voice_remind/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up method channel for alarm-specific features
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverLockScreen" -> {
                    showOverLockScreen()
                    result.success(null)
                }
                "clearFlags" -> {
                    clearFlags()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Set up method channel for audio features
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRingerMode" -> {
                    val ringerMode = getRingerMode()
                    result.success(ringerMode)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getRingerMode(): Int {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return audioManager.ringerMode
        // Returns: RINGER_MODE_NORMAL = 2, RINGER_MODE_VIBRATE = 1, RINGER_MODE_SILENT = 0
    }

   override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // Check if started for boot reschedule
    val bootReschedule = intent.getBooleanExtra("boot_reschedule", false)
    android.util.Log.d("VoiceRemind_MainActivity", "========================================")
    android.util.Log.d("VoiceRemind_MainActivity", "ðŸ“± MAINACTIVITY ONCREATE CALLED")
    android.util.Log.d("VoiceRemind_MainActivity", "   Boot reschedule flag: $bootReschedule")
    android.util.Log.d("VoiceRemind_MainActivity", "========================================")
    
    if (bootReschedule) {
        android.util.Log.d("VoiceRemind_MainActivity", "ðŸ”„ THIS IS A BOOT RESCHEDULE START")
        android.util.Log.d("VoiceRemind_MainActivity", "â³ Waiting for Flutter to initialize and reschedule...")
        
        // Keep activity alive longer to ensure Flutter initializes
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            android.util.Log.d("VoiceRemind_MainActivity", "âœ… Boot reschedule window complete - closing app")
            finish()
        }, 10000) // Increased to 10 seconds
    }
    
    // Allow showing alarm over lock screen
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    } else {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }
}

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    private fun clearFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}