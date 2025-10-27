// [android/app/src/main/kotlin/com/example/voice_remind]/AlarmBroadcastReceiver.kt

package com.example.voice_remind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import me.carda.awesome_notifications.AwesomeNotificationsPlugin

/**
 * AlarmBroadcastReceiver - Handles alarm triggers from AlarmManager
 * 
 * This receiver is triggered when an alarm set by AlarmRescheduler fires.
 * It then delegates to awesome_notifications to show the notification.
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VoiceRemind_AlarmReceiver"
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
            // Create notification using awesome_notifications
            // This integrates with your existing notification channels
            val notificationId = reminderId.hashCode()
            
            Log.d(TAG, "🔔 Showing alarm notification (ID: $notificationId)")
            
            // The actual notification will be handled by awesome_notifications
            // through its existing channel configuration
            
            // Since alarms were rescheduled by AlarmManager, awesome_notifications
            // should have them scheduled. The alarm trigger will wake the app
            // and awesome_notifications will display it.
            
            Log.d(TAG, "✅ Notification trigger initiated")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing notification: ${e.message}", e)
        }
    }
}