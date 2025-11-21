import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_remind/services/storage_service.dart';
import 'package:voice_remind/services/notification_service.dart';
import '../models/space.dart';
import 'package:flutter/material.dart';

class SpacesService {
  static SharedPreferences? _prefs;
  static const String _spacesKey = 'spaces';

  // Stream controller for real-time updates
  static final StreamController<List<Space>> _spacesController =
      StreamController<List<Space>>.broadcast();

  // Stream getter for listening to space changes
  static Stream<List<Space>> get spacesStream => _spacesController.stream;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Emit initial data
    final initialSpaces = await getSpaces();
    _spacesController.add(initialSpaces);
  }

  // Dispose method to close stream controller
  static void dispose() {
    _spacesController.close();
  }

  // Get all spaces
  static Future<List<Space>> getSpaces() async {
    final String? spacesJson = _prefs?.getString(_spacesKey);
    if (spacesJson == null || spacesJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> spacesList = json.decode(spacesJson);
      return spacesList.map((spaceMap) => Space.fromMap(spaceMap)).toList()
        ..sort((a, b) =>
            a.createdAt.compareTo(b.createdAt)); // Sort by creation time
    } catch (e) {
      // If there's an error parsing, return empty list
      return [];
    }
  }

  // Save all spaces and emit update
  static Future<void> saveSpaces(List<Space> spaces) async {
    final List<Map<String, dynamic>> spacesMapList =
        spaces.map((space) => space.toMap()).toList();
    final String spacesJson = json.encode(spacesMapList);
    await _prefs?.setString(_spacesKey, spacesJson);

    // Emit updated spaces to stream
    _spacesController.add(spaces);
  }

  // Add a new space
  static Future<void> addSpace(Space space) async {
    final List<Space> spaces = await getSpaces();
    spaces.add(space);
    await saveSpaces(spaces);
  }

  // Update an existing space
  static Future<void> updateSpace(Space updatedSpace) async {
    final List<Space> spaces = await getSpaces();
    final int index = spaces.indexWhere((s) => s.id == updatedSpace.id);

    if (index != -1) {
      spaces[index] = updatedSpace;
      await saveSpaces(spaces);
    }
  }

  // Delete a space
  static Future<void> deleteSpace(String spaceId,
      {bool deleteReminders = true}) async {
    if (deleteReminders) {
      // Actually DELETE all reminders from this space
      await _deleteRemindersInSpace(spaceId);
    } else {
      // Just unassign reminders from this space (set spaceId to null)
      final allReminders = await StorageService.getReminders();
      final updatedReminders = allReminders.map((reminder) {
        if (reminder.spaceId == spaceId) {
          return reminder.copyWith(spaceId: null);
        }
        return reminder;
      }).toList();
      await StorageService.saveReminders(updatedReminders);
    }

    // Then delete the space
    final List<Space> spaces = await getSpaces();
    spaces.removeWhere((space) => space.id == spaceId);
    await saveSpaces(spaces);
  }

  // Helper method to actually DELETE reminders in a space (not just unassign)
  static Future<void> _deleteRemindersInSpace(String spaceId) async {
    final allReminders = await StorageService.getReminders();

    // Get reminders to delete (for canceling notifications)
    final remindersToDelete =
        allReminders.where((reminder) => reminder.spaceId == spaceId).toList();

    // Cancel notifications for deleted reminders
    for (final reminder in remindersToDelete) {
      try {
        await NotificationService.cancelReminder(reminder.id);
      } catch (e) {
        // Continue if notification cancellation fails
        debugPrint(
            'Failed to cancel notification for reminder ${reminder.id}: $e');
      }
    }

    // Keep only reminders that are NOT in this space
    final remindersToKeep =
        allReminders.where((reminder) => reminder.spaceId != spaceId).toList();
    await StorageService.saveReminders(remindersToKeep);
  }

  // Get space by ID
  static Future<Space?> getSpaceById(String spaceId) async {
    final List<Space> spaces = await getSpaces();
    try {
      return spaces.firstWhere((space) => space.id == spaceId);
    } catch (e) {
      return null;
    }
  }

  // Clear all spaces
  static Future<void> clearAllSpaces() async {
    await _prefs?.remove(_spacesKey);
    _spacesController.add([]); // Emit empty list
  }

  // Get spaces count
  static Future<int> getSpacesCount() async {
    final List<Space> spaces = await getSpaces();
    return spaces.length;
  }

  // Force refresh - manually emit current data
  static Future<void> refreshData() async {
    final spaces = await getSpaces();
    _spacesController.add(spaces);
  }

  // === BULK OPERATIONS ===

  // Bulk delete spaces
  static Future<void> bulkDeleteSpaces(List<String> spaceIds,
      {bool deleteReminders = true}) async {
    if (deleteReminders) {
      // Actually DELETE all reminders from these spaces
      for (final spaceId in spaceIds) {
        await _deleteRemindersInSpace(spaceId);
      }
    } else {
      // Just unassign reminders from these spaces
      final allReminders = await StorageService.getReminders();
      final updatedReminders = allReminders.map((reminder) {
        if (spaceIds.contains(reminder.spaceId)) {
          return reminder.copyWith(spaceId: null);
        }
        return reminder;
      }).toList();
      await StorageService.saveReminders(updatedReminders);
    }

    // Delete the spaces
    final List<Space> spaces = await getSpaces();
    spaces.removeWhere((space) => spaceIds.contains(space.id));
    await saveSpaces(spaces);
  }

  // Bulk update space colors
  static Future<void> bulkUpdateSpaceColor(
      List<String> spaceIds, Color newColor) async {
    final List<Space> spaces = await getSpaces();
    for (int i = 0; i < spaces.length; i++) {
      if (spaceIds.contains(spaces[i].id)) {
        spaces[i] = spaces[i].copyWith(color: newColor);
      }
    }
    await saveSpaces(spaces);
  }

  // Bulk update space icons
  static Future<void> bulkUpdateSpaceIcon(
      List<String> spaceIds, IconData newIcon) async {
    final List<Space> spaces = await getSpaces();
    for (int i = 0; i < spaces.length; i++) {
      if (spaceIds.contains(spaces[i].id)) {
        spaces[i] = spaces[i].copyWith(icon: newIcon);
      }
    }
    await saveSpaces(spaces);
  }

  // Bulk duplicate spaces
  static Future<void> bulkDuplicateSpaces(List<String> spaceIds) async {
    final List<Space> spaces = await getSpaces();
    final List<Space> newSpaces = [];

    for (final spaceId in spaceIds) {
      final space = spaces.firstWhere((s) => s.id == spaceId);
      final duplicatedSpace = Space(
        id: '${DateTime.now().millisecondsSinceEpoch}_${newSpaces.length}',
        name: '${space.name} Copy',
        color: space.color,
        icon: space.icon,
        createdAt: DateTime.now(),
      );
      newSpaces.add(duplicatedSpace);
    }

    spaces.addAll(newSpaces);
    await saveSpaces(spaces);
  }
}
