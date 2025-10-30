package com.example.voice_remind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * AlarmBroadcastReceiver - Backup receiver for alarm triggers
 * 
 * NOTE: awesome_notifications handles most notifications through its own receivers
 * This is kept for compatibility but may not be actively used
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VoiceRemind_AlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "â° ALARM BROADCAST RECEIVED")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "========================================")

        try {
            val reminderId = intent.getStringExtra("reminder_id")
            val reminderTitle = intent.getStringExtra("reminder_title") ?: "Reminder"

            Log.d(TAG, "ðŸ“‹ Reminder: $reminderTitle")
            Log.d(TAG, "ðŸ†” ID: $reminderId")
            
            // awesome_notifications handles the actual notification display
            Log.d(TAG, "âœ… awesome_notifications will handle notification display")

        } catch (e: Exception) {
            Log.e(TAG, "âŒ Error processing alarm: ${e.message}", e)
        }
    }
}