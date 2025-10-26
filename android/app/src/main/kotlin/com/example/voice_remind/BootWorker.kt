// [android/app/src/main/kotlin/com/example/voice_remind]/BootWorker.kt

package com.example.voice_remind

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * BootWorker - Launches the Flutter app after device boot to reschedule alarms
 *
 * This Worker is scheduled by BootReceiver and runs with WorkManager,
 * which provides reliable background task execution even on Android 10+
 * where direct activity launches from BroadcastReceivers are restricted.
 */
class BootWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        private const val TAG = "VoiceRemind_BootWorker"
    }

    override fun doWork(): Result {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚀 BOOT WORKER EXECUTING")
        Log.d(TAG, "========================================")

        return try {
            // Set flag to indicate boot occurred
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            prefs.edit().putBoolean("flutter.needs_boot_reschedule", true).apply()
            Log.d(TAG, "✅ Boot flag set in SharedPreferences")

            // Launch the Flutter app
            val launchIntent = applicationContext.packageManager
                .getLaunchIntentForPackage(applicationContext.packageName)

            if (launchIntent != null) {
                // Add flags for launching from background
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                launchIntent.putExtra("launched_from_boot", true)

                applicationContext.startActivity(launchIntent)
                Log.d(TAG, "✅ App launched successfully")

                Log.d(TAG, "========================================")
                Log.d(TAG, "🎉 BOOT WORKER COMPLETED SUCCESSFULLY")
                Log.d(TAG, "========================================")

                Result.success()
            } else {
                Log.e(TAG, "❌ Could not create launch intent")
                Result.failure()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in boot worker: ${e.message}", e)
            Result.failure()
        }
    }
}
