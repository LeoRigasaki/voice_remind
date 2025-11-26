// [lib/services]/storage_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';

class StorageService {
  static SharedPreferences? _prefs;
  static const String _remindersKey = 'reminders';

  // Background update detection
  static const String _lastUpdateKey = 'last_background_update';
  static const String _backgroundUpdateMarkerKey = 'background_update_marker';
  static DateTime? _lastKnownUpdate;
  static Timer? _backgroundUpdateChecker;

  // AI Configuration Keys
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _groqApiKeyKey = 'groq_api_key';
  static const String _selectedAIProviderKey = 'selected_ai_provider';

  // Backup keys for redundancy
  static const String _geminiApiKeyBackupKey = 'gemini_api_key_backup';
  static const String _groqApiKeyBackupKey = 'groq_api_key_backup';
  static const String _selectedAIProviderBackupKey =
      'selected_ai_provider_backup';

  // Default Tab Preference Keys
  static const String _defaultReminderTabKey = 'default_reminder_tab';
  static const String _snoozeUseCustomKey = 'snooze_use_custom';
  static const String _snoozeCustomMinutesKey = 'snooze_custom_minutes';
  // Global Alarm Preference Keys
  static const String _useAlarmInsteadOfNotificationKey =
      'use_alarm_instead_of_notification';
  // Version tracking
  static const String _storageVersionKey = 'storage_version';
  static const String _apiConfigVersionKey = 'api_config_version';
  static const int _currentStorageVersion = 2;
  static const int _currentApiConfigVersion = 1;

  // Stream controller for real-time updates
  static final StreamController<List<Reminder>> _remindersController =
      StreamController<List<Reminder>>.broadcast();

  // Stream getter for listening to reminder changes
  static Stream<List<Reminder>> get remindersStream =>
      _remindersController.stream;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    await _performEnhancedMigration();
    await _verifyAndRecoverAPIKeys();

    final initialReminders = await getReminders();
    _remindersController.add(initialReminders);

    // Initialize background update tracking
    _lastKnownUpdate = DateTime.fromMillisecondsSinceEpoch(
        _prefs?.getInt(_lastUpdateKey) ?? 0);

    // Start periodic background update checking
    _startBackgroundUpdateChecker();

