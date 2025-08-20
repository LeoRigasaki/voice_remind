// lib/services/default_sound_service.dart
import 'package:flutter/services.dart';

class DefaultSoundService {
  static const _ch = MethodChannel('app.sound/ringtone');

  /// Returns a local *file path* copied from the user's default sound.
  /// When `usePhoneRingtone` is false, we prefer the default ALARM tone.
  static Future<String> getDefaultAlarmPath(
      {bool usePhoneRingtone = false}) async {
    final String? path = await _ch.invokeMethod<String>('getDefaultAlarmPath', {
      'type': usePhoneRingtone ? 'ringtone' : 'alarm',
    });
    if (path == null || path.isEmpty) {
      throw Exception(
          'Could not resolve default ${usePhoneRingtone ? 'ringtone' : 'alarm'} path.');
    }
    return path;
  }

  static Future<void> start({bool usePhoneRingtone = false}) async {
    await _ch.invokeMethod('play', {
      'type': usePhoneRingtone ? 'ringtone' : 'alarm',
    });
  }

  static Future<void> stop() async {
    await _ch.invokeMethod('stop');
  }
}
