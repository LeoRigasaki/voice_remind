package com.example.voice_remind

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.voice_remind/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for alarm-specific features
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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