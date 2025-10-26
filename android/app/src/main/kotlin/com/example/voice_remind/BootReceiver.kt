// [android/app/src/main/kotlin/com/example/voice_remind]/BootReceiver.kt

package com.example.voice_remind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * BootReceiver - Handles device boot and schedules alarm rescheduling
 *
 * UPDATED: Now uses WorkManager for reliable app launch on Android 10+
 *
 * WHY THE CHANGE:
 * Android 10+ restricts direct activity launches from BroadcastReceivers.
 * WorkManager provides a reliable way to launch the app after boot,
 * which then triggers the alarm rescheduling logic in Flutter.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VoiceRemind_BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val BOOT_FLAG_KEY = "flutter.needs_boot_reschedule"
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
            // Set flag to indicate boot occurred
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(BOOT_FLAG_KEY, true).apply()

            Log.d(TAG, "✅ Boot flag set in SharedPreferences")

            // CRITICAL FIX: Use WorkManager instead of startActivity
            // WorkManager is designed for reliable background tasks and
            // bypasses Android 10+ restrictions on background activity starts
            val bootWork = OneTimeWorkRequestBuilder<BootWorker>()
                .setInitialDelay(5, TimeUnit.SECONDS)  // Small delay to ensure system is ready
                .build()

            WorkManager.getInstance(context).enqueue(bootWork)

            Log.d(TAG, "✅ Boot worker scheduled via WorkManager")
            Log.d(TAG, "========================================")
            Log.d(TAG, "🔄 Boot handling completed")
            Log.d(TAG, "========================================")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling boot: ${e.message}", e)
        }
    }
}