// [lib/services]/default_sound_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Service for managing default system alarm sounds
/// Uses flutter_ringtone_player to play system ringtones, alarms, and notification sounds
class DefaultSoundService {
  static bool _isPlaying = false;

  /// Play the system default alarm sound
  /// Uses the device's default alarm sound with looping and maximum volume
  static Future<void> playAlarmSound() async {
    try {
      if (_isPlaying) {
        debugPrint('⚠️ Alarm sound already playing');
        return;
      }

      debugPrint('🔊 Playing system default alarm sound');

      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true, // Loop until stopped
        volume: 1.0, // Maximum volume
        asAlarm: true, // Mark as alarm (Android only)
      );

      _isPlaying = true;
      debugPrint('✅ Alarm sound started successfully');
    } catch (e) {
      debugPrint('❌ Error playing alarm sound: $e');
      _isPlaying = false;
    }
  }

  /// Play the system default ringtone sound
  static Future<void> playRingtone() async {
    try {
      if (_isPlaying) {
        debugPrint('⚠️ Sound already playing');
        return;
      }

      debugPrint('🔊 Playing system ringtone');

      await FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.triTone,
        looping: true,
        volume: 1.0,
      );

      _isPlaying = true;
      debugPrint('✅ Ringtone started successfully');
    } catch (e) {
      debugPrint('❌ Error playing ringtone: $e');
      _isPlaying = false;
    }
  }

  /// Play the system default notification sound
  static Future<void> playNotificationSound() async {
    try {
      debugPrint('🔊 Playing notification sound');

      await FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.triTone,
        looping: false, // Don't loop notifications
        volume: 0.8,
      );

      debugPrint('✅ Notification sound played');
    } catch (e) {
      debugPrint('❌ Error playing notification sound: $e');
    }
  }

  /// Stop any currently playing sound
  static Future<void> stop() async {
    try {
      if (!_isPlaying) {
        debugPrint('ℹ️ No sound currently playing');
        return;
      }

      debugPrint('🔇 Stopping alarm sound');
      await FlutterRingtonePlayer().stop();
      _isPlaying = false;
      debugPrint('✅ Sound stopped successfully');
    } catch (e) {
      debugPrint('❌ Error stopping sound: $e');
      _isPlaying = false;
    }
  }

  /// Check if alarm sound is currently playing
  static bool get isPlaying => _isPlaying;

  /// Get the default alarm sound path for alarm plugin compatibility
  /// Returns a placeholder path since we're using system sounds
  static Future<String> getDefaultAlarmPath() async {
    // Return system alarm identifier for compatibility
    return 'system://alarm';
  }
}
