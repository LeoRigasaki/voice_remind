// [android/app/src/main/kotlin/com/example/voice_remind]/BootReceiver.kt

package com.example.voice_remind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver - Handles device boot and reschedules alarms DIRECTLY
 *
 * UPDATED APPROACH (CRITICAL FIX):
 * - NO LONGER launches the Flutter app (Android 10+ restrictions)
 * - Reschedules alarms DIRECTLY using AlarmManager in native code
 * - Reads reminder data from SharedPreferences
 * - Works reliably even when app is not running
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VoiceRemind_BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action

        Log.d(TAG, "========================================")
        Log.d(TAG, "📱 BOOT RECEIVER TRIGGERED")
        Log.d(TAG, "Action: $action")
        Log.d(TAG, "========================================")

        // Check if this is a boot-related action
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                handleBootCompleted(context)
            }
            else -> {
                Log.w(TAG, "⚠️ Received unknown action: $action")
            }
        }
    }

    private fun handleBootCompleted(context: Context) {
        try {
            Log.d(TAG, "🔄 Starting alarm rescheduling...")

            // CRITICAL FIX: Reschedule alarms DIRECTLY without launching app
            // This bypasses Android 10+ background activity restrictions
            AlarmRescheduler.rescheduleAllAlarms(context)

            // Set flag for Flutter app (if/when user opens it)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.boot_reschedule_completed", true).apply()

            Log.d(TAG, "========================================")
            Log.d(TAG, "✅ BOOT HANDLING COMPLETED")
            Log.d(TAG, "========================================")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling boot: ${e.message}", e)
        }
    }
}