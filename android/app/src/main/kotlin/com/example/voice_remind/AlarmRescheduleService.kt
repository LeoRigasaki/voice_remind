package com.example.voice_remind

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class AlarmRescheduleService : Service() {

    companion object {
        private const val TAG = "VoiceRemind_RescheduleService"
        private const val NOTIFICATION_ID = 999
        private const val CHANNEL_ID = "alarm_reschedule_channel"
        private const val CHANNEL_NAME = "Alarm Reschedule"
        private const val RESCHEDULE_CHANNEL = "com.example.voice_remind/reschedule"
    }

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "========================================")
        Log.d(TAG, "📱 SERVICE CREATED")
        Log.d(TAG, "========================================")
        
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "========================================")
        Log.d(TAG, "⚡ SERVICE STARTED")
        Log.d(TAG, "========================================")

        // Initialize Flutter engine and reschedule
        initializeFlutterAndReschedule()

        return START_NOT_STICKY
    }

    private fun initializeFlutterAndReschedule() {
        try {
            Log.d(TAG, "🔄 Initializing Flutter engine...")

            // Create Flutter engine
            flutterEngine = FlutterEngine(applicationContext)
            
            // Start Dart execution
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            Log.d(TAG, "✅ Flutter engine initialized")

            // Wait a bit for Flutter to initialize, then trigger reschedule
            Handler(Looper.getMainLooper()).postDelayed({
                triggerReschedule()
            }, 3000) // 3 second delay

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing Flutter: ${e.message}", e)
            stopSelfAndCleanup()
        }
    }

    private fun triggerReschedule() {
    try {
        Log.d(TAG, "📞 Setting up method channel...")

        // Null safety check
        if (flutterEngine == null) {
            Log.e(TAG, "❌ Flutter engine is null")
            stopSelfAndCleanup()
            return
        }

        val dartExecutor = flutterEngine?.dartExecutor
        if (dartExecutor == null) {
            Log.e(TAG, "❌ Dart executor is null")
            stopSelfAndCleanup()
            return
        }

        // Create method channel
        methodChannel = MethodChannel(
            dartExecutor.binaryMessenger,
            RESCHEDULE_CHANNEL
        )

        Log.d(TAG, "📤 Invoking reschedule method...")
        
        // Call Flutter method to reschedule
        methodChannel?.invokeMethod("rescheduleFromBoot", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                Log.d(TAG, "✅ Reschedule completed successfully")
                Log.d(TAG, "Result: $result")
                
                // Wait a bit then stop service
                Handler(Looper.getMainLooper()).postDelayed({
                    stopSelfAndCleanup()
                }, 2000)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.e(TAG, "❌ Reschedule error: $errorCode - $errorMessage")
                stopSelfAndCleanup()
            }

            override fun notImplemented() {
                Log.e(TAG, "❌ Reschedule method not implemented in Flutter")
                stopSelfAndCleanup()
            }
        })

    } catch (e: Exception) {
        Log.e(TAG, "❌ Error triggering reschedule: ${e.message}", e)
        stopSelfAndCleanup()
    }
}

    private fun stopSelfAndCleanup() {
        Log.d(TAG, "🧹 Cleaning up and stopping service...")
        
        try {
            flutterEngine?.destroy()
            flutterEngine = null
            methodChannel = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup: ${e.message}")
        }
        
        stopForeground(true)
        stopSelf()
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "✅ SERVICE STOPPED")
        Log.d(TAG, "========================================")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Rescheduling alarms after boot"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "✅ Notification channel created")
        }
    }

    private fun createNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("VoiceRemind")
        .setContentText("Rescheduling reminders...")
        .setSmallIcon(android.R.drawable.ic_popup_reminder)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "📱 SERVICE DESTROYED")
    }
}