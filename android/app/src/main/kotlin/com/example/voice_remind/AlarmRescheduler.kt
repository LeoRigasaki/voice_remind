// [android/app/src/main/kotlin/com/example/voice_remind]/AlarmRescheduler.kt

package com.example.voice_remind

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * AlarmRescheduler - Native Kotlin utility to reschedule alarms after device reboot
 * 
 * This class reads reminder data from SharedPreferences (where Flutter stores it)
 * and reschedules all pending alarms using Android's AlarmManager directly.
 * 
 * WHY THIS IS NEEDED:
 * - AlarmManager clears ALL alarms on device reboot
 * - Android 10+ restricts launching activities from background
 * - We need to reschedule alarms WITHOUT launching the Flutter app
 */
object AlarmRescheduler {

    private const val TAG = "VoiceRemind_AlarmRescheduler"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val REMINDERS_KEY = "flutter.reminders"
    
    /**
     * Main entry point - reschedules all pending reminders after boot
     */
    fun rescheduleAllAlarms(context: Context) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔄 STARTING ALARM RESCHEDULING")
        Log.d(TAG, "========================================")
        
        try {
            // Check if we can schedule exact alarms (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                if (!alarmManager.canScheduleExactAlarms()) {
                    Log.e(TAG, "❌ SCHEDULE_EXACT_ALARM permission not granted")
                    Log.e(TAG, "   User must grant this permission in Settings")
                    return
                }
            }
            
            // Get reminders from SharedPreferences
            val reminders = getRemindersFromPrefs(context)
            
            if (reminders.isEmpty()) {
                Log.d(TAG, "📭 No reminders found to reschedule")
                Log.d(TAG, "========================================")
                return
            }
            
            Log.d(TAG, "📋 Found ${reminders.size} total reminders")
            
            // Filter and reschedule pending reminders
            var rescheduled = 0
            var skipped = 0
            
            for (reminder in reminders) {
                try {
                    if (shouldReschedule(reminder)) {
                        rescheduleReminder(context, reminder)
                        rescheduled++
                    } else {
                        skipped++
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to reschedule ${reminder.title}: ${e.message}")
                }
            }
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "✅ RESCHEDULING COMPLETE")
            Log.d(TAG, "   Rescheduled: $rescheduled")
            Log.d(TAG, "   Skipped: $skipped")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in rescheduleAllAlarms: ${e.message}", e)
        }
    }
    
    /**
     * Reads reminders from Flutter's SharedPreferences
     */
    private fun getRemindersFromPrefs(context: Context): List<ReminderData> {
        try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val remindersJson = prefs.getString(REMINDERS_KEY, null)
            
            if (remindersJson.isNullOrEmpty()) {
                Log.d(TAG, "⚠️ No reminders JSON found in SharedPreferences")
                return emptyList()
            }
            
            Log.d(TAG, "📖 Reading reminders from SharedPreferences...")
            
            val jsonArray = JSONArray(remindersJson)
            val reminders = mutableListOf<ReminderData>()
            
            for (i in 0 until jsonArray.length()) {
                try {
                    val jsonObj = jsonArray.getJSONObject(i)
                    val reminder = parseReminderJson(jsonObj)
                    reminders.add(reminder)
                } catch (e: Exception) {
                    Log.e(TAG, "⚠️ Failed to parse reminder at index $i: ${e.message}")
                }
            }
            
            Log.d(TAG, "✅ Successfully parsed ${reminders.size} reminders")
            return reminders
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading reminders from prefs: ${e.message}", e)
            return emptyList()
        }
    }
    
    /**
     * Parses a single reminder from JSON
     */
    private fun parseReminderJson(json: JSONObject): ReminderData {
        val id = json.getString("id")
        val title = json.getString("title")
        val description = json.optString("description", "")
        val scheduledTime = json.getLong("scheduledTime")
        val status = json.getString("status")
        val isNotificationEnabled = json.getBoolean("isNotificationEnabled")
        val repeatType = json.getString("repeatType")
        
        return ReminderData(
            id = id,
            title = title,
            description = description,
            scheduledTime = scheduledTime,
            status = status,
            isNotificationEnabled = isNotificationEnabled,
            repeatType = repeatType
        )
    }
    
    /**
     * Determines if a reminder should be rescheduled
     */
    private fun shouldReschedule(reminder: ReminderData): Boolean {
        // Only reschedule pending reminders with notifications enabled
        if (reminder.status != "pending" || !reminder.isNotificationEnabled) {
            Log.d(TAG, "⏭️ Skipping ${reminder.title}: status=${reminder.status}, notificationEnabled=${reminder.isNotificationEnabled}")
            return false
        }
        
        // For repeating reminders, calculate next occurrence
        val scheduledDate = Date(reminder.scheduledTime)
        val now = Date()
        
        if (reminder.repeatType != "none") {
            // Repeating reminders should always be rescheduled
            Log.d(TAG, "🔁 ${reminder.title} is repeating (${reminder.repeatType})")
            return true
        }
        
        // For one-time reminders, only reschedule if in the future
        if (scheduledDate.after(now)) {
            Log.d(TAG, "✅ ${reminder.title} scheduled for future: $scheduledDate")
            return true
        }
        
        Log.d(TAG, "⏭️ Skipping ${reminder.title}: scheduled in the past ($scheduledDate)")
        return false
    }
    
    /**
     * Reschedules a single reminder using AlarmManager
     */
    private fun rescheduleReminder(context: Context, reminder: ReminderData) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Calculate the next trigger time
            val triggerTime = calculateNextTriggerTime(reminder)
            
            if (triggerTime == null || triggerTime <= System.currentTimeMillis()) {
                Log.d(TAG, "⏭️ Skipping ${reminder.title}: no valid future trigger time")
                return
            }
            
            // Create intent for the alarm receiver
            // This needs to match whatever receiver your alarm plugin uses
            val intent = Intent(context, AlarmBroadcastReceiver::class.java).apply {
                action = "com.example.voice_remind.ALARM_ACTION"
                putExtra("reminder_id", reminder.id)
                putExtra("reminder_title", reminder.title)
                putExtra("reminder_description", reminder.description)
                putExtra("type", "alarm")
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                reminder.id.hashCode(), // Use consistent ID for cancellation
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Schedule the exact alarm
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
                else -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
            }
            
            val triggerDate = Date(triggerTime)
            val timeUntil = (triggerTime - System.currentTimeMillis()) / 1000 / 60 // minutes
            
            Log.d(TAG, "✅ Rescheduled: ${reminder.title}")
            Log.d(TAG, "   Trigger: $triggerDate")
            Log.d(TAG, "   Time until: $timeUntil minutes")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error rescheduling ${reminder.title}: ${e.message}", e)
        }
    }
    
    /**
     * Calculates the next trigger time for a reminder
     */
    private fun calculateNextTriggerTime(reminder: ReminderData): Long? {
        val now = System.currentTimeMillis()
        var triggerTime = reminder.scheduledTime
        
        // If it's a one-time reminder in the future, use scheduled time
        if (reminder.repeatType == "none") {
            return if (triggerTime > now) triggerTime else null
        }
        
        // For repeating reminders, calculate next occurrence
        val calendar = Calendar.getInstance().apply {
            timeInMillis = triggerTime
        }
        
        // Move to future if past
        while (calendar.timeInMillis <= now) {
            when (reminder.repeatType) {
                "daily" -> calendar.add(Calendar.DAY_OF_YEAR, 1)
                "weekly" -> calendar.add(Calendar.WEEK_OF_YEAR, 1)
                "monthly" -> calendar.add(Calendar.MONTH, 1)
                "yearly" -> calendar.add(Calendar.YEAR, 1)
                else -> return null // Unknown repeat type
            }
        }
        
        return calendar.timeInMillis
    }
    
    /**
     * Data class to hold reminder information
     */
    data class ReminderData(
        val id: String,
        val title: String,
        val description: String,
        val scheduledTime: Long,
        val status: String,
        val isNotificationEnabled: Boolean,
        val repeatType: String
    )
}