import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

class StorageService {
  static SharedPreferences? _prefs;
  static const String _remindersKey = 'reminders';

  // Stream controller for real-time updates
  static final StreamController<List<Reminder>> _remindersController =
      StreamController<List<Reminder>>.broadcast();

  // Stream getter for listening to reminder changes
  static Stream<List<Reminder>> get remindersStream =>
      _remindersController.stream;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Emit initial data
    final initialReminders = await getReminders();
    _remindersController.add(initialReminders);
  }

  // Dispose method to close stream controller
  static void dispose() {
    _remindersController.close();
  }

  // Get all reminders
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
        ..sort((a, b) =>
            a.scheduledTime.compareTo(b.scheduledTime)); // Sort by time
    } catch (e) {
      // If there's an error parsing, return empty list
      return [];
    }
  }

  // Save all reminders and emit update
  static Future<void> saveReminders(List<Reminder> reminders) async {
    final List<Map<String, dynamic>> remindersMapList =
        reminders.map((reminder) => reminder.toMap()).toList();
    final String remindersJson = json.encode(remindersMapList);
    await _prefs?.setString(_remindersKey, remindersJson);

    // Emit updated reminders to stream
    _remindersController.add(reminders);
  }

  // Add a new reminder
  static Future<void> addReminder(Reminder reminder) async {
    final List<Reminder> reminders = await getReminders();
    reminders.add(reminder);
    await saveReminders(reminders);
  }

  // Update an existing reminder
  static Future<void> updateReminder(Reminder updatedReminder) async {
    final List<Reminder> reminders = await getReminders();
    final int index = reminders.indexWhere((r) => r.id == updatedReminder.id);

    if (index != -1) {
      reminders[index] = updatedReminder;
      await saveReminders(reminders);
    }
  }

  // Delete a reminder
  static Future<void> deleteReminder(String reminderId) async {
    final List<Reminder> reminders = await getReminders();
    reminders.removeWhere((reminder) => reminder.id == reminderId);
    await saveReminders(reminders);
  }

  // Get reminder by ID
  static Future<Reminder?> getReminderById(String reminderId) async {
    final List<Reminder> reminders = await getReminders();
    try {
      return reminders.firstWhere((reminder) => reminder.id == reminderId);
    } catch (e) {
      return null;
    }
  }

  // Clear all reminders
  static Future<void> clearAllReminders() async {
    await _prefs?.remove(_remindersKey);
    _remindersController.add([]); // Emit empty list
  }

  // Get reminders by status
  static Future<List<Reminder>> getRemindersByStatus(
      ReminderStatus status) async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders.where((reminder) => reminder.status == status).toList();
  }

  // Get upcoming reminders (next 24 hours)
  static Future<List<Reminder>> getUpcomingReminders() async {
    final List<Reminder> allReminders = await getReminders();
    final DateTime now = DateTime.now();
    final DateTime tomorrow = now.add(const Duration(days: 1));

    return allReminders
        .where((reminder) =>
            reminder.status == ReminderStatus.pending &&
            reminder.scheduledTime.isAfter(now) &&
            reminder.scheduledTime.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  // Get overdue reminders
  static Future<List<Reminder>> getOverdueReminders() async {
    final List<Reminder> allReminders = await getReminders();
    final DateTime now = DateTime.now();

    return allReminders
        .where((reminder) =>
            reminder.status == ReminderStatus.pending &&
            reminder.scheduledTime.isBefore(now))
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
  }

  // Update reminder status
  static Future<void> updateReminderStatus(
      String reminderId, ReminderStatus newStatus) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null) {
      final Reminder updatedReminder = reminder.copyWith(status: newStatus);
      await updateReminder(updatedReminder);
    }
  }

  // Statistics helpers
  static Future<int> getTotalRemindersCount() async {
    final List<Reminder> reminders = await getReminders();
    return reminders.length;
  }

  static Future<int> getCompletedRemindersCount() async {
    final List<Reminder> reminders = await getReminders();
    return reminders.where((r) => r.status == ReminderStatus.completed).length;
  }

  static Future<int> getPendingRemindersCount() async {
    final List<Reminder> reminders = await getReminders();
    return reminders.where((r) => r.status == ReminderStatus.pending).length;
  }

  // Force refresh - manually emit current data
  static Future<void> refreshData() async {
    final reminders = await getReminders();
    _remindersController.add(reminders);
  }

  // Clear all data - for testing or reset purposes// Get reminders by space ID
  static Future<List<Reminder>> getRemindersBySpace(String? spaceId) async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders
        .where((reminder) => reminder.spaceId == spaceId)
        .toList();
  }

// Get reminders without space assignment
  static Future<List<Reminder>> getRemindersWithoutSpace() async {
    final List<Reminder> allReminders = await getReminders();
    return allReminders.where((reminder) => reminder.spaceId == null).toList();
  }

// Update reminder space assignment
  static Future<void> updateReminderSpace(
      String reminderId, String? spaceId) async {
    final Reminder? reminder = await getReminderById(reminderId);
    if (reminder != null) {
      final Reminder updatedReminder = reminder.copyWith(spaceId: spaceId);
      await updateReminder(updatedReminder);
    }
  }

// Get count of reminders in a space
  static Future<int> getSpaceReminderCount(String spaceId) async {
    final List<Reminder> spaceReminders = await getRemindersBySpace(spaceId);
    return spaceReminders.length;
  }

// Remove all reminders from a space (when space is deleted)
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
}
