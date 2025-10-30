package com.example.voice_remind

import android.app.Notification
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

class AlarmRescheduleService : Service() {

    companion object {
        private const val TAG = "VoiceRemind_RescheduleService"
        private const val NOTIFICATION_ID = 999
        private const val CHANNEL_ID = "boot_reschedule_channel"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "========================================")
        Log.d(TAG, "ðŸš€ RESCHEDULE SERVICE STARTED")
        Log.d(TAG, "========================================")

        // Start foreground immediately
        startForeground(NOTIFICATION_ID, createNotification())

        // Set the boot reschedule flag
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.boot_reschedule_completed", true).apply()
            Log.d(TAG, "âœ… Set boot reschedule flag")
        } catch (e: Exception) {
            Log.e(TAG, "âŒ Failed to set boot flag: ${e.message}")
        }

        // Initialize Flutter engine and let it handle rescheduling
        try {
            Log.d(TAG, "ðŸ”„ Initializing Flutter engine for rescheduling...")
            
            // Start MainActivity which will handle the actual rescheduling
            val mainIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("boot_reschedule", true)
            }
            startActivity(mainIntent)
            Log.d(TAG, "âœ… Started MainActivity")
            
        } catch (e: Exception) {
            Log.e(TAG, "âŒ Failed to initialize: ${e.message}", e)
        }

        // Stop service after 10 seconds
        Handler(Looper.getMainLooper()).postDelayed({
            Log.d(TAG, "âœ… Reschedule service stopping")
            stopForeground(true)
            stopSelf()
        }, 10000)

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        createNotificationChannel()

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("VoiceRemind")
            .setContentText("Rescheduling reminders...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Boot Reschedule",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification shown while rescheduling reminders after boot"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}