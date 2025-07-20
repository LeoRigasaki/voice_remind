// lib/models/filter_state.dart

import 'package:flutter/material.dart';

import '../models/sort_option.dart';
import '../models/reminder.dart';

enum FilterStatus {
  all,
  pending,
  completed,
  overdue,
}

enum FilterDateRange {
  allTime,
  today,
  tomorrow,
  thisWeek,
  nextWeek,
  thisMonth,
  customRange,
}

enum FilterTimeOfDay {
  anyTime,
  morning, // 6 AM - 12 PM
  afternoon, // 12 PM - 6 PM
  evening, // 6 PM - 10 PM
  night, // 10 PM - 6 AM
  customTime,
}

class FilterState {
  final FilterStatus status;
  final String? selectedSpaceId; // null means "All Spaces"
  final FilterDateRange dateRange;
  final FilterTimeOfDay timeOfDay;
  final SortOption sortOption;
  final bool isGridView; // For quick filters display
  final bool isSpacesGridView; // For spaces display
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final TimeOfDay? customStartTime;
  final TimeOfDay? customEndTime;
  final String searchQuery;

  const FilterState({
    this.status = FilterStatus.all,
    this.selectedSpaceId,
    this.dateRange = FilterDateRange.allTime,
    this.timeOfDay = FilterTimeOfDay.anyTime,
    this.sortOption = const SortOption(
      type: SortType.dateCreated,
      order: SortOrder.descending,
      label: 'Date Created (Newest)',
      icon: Icons.calendar_today_outlined,
    ),
    this.isGridView = false,
    this.isSpacesGridView = false,
    this.customStartDate,
    this.customEndDate,
    this.customStartTime,
    this.customEndTime,
    this.searchQuery = '',
  });

