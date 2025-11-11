// [lib/controllers]/reminder_form_controller.dart
// Controller for managing reminder form state across different UI contexts

import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../models/space.dart';
import '../services/reminder_service.dart';
import '../services/spaces_service.dart';

class ReminderFormController extends ChangeNotifier {
  // Text controllers
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // Form state
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  RepeatType _selectedRepeat = RepeatType.none;
  bool _isNotificationEnabled = true;
  Space? _selectedSpace;

  // Multi-time state
  bool _isMultiTime = false;
  List<TimeSlot> _timeSlots = [];

  // Available spaces
  List<Space> _availableSpaces = [];

  // Edit mode state
  bool _isEditing = false;
  Reminder? _originalReminder;

  // Loading state
  bool _isLoading = false;

  // Getters
  DateTime get selectedDate => _selectedDate;
  TimeOfDay get selectedTime => _selectedTime;
  RepeatType get selectedRepeat => _selectedRepeat;
  bool get isNotificationEnabled => _isNotificationEnabled;
  Space? get selectedSpace => _selectedSpace;
  bool get isMultiTime => _isMultiTime;
  List<TimeSlot> get timeSlots => _timeSlots;
  List<Space> get availableSpaces => _availableSpaces;
  bool get isEditing => _isEditing;
  bool get isLoading => _isLoading;
  Reminder? get originalReminder => _originalReminder;

  ReminderFormController({
    Reminder? reminder,
    Space? preSelectedSpace,
  }) {
    _selectedSpace = preSelectedSpace;

    if (reminder != null) {
      _isEditing = true;
      _originalReminder = reminder;
      populateFromReminder(reminder);
    } else {
      // Set default time to next hour
      final now = DateTime.now();
      _selectedTime = TimeOfDay(hour: now.hour + 1, minute: 0);
      _selectedDate = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }

    loadSpaces();
  }

  /// Load available spaces
  Future<void> loadSpaces() async {
    try {
      _availableSpaces = await SpacesService.getSpaces();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading spaces: $e');
    }
  }

  /// Populate form fields from an existing reminder
  void populateFromReminder(Reminder reminder) async {
    titleController.text = reminder.title;
    descriptionController.text = reminder.description ?? '';
    _selectedDate = reminder.scheduledTime;
    _selectedTime = TimeOfDay.fromDateTime(reminder.scheduledTime);
    _selectedRepeat = reminder.repeatType;
    _isNotificationEnabled = reminder.isNotificationEnabled;
    _isMultiTime = reminder.hasMultipleTimes;
    _timeSlots = List.from(reminder.timeSlots);

    if (reminder.spaceId != null) {
      _selectedSpace = await SpacesService.getSpaceById(reminder.spaceId!);
    }

    notifyListeners();
  }

  /// Update selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(
      date.year,
      date.month,
      date.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    notifyListeners();
  }

  /// Update selected time
  void setSelectedTime(TimeOfDay time) {
    _selectedTime = time;
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
    notifyListeners();
  }

  /// Update repeat type
  void setRepeatType(RepeatType repeat) {
    _selectedRepeat = repeat;
    notifyListeners();
  }

  /// Update notification enabled state
  void setNotificationEnabled(bool enabled) {
    _isNotificationEnabled = enabled;
    notifyListeners();
  }

  /// Update selected space
  void setSelectedSpace(Space? space) {
    _selectedSpace = space;
    notifyListeners();
  }

  /// Update multi-time toggle
  void setMultiTime(bool isMultiTime) {
    _isMultiTime = isMultiTime;
    if (!isMultiTime) {
      _timeSlots.clear();
    }
    notifyListeners();
  }

  /// Update time slots
  void setTimeSlots(List<TimeSlot> timeSlots) {
    _timeSlots = timeSlots;
    notifyListeners();
  }

  /// Validate form data
  String? validate() {
    return ReminderService.validateReminderData(
      title: titleController.text,
      isMultiTime: _isMultiTime,
      timeSlots: _timeSlots,
    );
  }

  /// Save the reminder (create or update)
  Future<Reminder> save() async {
    _isLoading = true;
    notifyListeners();

    try {
      final reminder = await ReminderService.saveReminder(
        existingReminder: _originalReminder,
        title: titleController.text,
        description: descriptionController.text,
        scheduledTime: _selectedDate,
        repeatType: _selectedRepeat,
        isNotificationEnabled: _isNotificationEnabled,
        spaceId: _selectedSpace?.id,
        timeSlots: _timeSlots,
        isMultiTime: _isMultiTime,
      );

      _isLoading = false;
      notifyListeners();

      return reminder;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Reset form to default state
  void reset() {
    titleController.clear();
    descriptionController.clear();
    final now = DateTime.now();
    _selectedTime = TimeOfDay(hour: now.hour + 1, minute: 0);
    _selectedDate = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _selectedRepeat = RepeatType.none;
    _isNotificationEnabled = true;
    _selectedSpace = null;
    _isMultiTime = false;
    _timeSlots.clear();
    _isEditing = false;
    _originalReminder = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
