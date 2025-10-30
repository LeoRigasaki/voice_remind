package com.example.voice_remind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VoiceRemind_BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action

        Log.d(TAG, "========================================")
        Log.d(TAG, "ðŸ“± BOOT RECEIVER TRIGGERED")
        Log.d(TAG, "Action: $action")
        Log.d(TAG, "========================================")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                handleBootCompleted(context)
            }
            else -> {
                Log.w(TAG, "âš ï¸ Received unknown action: $action")
            }
        }
    }

    private fun handleBootCompleted(context: Context) {
        try {
            Log.d(TAG, "ðŸ”„ Boot completed - starting reschedule service")
            
            // Start the foreground service to handle rescheduling
            val serviceIntent = Intent(context, AlarmRescheduleService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
                Log.d(TAG, "âœ… Started foreground reschedule service")
            } else {
                context.startService(serviceIntent)
                Log.d(TAG, "âœ… Started reschedule service")
            }
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "âœ… BOOT HANDLING COMPLETED")
            Log.d(TAG, "========================================")

        } catch (e: Exception) {
            Log.e(TAG, "âŒ Error handling boot: ${e.message}", e)
        }
    }
}