// [android/app/src/main/kotlin/com/example/voice_remind]/AlarmBroadcastReceiver.kt

package com.example.voice_remind

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

import com.example.voice_remind.R

/**
 * AlarmBroadcastReceiver - Handles alarm triggers from AlarmManager
 *
 * This receiver is triggered when an alarm set by AlarmRescheduler fires.
 * It then delegates to awesome_notifications to show the notification.
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VoiceRemind_AlarmReceiver"
        private const val CHANNEL_ID = "alarm_channel_v3"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "⏰ ALARM TRIGGERED")
        Log.d(TAG, "========================================")

        try {
            val reminderId = intent.getStringExtra("reminder_id")
            val reminderTitle = intent.getStringExtra("reminder_title") ?: "Reminder"
            val reminderDescription = intent.getStringExtra("reminder_description") ?: ""

            Log.d(TAG, "📋 Reminder: $reminderTitle")
            Log.d(TAG, "🆔 ID: $reminderId")

            if (reminderId == null) {
                Log.e(TAG, "❌ No reminder ID in intent")
                return
            }

            // Show notification using awesome_notifications
            showAlarmNotification(context, reminderId, reminderTitle, reminderDescription)

            Log.d(TAG, "========================================")
            Log.d(TAG, "✅ ALARM PROCESSED SUCCESSFULLY")
            Log.d(TAG, "========================================")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing alarm: ${e.message}", e)
        }
    }

    private fun showAlarmNotification(
        context: Context,
        reminderId: String,
        title: String,
        description: String
    ) {
        try {
            val appContext = context.applicationContext
            val notificationId = reminderId.hashCode()

            Log.d(TAG, "🔔 Showing alarm notification (ID: $notificationId)")

            val alarmSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: Settings.System.DEFAULT_ALARM_ALERT_URI

            ensureNotificationChannel(appContext, alarmSoundUri)

            if (!hasNotificationPermission(appContext)) {
                Log.w(TAG, "⚠️ Notification permission not granted - cannot show alarm")
                return
            }

            val launchIntent = Intent(appContext, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("reminder_id", reminderId)
            }

            val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

            val contentIntent = PendingIntent.getActivity(
                appContext,
                notificationId,
                launchIntent,
                pendingFlags
            )

            val fullScreenIntent = PendingIntent.getActivity(
                appContext,
                notificationId + 1,
                launchIntent,
                pendingFlags
            )

            val notificationBuilder = NotificationCompat.Builder(appContext, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(description.ifBlank { appContext.getString(R.string.app_name) })
                .setStyle(NotificationCompat.BigTextStyle().bigText(description.ifBlank { title }))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(false)
                .setOngoing(true)
                .setFullScreenIntent(fullScreenIntent, true)
                .setContentIntent(contentIntent)
                .setSound(alarmSoundUri)

            NotificationManagerCompat.from(appContext).notify(notificationId, notificationBuilder.build())

            Log.d(TAG, "✅ Notification trigger initiated")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing notification: ${e.message}", e)
        }
    }

    private fun ensureNotificationChannel(context: Context, soundUri: android.net.Uri) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val existingChannel = notificationManager.getNotificationChannel(CHANNEL_ID)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        if (existingChannel == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Full-screen alarm notifications with loud sound"
                enableVibration(true)
                setBypassDnd(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setSound(soundUri, audioAttributes)
            }

            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "📢 Created alarm notification channel")
        } else {
            // Ensure the channel keeps the correct sound configuration
            existingChannel.setSound(soundUri, audioAttributes)
            notificationManager.createNotificationChannel(existingChannel)
        }
    }

    private fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED

            if (!granted) {
                Log.w(TAG, "⚠️ POST_NOTIFICATIONS permission missing")
                return false
            }
        }

        val managerCompat = NotificationManagerCompat.from(context)
        val enabled = managerCompat.areNotificationsEnabled()
        if (!enabled) {
            Log.w(TAG, "⚠️ Notifications are disabled for the app")
        }
        return enabled
    }
}
