import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_remind/services/storage_service.dart';
import '../models/space.dart';

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
  // Delete a space
  static Future<void> deleteSpace(String spaceId) async {
    // First remove all reminders from this space
    await StorageService.removeRemindersFromSpace(spaceId);

    // Then delete the space
    final List<Space> spaces = await getSpaces();
    spaces.removeWhere((space) => space.id == spaceId);
    await saveSpaces(spaces);
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
}