    debugPrint('✅ StorageService initialized with enhanced API persistence');
  }

  /// Start a timer to periodically check for background updates
  static void _startBackgroundUpdateChecker() {
    _backgroundUpdateChecker?.cancel();
    _backgroundUpdateChecker = Timer.periodic(
      const Duration(seconds: 5), // More frequent checking
      (timer) async {
        try {
          final hasUpdates = await checkForBackgroundUpdates();
          if (hasUpdates) {
            debugPrint('🔄 Background update detected via enhanced checker');
            // Additional immediate refresh
            await forceImmediateRefresh();
          }
        } catch (e) {
          debugPrint('⚠️ Error in enhanced background checker: $e');
        }
      },
    );
  }

  static Future<void> _performEnhancedMigration() async {
    try {
      final currentStorageVersion = _prefs?.getInt(_storageVersionKey) ?? 0;
      final currentApiVersion = _prefs?.getInt(_apiConfigVersionKey) ?? 0;

      if (currentStorageVersion < _currentStorageVersion) {
        await _performMigration();
        await _prefs?.setInt(_storageVersionKey, _currentStorageVersion);
      }

      if (currentApiVersion < _currentApiConfigVersion) {
        await _migrateAndBackupAPIConfig();
        await _prefs?.setInt(_apiConfigVersionKey, _currentApiConfigVersion);
      }
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
    }
  }

  static Future<void> _migrateAndBackupAPIConfig() async {
    try {
      final geminiKey = _prefs?.getString(_geminiApiKeyKey);
      final groqKey = _prefs?.getString(_groqApiKeyKey);
      final selectedProvider = _prefs?.getString(_selectedAIProviderKey);

      if (geminiKey != null && geminiKey.isNotEmpty) {
        await _prefs?.setString(_geminiApiKeyBackupKey, geminiKey);
      }

      if (groqKey != null && groqKey.isNotEmpty) {
        await _prefs?.setString(_groqApiKeyBackupKey, groqKey);
      }

      if (selectedProvider != null && selectedProvider.isNotEmpty) {
        await _prefs?.setString(_selectedAIProviderBackupKey, selectedProvider);
      }
    } catch (e) {
      debugPrint('⚠️ API config migration failed: $e');
    }
  }

  static Future<void> _verifyAndRecoverAPIKeys() async {
    try {
      bool recoveredAny = false;

      // Check and recover Gemini key
      final geminiKey = _prefs?.getString(_geminiApiKeyKey);
      if (geminiKey == null || geminiKey.isEmpty) {
        final backupKey = _prefs?.getString(_geminiApiKeyBackupKey);
        if (backupKey != null && backupKey.isNotEmpty) {
          await _prefs?.setString(_geminiApiKeyKey, backupKey);
          recoveredAny = true;
          debugPrint('🔄 Recovered Gemini API key from backup');
        }
      }

      // Check and recover Groq key
      final groqKey = _prefs?.getString(_groqApiKeyKey);
      if (groqKey == null || groqKey.isEmpty) {
        final backupKey = _prefs?.getString(_groqApiKeyBackupKey);
        if (backupKey != null && backupKey.isNotEmpty) {
          await _prefs?.setString(_groqApiKeyKey, backupKey);
          recoveredAny = true;
          debugPrint('🔄 Recovered Groq API key from backup');
        }
      }

      // Check and recover selected provider
      final selectedProvider = _prefs?.getString(_selectedAIProviderKey);
      if (selectedProvider == null || selectedProvider.isEmpty) {
        final backupProvider = _prefs?.getString(_selectedAIProviderBackupKey);
        if (backupProvider != null && backupProvider.isNotEmpty) {
          await _prefs?.setString(_selectedAIProviderKey, backupProvider);
          recoveredAny = true;
          debugPrint('🔄 Recovered selected provider from backup');
        }
      }

      if (recoveredAny) {
        debugPrint('✅ API keys recovered successfully');
      }
    } catch (e) {
      debugPrint('❌ API key verification failed: $e');
    }
  }

  /// Migrate existing single-time reminders to support multi-time format
  static Future<void> _performMigration() async {
    final String? remindersJson = _prefs?.getString(_remindersKey);
    if (remindersJson == null || remindersJson.isEmpty) {
      return;
    }

    try {
      final List<dynamic> remindersList = json.decode(remindersJson);
      bool needsMigration = false;

      final List<Map<String, dynamic>> migratedReminders =
          remindersList.map((reminderMap) {
        final Map<String, dynamic> reminderData =
            Map<String, dynamic>.from(reminderMap);

        if (!reminderData.containsKey('timeSlots') ||
            !reminderData.containsKey('isMultiTime')) {
          needsMigration = true;
          reminderData['timeSlots'] = <Map<String, dynamic>>[];
          reminderData['isMultiTime'] = false;
        }

        return reminderData;
      }).toList();

      if (needsMigration) {
        final String migratedJson = json.encode(migratedReminders);
        await _prefs?.setString(_remindersKey, migratedJson);
      }
    } catch (e) {
      debugPrint('❌ Reminder migration failed: $e');
    }
  }

  static void dispose() {
    _backgroundUpdateChecker?.cancel();
    _remindersController.close();
  }

  static Future<List<Reminder>> getReminders() async {
    final String? remindersJson = _prefs?.getString(_remindersKey);
    if (remindersJson == null || remindersJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> remindersList = json.decode(remindersJson);
      return remindersList
          .map((reminderMap) => Reminder.fromMap(reminderMap))
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    } catch (e) {
      debugPrint('❌ Error loading reminders: $e');
      return [];
    }
  }

  static Future<void> saveReminders(List<Reminder> reminders) async {
    try {
      final List<Map<String, dynamic>> remindersMapList =
          reminders.map((reminder) => reminder.toMap()).toList();
      final String remindersJson = json.encode(remindersMapList);
      await _prefs?.setString(_remindersKey, remindersJson);

      // Mark the time of this update for background change detection
      await _markBackgroundUpdate();

      _remindersController.add(reminders);
    } catch (e) {
      debugPrint('❌ Error saving reminders: $e');
      rethrow;
    }
  }

  /// Mark that a background update occurred with an enhanced marker system
  static Future<void> _markBackgroundUpdate() async {
    final now = DateTime.now();
    final updateId =
        '${now.millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

    await _prefs?.setInt(_lastUpdateKey, now.millisecondsSinceEpoch);
    await _prefs?.setString(_backgroundUpdateMarkerKey, updateId);

    debugPrint('📱 Marked background update at: $now (ID: $updateId)');
  }

  /// Force mark a background update from notification actions
  static Future<void> markNotificationUpdate() async {
    try {
      final now = DateTime.now();
      final updateId =
          'notification_${now.millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

      // Use fresh instance for background isolate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateKey, now.millisecondsSinceEpoch);
      await prefs.setString(_backgroundUpdateMarkerKey, updateId);

      debugPrint('🔔 Marked notification update: $updateId');

      // CRITICAL: Multiple reload attempts for cross-isolate sync
      await prefs.reload();
      await Future.delayed(const Duration(milliseconds: 50));
      await prefs.reload();

      // Force stream update immediately
      try {
        final freshReminders = await getReminders();
        _remindersController.add(freshReminders);
        debugPrint(
            '🔔 Forced immediate stream update: ${freshReminders.length} reminders');
      } catch (e) {
        debugPrint('⚠️ Error in immediate stream update: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Error marking notification update: $e');
    }
  }

  /// Check if background updates occurred and refresh if needed
  static Future<bool> checkForBackgroundUpdates() async {
    try {
      // CRITICAL: Force reload before checking
      await _prefs?.reload();

      final lastUpdateTimestamp = _prefs?.getInt(_lastUpdateKey) ?? 0;
      final lastUpdate =
          DateTime.fromMillisecondsSinceEpoch(lastUpdateTimestamp);
      final currentMarker = _prefs?.getString(_backgroundUpdateMarkerKey);

      if (_lastKnownUpdate == null) {
        _lastKnownUpdate = lastUpdate;
        return false;
      }

      // Enhanced detection with marker validation
      final hasTimeUpdate = lastUpdate.isAfter(_lastKnownUpdate!);
      final hasNewMarker = currentMarker != null;

      if (hasTimeUpdate || hasNewMarker) {
        debugPrint('🔄 Background update detected!');
        debugPrint('🔄 Time: $_lastKnownUpdate → $lastUpdate');
        debugPrint('🔄 Marker: $currentMarker');

        _lastKnownUpdate = lastUpdate;

        // IMMEDIATE refresh and notify
        await refreshData();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking background updates: $e');
      return false;
    }
  }

  /// Force refresh data from storage and update stream
  static Future<void> forceRefreshFromBackgroundUpdate() async {
    try {
      debugPrint('🔄 Force refreshing data due to suspected background update');

      // Reload data directly from storage
      final freshReminders = await getReminders();

      // Force update the stream even if data appears the same
      _remindersController.add(freshReminders);

      // Update our last known timestamp
      _lastKnownUpdate = DateTime.now();

      debugPrint(
          '🔄 Force refresh completed - ${freshReminders.length} reminders loaded');
    } catch (e) {
      debugPrint('❌ Error in force refresh: $e');
    }
  }

  static Future<void> addReminder(Reminder reminder) async {
    final List<Reminder> reminders = await getReminders();
    reminders.add(reminder);
    await saveReminders(reminders);
  }

  static Future<void> updateReminder(Reminder updatedReminder) async {
    debugPrint('💾 Updating reminder: ${updatedReminder.id}');
    debugPrint('💾 New status: ${updatedReminder.status}');

    final List<Reminder> reminders = await getReminders();
    final int index = reminders.indexWhere((r) => r.id == updatedReminder.id);

    if (index != -1) {
      reminders[index] = updatedReminder;
      await saveReminders(reminders);

      // FORCE immediate update notification
      await _markBackgroundUpdate();

      debugPrint('✅ Reminder updated in storage');
      debugPrint('✅ Updated reminder: ${updatedReminder.id}');
    } else {
      debugPrint('⚠️ Reminder not found for update: ${updatedReminder.id}');
    }
  }

  static Future<void> deleteReminder(String reminderId) async {
    final List<Reminder> reminders = await getReminders();
    reminders.removeWhere((reminder) => reminder.id == reminderId);
    await saveReminders(reminders);
  }

  static Future<Reminder?> getReminderById(String reminderId) async {
    final List<Reminder> reminders = await getReminders();
    try {
      return reminders.firstWhere((reminder) => reminder.id == reminderId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearAllReminders() async {
    await _prefs?.remove(_remindersKey);
    _remindersController.add([]);
  }

  // =============================================================================
  // NEW: Default Tab Preference Methods
  // =============================================================================

  /// Set the default reminder creation tab (0=Manual, 1=AI Text, 2=Voice)
  static Future<void> setDefaultReminderTab(int tabIndex) async {
    try {
      await _prefs?.setInt(_defaultReminderTabKey, tabIndex);
      debugPrint('💾 Saved default reminder tab: $tabIndex');
    } catch (e) {
      debugPrint('❌ Error saving default reminder tab: $e');
      rethrow;
    }
  }

  /// Get the default reminder creation tab (0=Manual, 1=AI Text, 2=Voice)
  /// Returns 0 (Manual) by default
  static Future<int> getDefaultReminderTab() async {
    try {
      return _prefs?.getInt(_defaultReminderTabKey) ??
          0; // Default to Manual (0)
    } catch (e) {
      debugPrint('❌ Error getting default reminder tab: $e');
      return 0; // Fallback to Manual
    }
  }

  /// Set default reminder tab by mode string
  static Future<void> setDefaultReminderTabByMode(String mode) async {
    int index = 0; // Manual
    switch (mode.toLowerCase()) {
      case 'manual':
        index = 0;
        break;
      case 'ai':
      case 'aitext':
      case 'ai text':
        index = 1;
        break;
      case 'voice':
        index = 2;
        break;
    }
    await setDefaultReminderTab(index);
  }

  /// Get default reminder tab as mode string
  static Future<String> getDefaultReminderTabMode() async {
    final index = await getDefaultReminderTab();
    switch (index) {
      case 0:
        return 'Manual';
      case 1:
        return 'AI Text';
      case 2:
        return 'Voice';
      default:
        return 'Manual';
    }
  }

  // =============================================================================
  // NEW: Notification Action Helper Methods
  // =============================================================================

  /// Snooze a single-time reminder by the specified duration
  static Future<void> snoozeReminder(
      String reminderId, Duration snoozeDuration) async {
    final reminder = await getReminderById(reminderId);
    if (reminder == null) return;

    final snoozeTime = DateTime.now().add(snoozeDuration);
    final snoozedReminder = reminder.copyWith(scheduledTime: snoozeTime);

    await updateReminder(snoozedReminder);
    debugPrint(
        'Snoozed reminder $reminderId for ${snoozeDuration.inMinutes} minutes');
  }

  /// Snooze a specific time slot by the specified duration
  static Future<void> snoozeTimeSlot(
      String reminderId, String timeSlotId, Duration snoozeDuration) async {
    final reminder = await getReminderById(reminderId);
    if (reminder == null || !reminder.hasMultipleTimes) return;

    final timeSlot = reminder.timeSlots.firstWhere(
      (slot) => slot.id == timeSlotId,
      orElse: () => throw Exception('Time slot not found'),
    );

    final snoozeTime = DateTime.now().add(snoozeDuration);
    final snoozedTimeSlot = timeSlot.copyWith(
      time: TimeOfDay(hour: snoozeTime.hour, minute: snoozeTime.minute),
    );

    await updateTimeSlot(reminderId, timeSlotId, snoozedTimeSlot);
    debugPrint(
        'Snoozed time slot $timeSlotId for ${snoozeDuration.inMinutes} minutes');
  }

  /// Complete a reminder entirely (for single-time reminders)
  static Future<void> completeReminder(String reminderId) async {
    await updateReminderStatus(reminderId, ReminderStatus.completed);
    debugPrint('✅ Completed reminder $reminderId');
  }

  /// Complete a specific time slot (for multi-time reminders)
  static Future<void> completeTimeSlot(
      String reminderId, String timeSlotId) async {
    await updateTimeSlotStatus(
        reminderId, timeSlotId, ReminderStatus.completed);
    debugPrint('✅ Completed time slot $timeSlotId for reminder $reminderId');
  }

  /// Get reminder action summary (for debugging/logging)
  static Future<Map<String, dynamic>> getReminderActionSummary(
      String reminderId) async {
    final reminder = await getReminderById(reminderId);
    if (reminder == null) return {};

    if (reminder.hasMultipleTimes) {
      final completedSlots =
          reminder.timeSlots.where((slot) => slot.isCompleted).length;
      final totalSlots = reminder.timeSlots.length;
      final pendingSlots = reminder.timeSlots
          .where((slot) => slot.status == ReminderStatus.pending)
          .length;

      return {
        'type': 'multi-time',
        'completedSlots': completedSlots,
        'totalSlots': totalSlots,
        'pendingSlots': pendingSlots,
        'progress': totalSlots > 0 ? completedSlots / totalSlots : 0.0,
        'overallStatus': reminder.overallStatus.toString(),
      };
    } else {
      return {
        'type': 'single-time',
        'status': reminder.status.toString(),
        'isCompleted': reminder.isCompleted,
        'isOverdue': reminder.isOverdue,
        'scheduledTime': reminder.scheduledTime.toIso8601String(),
      };
    }
  }

  // =============================================================================
  // Multi-Time Reminder Methods
  // =============================================================================

  static Future<List<Reminder>> getRemindersBySlotStatus(
      ReminderStatus status) async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders
        .where((reminder) =>
            reminder.hasMultipleTimes &&
            reminder.timeSlots.any((slot) => slot.status == status))
        .toList();
  }

  static Future<void> updateTimeSlotStatus(
      String reminderId, String timeSlotId, ReminderStatus newStatus) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null && reminder.hasMultipleTimes) {
      final updatedTimeSlots = reminder.timeSlots.map((slot) {
        if (slot.id == timeSlotId) {
          return slot.copyWith(
            status: newStatus,
            completedAt:
                newStatus == ReminderStatus.completed ? DateTime.now() : null,
          );
        }
        return slot;
      }).toList();

      // CRITICAL FIX: Check if all slots completed for repeating reminders
      final allCompleted = updatedTimeSlots
          .every((slot) => slot.status == ReminderStatus.completed);

      if (allCompleted && reminder.repeatType != RepeatType.none) {
        debugPrint('🔄 All time slots completed for repeating reminder');
        debugPrint('🔄 Resetting slots and rescheduling for next occurrence');

        // Reset all slots to pending for next occurrence
        final resetSlots = updatedTimeSlots.map((slot) {
          return slot.copyWith(
            status: ReminderStatus.pending,
            completedAt: null,
          );
        }).toList();

        // Calculate next occurrence
        DateTime nextScheduledTime;
        switch (reminder.repeatType) {
          case RepeatType.daily:
            nextScheduledTime =
                reminder.scheduledTime.add(const Duration(days: 1));
            break;
          case RepeatType.weekly:
            nextScheduledTime =
                reminder.scheduledTime.add(const Duration(days: 7));
            break;
          case RepeatType.monthly:
            final originalDate = reminder.scheduledTime;
            nextScheduledTime = DateTime(
              originalDate.year,
              originalDate.month + 1,
              originalDate.day,
              originalDate.hour,
              originalDate.minute,
            );
            break;
          case RepeatType.custom:
            if (reminder.customRepeatConfig != null) {
              nextScheduledTime = reminder.scheduledTime.add(
                Duration(minutes: reminder.customRepeatConfig!.totalMinutes),
              );
            } else {
              nextScheduledTime = reminder.scheduledTime;
            }
            break;
          case RepeatType.none:
            nextScheduledTime = reminder.scheduledTime;
            break;
        }

        final updatedReminder = reminder.copyWith(
          timeSlots: resetSlots,
          scheduledTime: nextScheduledTime,
          updatedAt: DateTime.now(),
        );

        await updateReminder(updatedReminder);
        debugPrint('✅ Reminder rescheduled to: $nextScheduledTime');

        // Reschedule notifications
        // Import at top: import '../services/notification_service.dart';
        if (updatedReminder.isNotificationEnabled) {
          await NotificationService.scheduleReminder(updatedReminder);
          debugPrint('✅ Notifications scheduled for next occurrence');
        }
      } else {
        // Just update this slot normally
        final updatedReminder = reminder.copyWith(timeSlots: updatedTimeSlots);
        await updateReminder(updatedReminder);
        debugPrint('✅ Time slot status updated');
      }
    }
  }

  static Future<void> addTimeSlot(String reminderId, TimeSlot timeSlot) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null) {
      final updatedTimeSlots = [...reminder.timeSlots, timeSlot];
      final updatedReminder = reminder.copyWith(
        timeSlots: updatedTimeSlots,
        isMultiTime: true,
      );
      await updateReminder(updatedReminder);
    }
  }

  static Future<void> removeTimeSlot(
      String reminderId, String timeSlotId) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null && reminder.hasMultipleTimes) {
      final updatedTimeSlots =
          reminder.timeSlots.where((slot) => slot.id != timeSlotId).toList();

      final updatedReminder = reminder.copyWith(
        timeSlots: updatedTimeSlots,
        isMultiTime: updatedTimeSlots.isNotEmpty,
      );
      await updateReminder(updatedReminder);
    }
  }

  static Future<void> updateTimeSlot(
      String reminderId, String timeSlotId, TimeSlot updatedTimeSlot) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null && reminder.hasMultipleTimes) {
      final updatedTimeSlots = reminder.timeSlots.map((slot) {
        if (slot.id == timeSlotId) {
          return updatedTimeSlot;
        }
        return slot;
      }).toList();

      final updatedReminder = reminder.copyWith(timeSlots: updatedTimeSlots);
      await updateReminder(updatedReminder);
    }
  }

  static Future<void> convertToMultiTime(
      String reminderId, List<TimeSlot> timeSlots) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null && !reminder.hasMultipleTimes) {
      final updatedReminder = reminder.copyWith(
        timeSlots: timeSlots,
        isMultiTime: true,
      );
      await updateReminder(updatedReminder);
    }
  }

  static Future<void> convertToSingleTime(String reminderId) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null && reminder.hasMultipleTimes) {
      final updatedReminder = reminder.copyWith(
        timeSlots: <TimeSlot>[],
        isMultiTime: false,
      );
      await updateReminder(updatedReminder);
    }
  }

  // =============================================================================
  // Existing Methods (Updated for Multi-Time Support)
  // =============================================================================

  static Future<List<Reminder>> getRemindersByStatus(
      ReminderStatus status) async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders.where((reminder) {
      if (reminder.hasMultipleTimes) {
        return reminder.overallStatus == status;
      } else {
        return reminder.status == status;
      }
    }).toList();
  }

  static Future<List<Reminder>> getUpcomingReminders() async {
    final List<Reminder> allReminders = await getReminders();
    final DateTime now = DateTime.now();
    final DateTime tomorrow = now.add(const Duration(days: 1));

    return allReminders.where((reminder) {
      if (reminder.hasMultipleTimes) {
        return reminder.overallStatus == ReminderStatus.pending &&
            reminder.nextPendingSlot != null;
      } else {
        return reminder.status == ReminderStatus.pending &&
            reminder.scheduledTime.isAfter(now) &&
            reminder.scheduledTime.isBefore(tomorrow);
      }
    }).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  static Future<List<Reminder>> getOverdueReminders() async {
    final List<Reminder> allReminders = await getReminders();

    return allReminders.where((reminder) {
      if (reminder.hasMultipleTimes) {
        return reminder.overallStatus == ReminderStatus.overdue;
      } else {
        return reminder.status == ReminderStatus.pending &&
            reminder.scheduledTime.isBefore(DateTime.now());
      }
    }).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  static Future<void> updateReminderStatus(
      String reminderId, ReminderStatus newStatus) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null) {
      // Handle repeat reminders when completed
      if (newStatus == ReminderStatus.completed &&
          reminder.repeatType != RepeatType.none) {
        await _updateToNextOccurrence(reminder);
        return; // Don't do regular status update for repeating reminders
      }

      // Regular status update for non-repeating reminders
      Reminder updatedReminder;
      if (reminder.hasMultipleTimes) {
        final updatedTimeSlots = reminder.timeSlots.map((slot) {
          if (slot.status == ReminderStatus.pending) {
            return slot.copyWith(
              status: newStatus,
              completedAt:
                  newStatus == ReminderStatus.completed ? DateTime.now() : null,
            );
          }
          return slot;
        }).toList();

        updatedReminder = reminder.copyWith(timeSlots: updatedTimeSlots);
      } else {
        updatedReminder = reminder.copyWith(
          status: newStatus,
          completedAt:
              newStatus == ReminderStatus.completed ? DateTime.now() : null,
        );
      }

      await updateReminder(updatedReminder);

      // TRIPLE notification for critical status updates
      await markNotificationUpdate();
      await Future.delayed(const Duration(milliseconds: 100));
      await markNotificationUpdate();

      debugPrint('✅ Updated reminder status: $reminderId → $newStatus');
    }
  }

  /// Update a repeating reminder to its next occurrence
  static Future<void> _updateToNextOccurrence(Reminder originalReminder) async {
    try {
      DateTime nextScheduledTime;

      switch (originalReminder.repeatType) {
        case RepeatType.daily:
          nextScheduledTime =
              originalReminder.scheduledTime.add(const Duration(days: 1));
          break;
        case RepeatType.weekly:
          nextScheduledTime =
              originalReminder.scheduledTime.add(const Duration(days: 7));
          break;
        case RepeatType.monthly:
          final originalDate = originalReminder.scheduledTime;
          nextScheduledTime = DateTime(
            originalDate.year,
            originalDate.month + 1,
            originalDate.day,
            originalDate.hour,
            originalDate.minute,
          );
          break;
        case RepeatType.custom:
          if (originalReminder.customRepeatConfig != null) {
            nextScheduledTime = originalReminder.scheduledTime.add(
              Duration(minutes: originalReminder.customRepeatConfig!.totalMinutes),
            );
          } else {
            return; // No valid config
          }
          break;
        case RepeatType.none:
          return; // No repeat
      }

      // Update the existing reminder to next occurrence
      final updatedReminder = originalReminder.copyWith(
        scheduledTime: nextScheduledTime,
        status: ReminderStatus.pending, // Reset to pending
        completedAt: null, // Clear completion time
        timeSlots: originalReminder.hasMultipleTimes
            ? originalReminder.timeSlots
                .map((slot) => slot.copyWith(
                      status:
                          ReminderStatus.pending, // Reset all slots to pending
                      completedAt: null, // Clear completion time
                    ))
                .toList()
            : originalReminder.timeSlots,
        updatedAt: DateTime.now(), // Update the modified time
      );

      // Update the existing reminder
      await updateReminder(updatedReminder);

      // Schedule notification for the updated reminder
      if (updatedReminder.isNotificationEnabled) {
        await NotificationService.scheduleReminder(updatedReminder);
        // Update badge count after rescheduling
        await NotificationService.updateBadgeCount();
      }

      debugPrint(
          '🔄 Updated ${originalReminder.repeatType.name} reminder to next occurrence');
      debugPrint(
          '📅 Next scheduled: ${DateFormat('MMM dd, yyyy • h:mm a').format(nextScheduledTime)}');
    } catch (e) {
      debugPrint('❌ Error updating to next occurrence: $e');
    }
  }

  static Future<void> forceImmediateRefresh() async {
    try {
      // Force SharedPreferences reload
      await _prefs?.reload();

      // Get fresh data directly from storage
      final reminders = await getReminders();

      // Force stream update
      _remindersController.add(reminders);

      // Update tracking
      _lastKnownUpdate = DateTime.now();

      debugPrint(
          '🔄 Force immediate refresh completed: ${reminders.length} reminders');
    } catch (e) {
      debugPrint('⚠️ Error in force immediate refresh: $e');
    }
  }

  static Future<int> getTotalRemindersCount() async {
    final List<Reminder> reminders = await getReminders();
    return reminders.length;
  }

  static Future<int> getCompletedRemindersCount() async {
    final List<Reminder> reminders = await getReminders();
    return reminders.where((r) {
      if (r.hasMultipleTimes) {
        return r.overallStatus == ReminderStatus.completed;
      } else {
        return r.status == ReminderStatus.completed;
      }
    }).length;
  }

  static Future<int> getPendingRemindersCount() async {
    final List<Reminder> reminders = await getReminders();
    return reminders.where((r) {
      if (r.hasMultipleTimes) {
        return r.overallStatus == ReminderStatus.pending;
      } else {
        return r.status == ReminderStatus.pending;
      }
    }).length;
  }

  static Future<void> refreshData() async {
    final reminders = await getReminders();
    _remindersController.add(reminders);
    debugPrint(
        '🔄 Refreshed reminder data - ${reminders.length} reminders loaded');
  }

  static Future<List<Reminder>> getRemindersBySpace(String? spaceId) async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders
        .where((reminder) => reminder.spaceId == spaceId)
        .toList();
  }

  static Future<List<Reminder>> getRemindersWithoutSpace() async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders.where((reminder) => reminder.spaceId == null).toList();
  }

  static Future<void> updateReminderSpace(
      String reminderId, String? spaceId) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null) {
      final Reminder updatedReminder = reminder.copyWith(spaceId: spaceId);
      await updateReminder(updatedReminder);
    }
  }

  static Future<int> getSpaceReminderCount(String spaceId) async {
    final List<Reminder> spaceReminders = await getRemindersBySpace(spaceId);
    return spaceReminders.length;
  }

  static Future<void> removeRemindersFromSpace(String spaceId) async {
    final List<Reminder> allReminders = await getReminders();
    final List<Reminder> updatedReminders = allReminders.map((reminder) {
      if (reminder.spaceId == spaceId) {
        return reminder.copyWith(spaceId: null);
      }
      return reminder;
    }).toList();

    await saveReminders(updatedReminders);
  }

  // =============================================================================
  // Enhanced AI Configuration Methods with Backup System
  // =============================================================================

  static Future<void> setGeminiApiKey(String? apiKey) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        await _prefs?.remove(_geminiApiKeyKey);
        await _prefs?.remove(_geminiApiKeyBackupKey);
      } else {
        await _prefs?.setString(_geminiApiKeyKey, apiKey);
        await _prefs?.setString(_geminiApiKeyBackupKey, apiKey);
        debugPrint('💾 Saved Gemini API key with backup');
      }
    } catch (e) {
      debugPrint('❌ Error saving Gemini API key: $e');
      rethrow;
    }
  }

  static Future<String?> getGeminiApiKey() async {
    try {
      String? apiKey = _prefs?.getString(_geminiApiKeyKey);

      if (apiKey == null || apiKey.isEmpty) {
        apiKey = _prefs?.getString(_geminiApiKeyBackupKey);
        if (apiKey != null && apiKey.isNotEmpty) {
          await _prefs?.setString(_geminiApiKeyKey, apiKey);
          debugPrint('🔄 Restored Gemini API key from backup');
        }
      }

      return apiKey;
    } catch (e) {
      debugPrint('❌ Error retrieving Gemini API key: $e');
      return null;
    }
  }

  static Future<void> setGroqApiKey(String? apiKey) async {
    try {
      if (apiKey == null || apiKey.isEmpty) {
        await _prefs?.remove(_groqApiKeyKey);
        await _prefs?.remove(_groqApiKeyBackupKey);
      } else {
        await _prefs?.setString(_groqApiKeyKey, apiKey);
        await _prefs?.setString(_groqApiKeyBackupKey, apiKey);
        debugPrint('💾 Saved Groq API key with backup');
      }
    } catch (e) {
      debugPrint('❌ Error saving Groq API key: $e');
      rethrow;
    }
  }

  static Future<String?> getGroqApiKey() async {
    try {
      String? apiKey = _prefs?.getString(_groqApiKeyKey);

      if (apiKey == null || apiKey.isEmpty) {
        apiKey = _prefs?.getString(_groqApiKeyBackupKey);
        if (apiKey != null && apiKey.isNotEmpty) {
          await _prefs?.setString(_groqApiKeyKey, apiKey);
          debugPrint('🔄 Restored Groq API key from backup');
        }
      }

      return apiKey;
    } catch (e) {
      debugPrint('❌ Error retrieving Groq API key: $e');
      return null;
    }
  }

  static Future<void> setSelectedAIProvider(String? provider) async {
    try {
      if (provider == null || provider == 'none') {
        await _prefs?.remove(_selectedAIProviderKey);
        await _prefs?.remove(_selectedAIProviderBackupKey);
      } else {
        await _prefs?.setString(_selectedAIProviderKey, provider);
        await _prefs?.setString(_selectedAIProviderBackupKey, provider);
        debugPrint('💾 Saved selected provider ($provider) with backup');
      }
    } catch (e) {
      debugPrint('❌ Error saving selected provider: $e');
      rethrow;
    }
  }

  static Future<String?> getSelectedAIProvider() async {
    try {
      String? provider = _prefs?.getString(_selectedAIProviderKey);

      if (provider == null || provider.isEmpty) {
        provider = _prefs?.getString(_selectedAIProviderBackupKey);
        if (provider != null && provider.isNotEmpty) {
          await _prefs?.setString(_selectedAIProviderKey, provider);
          debugPrint('🔄 Restored selected provider from backup');
        }
      }

      return provider;
    } catch (e) {
      debugPrint('❌ Error retrieving selected provider: $e');
      return null;
    }
  }

  static Future<bool> hasAnyAIProvider() async {
    final geminiKey = await getGeminiApiKey();
    final groqKey = await getGroqApiKey();
    return (geminiKey?.isNotEmpty == true) || (groqKey?.isNotEmpty == true);
  }

  static Future<Map<String, dynamic>> getAIConfigurationStatus() async {
    final geminiKey = await getGeminiApiKey();
    final groqKey = await getGroqApiKey();
    final selectedProvider = await getSelectedAIProvider();

    return {
      'hasGemini': geminiKey?.isNotEmpty == true,
      'hasGroq': groqKey?.isNotEmpty == true,
      'selectedProvider': selectedProvider ?? 'none',
      'hasAnyProvider':
          (geminiKey?.isNotEmpty == true) || (groqKey?.isNotEmpty == true),
      'geminiStatus': geminiKey?.isNotEmpty == true
          ? 'Configured (${geminiKey!.substring(0, math.min(8, geminiKey.length))}...)'
          : 'Not configured',
      'groqStatus': groqKey?.isNotEmpty == true
          ? 'Configured (${groqKey!.substring(0, math.min(8, groqKey.length))}...)'
          : 'Not configured',
    };
  }

  static Future<void> clearAIConfiguration() async {
    try {
      await _prefs?.remove(_geminiApiKeyKey);
      await _prefs?.remove(_groqApiKeyKey);
      await _prefs?.remove(_selectedAIProviderKey);
      await _prefs?.remove(_geminiApiKeyBackupKey);
      await _prefs?.remove(_groqApiKeyBackupKey);
      await _prefs?.remove(_selectedAIProviderBackupKey);
      debugPrint('🗑️ Cleared all AI configuration and backups');
    } catch (e) {
      debugPrint('❌ Error clearing AI configuration: $e');
      rethrow;
    }
  }

  static bool isValidApiKeyFormat(String apiKey, String provider) {
    if (apiKey.isEmpty) return false;

    switch (provider.toLowerCase()) {
      case 'gemini':
        return apiKey.startsWith('AI') && apiKey.length >= 30;
      case 'groq':
        return apiKey.startsWith('gsk_') && apiKey.length >= 30;
      default:
        return apiKey.length >= 20;
    }
  }

  static Future<bool> isAPIKeyConfigured(String provider) async {
    switch (provider.toLowerCase()) {
      case 'gemini':
        final key = await getGeminiApiKey();
        return key?.isNotEmpty == true;
      case 'groq':
        final key = await getGroqApiKey();
        return key?.isNotEmpty == true;
      default:
        return false;
    }
  }

  static Future<String?> getCurrentProviderApiKey() async {
    final selectedProvider = await getSelectedAIProvider();
    if (selectedProvider == null || selectedProvider == 'none') {
      return null;
    }

    switch (selectedProvider) {
      case 'gemini':
        return await getGeminiApiKey();
      case 'groq':
        return await getGroqApiKey();
      default:
        return null;
    }
  }

  static Future<bool> switchAIProvider(String newProvider) async {
    if (newProvider == 'none') {
      await setSelectedAIProvider('none');
      return true;
    }

    final hasKey = await isAPIKeyConfigured(newProvider);
    if (hasKey) {
      await setSelectedAIProvider(newProvider);
      return true;
    }

    return false;
  }

  static Future<Map<String, String?>> exportAIConfiguration() async {
    return {
      'geminiApiKey': await getGeminiApiKey(),
      'groqApiKey': await getGroqApiKey(),
      'selectedProvider': await getSelectedAIProvider(),
      'geminiApiKeyBackup': _prefs?.getString(_geminiApiKeyBackupKey),
      'groqApiKeyBackup': _prefs?.getString(_groqApiKeyBackupKey),
      'selectedProviderBackup': _prefs?.getString(_selectedAIProviderBackupKey),
      'storageVersion': _currentStorageVersion.toString(),
      'apiConfigVersion': _currentApiConfigVersion.toString(),
    };
  }

  static Future<void> importAIConfiguration(Map<String, String?> config) async {
    try {
      if (config['geminiApiKey'] != null) {
        await setGeminiApiKey(config['geminiApiKey']);
      }
      if (config['groqApiKey'] != null) {
        await setGroqApiKey(config['groqApiKey']);
      }
      if (config['selectedProvider'] != null) {
        await setSelectedAIProvider(config['selectedProvider']);
      }

      if (config['geminiApiKeyBackup'] != null) {
        await _prefs?.setString(
            _geminiApiKeyBackupKey, config['geminiApiKeyBackup']!);
      }
      if (config['groqApiKeyBackup'] != null) {
        await _prefs?.setString(
            _groqApiKeyBackupKey, config['groqApiKeyBackup']!);
      }
      if (config['selectedProviderBackup'] != null) {
        await _prefs?.setString(
            _selectedAIProviderBackupKey, config['selectedProviderBackup']!);
      }

      debugPrint('✅ AI configuration imported successfully');
    } catch (e) {
      debugPrint('❌ Error importing AI configuration: $e');
      rethrow;
    }
  }

  /// Set whether to use custom snooze duration (false = default 10min+1hour)
  static Future<void> setSnoozeUseCustom(bool useCustom) async {
    try {
      await _prefs?.setBool(_snoozeUseCustomKey, useCustom);
      debugPrint('💾 Saved snooze use custom: $useCustom');
    } catch (e) {
      debugPrint('❌ Error saving snooze use custom: $e');
      rethrow;
    }
  }

  /// Get whether to use custom snooze duration (false = default)
  static Future<bool> getSnoozeUseCustom() async {
    try {
      return _prefs?.getBool(_snoozeUseCustomKey) ?? false; // Default to false
    } catch (e) {
      debugPrint('❌ Error getting snooze use custom: $e');
      return false; // Fallback to default
    }
  }

  /// Set custom snooze duration in minutes
  static Future<void> setSnoozeCustomMinutes(int minutes) async {
    try {
      // Validate range
      final validMinutes = minutes.clamp(1, 120);
      await _prefs?.setInt(_snoozeCustomMinutesKey, validMinutes);
      debugPrint('💾 Saved custom snooze minutes: $validMinutes');
    } catch (e) {
      debugPrint('❌ Error saving custom snooze minutes: $e');
      rethrow;
    }
  }

  /// Get custom snooze duration in minutes (default: 15)
  static Future<int> getSnoozeCustomMinutes() async {
    try {
      return _prefs?.getInt(_snoozeCustomMinutesKey) ??
          15; // Default to 15 minutes
    } catch (e) {
      debugPrint('❌ Error getting custom snooze minutes: $e');
      return 15; // Fallback to 15 minutes
    }
  }

  /// Get snooze configuration summary
  static Future<Map<String, dynamic>> getSnoozeConfiguration() async {
    final useCustom = await getSnoozeUseCustom();
    final customMinutes = await getSnoozeCustomMinutes();

    return {
      'useCustom': useCustom,
      'customMinutes': customMinutes,
      'description': useCustom
          ? 'Custom: $customMinutes minutes'
          : 'Default: 10min, 1hour',
    };
  }

  // =============================================================================
  // Global Alarm Preference Methods
  // =============================================================================

  /// Set whether to use alarms instead of notifications globally
  static Future<void> setUseAlarmInsteadOfNotification(bool useAlarm) async {
    try {
      await _prefs?.setBool(_useAlarmInsteadOfNotificationKey, useAlarm);
      debugPrint('💾 Saved global alarm preference: $useAlarm');
    } catch (e) {
      debugPrint('❌ Error saving alarm preference: $e');
      rethrow;
    }
  }

  /// Get whether to use alarms instead of notifications globally
  static Future<bool> getUseAlarmInsteadOfNotification() async {
    try {
      return _prefs?.getBool(_useAlarmInsteadOfNotificationKey) ??
          false; // Default to notifications
    } catch (e) {
      debugPrint('❌ Error getting alarm preference: $e');
      return false; // Fallback to notifications
    }
  }

  /// Get global alarm configuration summary
  static Future<Map<String, dynamic>> getAlarmConfiguration() async {
    final useAlarm = await getUseAlarmInsteadOfNotification();

    return {
      'useAlarm': useAlarm,
      'description': useAlarm
          ? 'Full-screen alarms (Samsung style)'
          : 'Standard notifications',
    };
  }
}
