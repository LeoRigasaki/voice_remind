// [android/app/src/main/kotlin/com/example/voice_remind]/BootReceiver.kt

package com.example.voice_remind

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver - Handles device boot and reschedules all alarms
 * 
 * PLACEMENT: Create this NEW file at:
 * android/app/src/main/kotlin/com/example/voice_remind/BootReceiver.kt
 * 
 * This file should be in the SAME directory as MainActivity.kt
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
            
            // Launch app in background to trigger reschedule
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                launchIntent.putExtra("launched_from_boot", true)
                
                context.startActivity(launchIntent)
                Log.d(TAG, "✅ App launched in background for reschedule")
            } else {
                Log.e(TAG, "❌ Could not create launch intent")
            }
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "🔄 Boot handling completed")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling boot: ${e.message}", e)
        }
    }
}