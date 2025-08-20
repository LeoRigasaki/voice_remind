package com.example.voice_remind

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sound / Ringtone channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.sound/ringtone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDefaultAlarmPath" -> {
                        val type = (call.argument<String>("type") ?: "alarm").lowercase()
                        try {
                            val uri = getDefaultUri(type)
                            val path = copyUriToCache(uri)
                            result.success(path)
                        } catch (se: SecurityException) {
                            result.error("PERMISSION", "Missing media read permission: ${se.message}", null)
                        } catch (e: Exception) {
                            result.error("COPY_FAIL", e.message, null)
                        }
                    }

                    "play" -> {
                        val type = (call.argument<String>("type") ?: "alarm").lowercase()
                        val uri = getDefaultUri(type)

                        try { ringtone?.stop() } catch (_: Exception) {}
                        ringtone = RingtoneManager.getRingtone(this, uri)?.apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                audioAttributes = AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                    .build()
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                isLooping = true
                            }
                            play()
                        }
                        result.success(null)
                    }

                    "stop" -> {
                        try { ringtone?.stop() } catch (_: Exception) {}
                        ringtone = null
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        // Screen state channel (moved INSIDE configureFlutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.voiceremind/screen_state")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isScreenOn" -> {
                        try {
                            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                                powerManager.isInteractive
                            } else {
                                @Suppress("DEPRECATION")
                                powerManager.isScreenOn
                            }
                            result.success(isScreenOn)
                        } catch (e: Exception) {
                            result.error("SCREEN_STATE_ERROR", "Failed to get screen state", e.message)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getDefaultUri(type: String): Uri {
        val target = when (type) {
            "ringtone" -> RingtoneManager.TYPE_RINGTONE
            "notification" -> RingtoneManager.TYPE_NOTIFICATION
            else -> RingtoneManager.TYPE_ALARM
        }

        // Try actual default first, then plain default for the type, then alarm as last resort
        return RingtoneManager.getActualDefaultRingtoneUri(this, target)
            ?: RingtoneManager.getDefaultUri(target)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
    }

    private fun copyUriToCache(uri: Uri): String {
        val name = queryDisplayName(uri) ?: "default_alarm_${System.currentTimeMillis()}.sound"
        val outFile = File(cacheDir, name)

        contentResolver.openInputStream(uri).use { input ->
            FileOutputStream(outFile).use { output ->
                requireNotNull(input) { "Unable to open sound stream" }
                input.copyTo(output)
            }
        }
        return outFile.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && c.moveToFirst()) c.getString(idx) else null
        }
    }

    override fun onDestroy() {
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
        super.onDestroy()
    }
}