  // Copy with method for state updates
  FilterState copyWith(
      {FilterStatus? status,
      String? selectedSpaceId,
      FilterDateRange? dateRange,
      FilterTimeOfDay? timeOfDay,
      SortOption? sortOption,
      bool? isGridView,
      bool? isSpacesGridView,
      DateTime? customStartDate,
      DateTime? customEndDate,
      TimeOfDay? customStartTime,
      TimeOfDay? customEndTime,
      String? searchQuery,
      bool clearSpaceId = false,
      bool clearCustomDates = false,
      bool clearCustomTimes = false}) {
    return FilterState(
      status: status ?? this.status,
      selectedSpaceId:
          clearSpaceId ? null : (selectedSpaceId ?? this.selectedSpaceId),
      dateRange: dateRange ?? this.dateRange,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      sortOption: sortOption ?? this.sortOption,
      isGridView: isGridView ?? this.isGridView,
      isSpacesGridView: isSpacesGridView ?? this.isSpacesGridView,
      customStartDate:
          clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate:
          clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      customStartTime:
          clearCustomTimes ? null : (customStartTime ?? this.customStartTime),
      customEndTime:
          clearCustomTimes ? null : (customEndTime ?? this.customEndTime),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  // Reset to default state
  FilterState reset() {
    return const FilterState();
  }

  // Check if any filters are applied (not default)
  bool get hasActiveFilters {
    return status != FilterStatus.all ||
        selectedSpaceId != null ||
        dateRange != FilterDateRange.allTime ||
        timeOfDay != FilterTimeOfDay.anyTime ||
        searchQuery.isNotEmpty;
  }

  // Get filter labels for display
  String get statusLabel {
    switch (status) {
      case FilterStatus.all:
        return 'All';
      case FilterStatus.pending:
        return 'Pending';
      case FilterStatus.completed:
        return 'Completed';
      case FilterStatus.overdue:
        return 'Overdue';
    }
  }

  String get dateRangeLabel {
    switch (dateRange) {
      case FilterDateRange.allTime:
        return 'All Time';
      case FilterDateRange.today:
        return 'Today';
      case FilterDateRange.tomorrow:
        return 'Tomorrow';
      case FilterDateRange.thisWeek:
        return 'This Week';
      case FilterDateRange.nextWeek:
        return 'Next Week';
      case FilterDateRange.thisMonth:
        return 'This Month';
      case FilterDateRange.customRange:
        return 'Custom Range';
    }
  }

  String get timeOfDayLabel {
    switch (timeOfDay) {
      case FilterTimeOfDay.anyTime:
        return 'Any Time';
      case FilterTimeOfDay.morning:
        return 'Morning';
      case FilterTimeOfDay.afternoon:
        return 'Afternoon';
      case FilterTimeOfDay.evening:
        return 'Evening';
      case FilterTimeOfDay.night:
        return 'Night';
      case FilterTimeOfDay.customTime:
        return 'Custom Time';
    }
  }

  // Apply filters to a list of reminders
  List<Reminder> applyFilters(List<Reminder> reminders) {
    var filtered = reminders.where((reminder) {
      // Status filter
      if (!_matchesStatus(reminder)) return false;

      // Space filter
      if (!_matchesSpace(reminder)) return false;

      // Date range filter
      if (!_matchesDateRange(reminder)) return false;

      // Time of day filter
      if (!_matchesTimeOfDay(reminder)) return false;

      // Search query filter
      if (!_matchesSearchQuery(reminder)) return false;

      return true;
    }).toList();

    // Apply sorting
    return _applySorting(filtered);
  }

  bool _matchesStatus(Reminder reminder) {
    final now = DateTime.now();
    switch (status) {
      case FilterStatus.all:
        return true;
      case FilterStatus.pending:
        return !reminder.isCompleted && reminder.scheduledTime.isAfter(now);
      case FilterStatus.completed:
        return reminder.isCompleted;
      case FilterStatus.overdue:
        return !reminder.isCompleted && reminder.scheduledTime.isBefore(now);
    }
  }

  bool _matchesSpace(Reminder reminder) {
    if (selectedSpaceId == null) return true;
    return reminder.spaceId == selectedSpaceId;
  }

  bool _matchesDateRange(Reminder reminder) {
    final now = DateTime.now();
    final reminderDate = reminder.scheduledTime;

    switch (dateRange) {
      case FilterDateRange.allTime:
        return true;
      case FilterDateRange.today:
        return _isSameDay(reminderDate, now);
      case FilterDateRange.tomorrow:
        final tomorrow = now.add(const Duration(days: 1));
        return _isSameDay(reminderDate, tomorrow);
      case FilterDateRange.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return reminderDate.isAfter(weekStart) &&
            reminderDate.isBefore(weekEnd.add(const Duration(days: 1)));
      case FilterDateRange.nextWeek:
        final nextWeekStart = now.add(Duration(days: 7 - now.weekday + 1));
        final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
        return reminderDate.isAfter(nextWeekStart) &&
            reminderDate.isBefore(nextWeekEnd.add(const Duration(days: 1)));
      case FilterDateRange.thisMonth:
        return reminderDate.year == now.year && reminderDate.month == now.month;
      case FilterDateRange.customRange:
        if (customStartDate == null || customEndDate == null) return true;
        return reminderDate.isAfter(customStartDate!) &&
            reminderDate.isBefore(customEndDate!.add(const Duration(days: 1)));
    }
  }

  bool _matchesTimeOfDay(Reminder reminder) {
    if (timeOfDay == FilterTimeOfDay.anyTime) return true;

    final hour = reminder.scheduledTime.hour;

    switch (timeOfDay) {
      case FilterTimeOfDay.anyTime:
        return true;
      case FilterTimeOfDay.morning:
        return hour >= 6 && hour < 12;
      case FilterTimeOfDay.afternoon:
        return hour >= 12 && hour < 18;
      case FilterTimeOfDay.evening:
        return hour >= 18 && hour < 22;
      case FilterTimeOfDay.night:
        return hour >= 22 || hour < 6;
      case FilterTimeOfDay.customTime:
        return true; // TODO: Implement custom time filtering
    }
  }

  bool _matchesSearchQuery(Reminder reminder) {
    if (searchQuery.isEmpty) return true;

    final query = searchQuery.toLowerCase();
    return reminder.title.toLowerCase().contains(query) ||
        (reminder.description?.toLowerCase().contains(query) ?? false);
  }

  List<Reminder> _applySorting(List<Reminder> reminders) {
    reminders.sort((a, b) {
      int comparison;

      switch (sortOption.type) {
        case SortType.dateCreated:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortType.alphabetical:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case SortType.scheduledTime:
          comparison = a.scheduledTime.compareTo(b.scheduledTime);
          break;
        case SortType.space:
          comparison = (a.spaceId ?? '').compareTo(b.spaceId ?? '');
          break;
        case SortType.status:
          // Sort by completion status, then by overdue status
          if (a.isCompleted != b.isCompleted) {
            comparison = a.isCompleted ? 1 : -1;
          } else {
            final now = DateTime.now();
            final aOverdue = !a.isCompleted && a.scheduledTime.isBefore(now);
            final bOverdue = !b.isCompleted && b.scheduledTime.isBefore(now);
            comparison = aOverdue == bOverdue ? 0 : (aOverdue ? -1 : 1);
          }
          break;
      }

      return sortOption.order == SortOrder.ascending ? comparison : -comparison;
    });

    return reminders;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  String toString() {
    return 'FilterState(status: $status, spaceId: $selectedSpaceId, '
        'dateRange: $dateRange, timeOfDay: $timeOfDay, sort: ${sortOption.label})';
  }
}
