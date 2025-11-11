import 'package:intl/intl.dart';

/// Configuration for custom repeat intervals
/// Allows flexible scheduling with days, hours, and minutes
class CustomRepeatConfig {
  final int minutes; // 0-59
  final int hours; // 0-23
  final int days; // 0-365
  final Set<int>? specificDays; // 1=Mon, 2=Tue, ..., 7=Sun (null = all days)
  final DateTime? endDate; // Optional end date for the repeat

  const CustomRepeatConfig({
    this.minutes = 0,
    this.hours = 0,
    this.days = 0,
    this.specificDays,
    this.endDate,
  });

  /// Total interval in minutes
  int get totalMinutes => (days * 24 * 60) + (hours * 60) + minutes;

  /// Returns normalized config (handles overflow)
  /// Example: 90 minutes -> 1 hour 30 minutes
  CustomRepeatConfig get normalized {
    int totalMins = totalMinutes;
    int d = totalMins ~/ (24 * 60);
    int h = (totalMins % (24 * 60)) ~/ 60;
    int m = totalMins % 60;

    return CustomRepeatConfig(
      minutes: m,
      hours: h,
      days: d,
      specificDays: specificDays,
      endDate: endDate,
    );
  }

  /// Validates the configuration
  bool get isValid {
    // Minimum 5 minutes
    if (totalMinutes < 5) return false;

    // Maximum 365 days
    if (totalMinutes > (365 * 24 * 60)) return false;

    // Check leap day for end date
    if (endDate != null) {
      if (endDate!.month == 2 && endDate!.day == 29) {
        // Check if it's a leap year
        final year = endDate!.year;
        final isLeapYear =
            (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        if (!isLeapYear) return false;
      }
    }

    // Validate specific days (1-7)
    if (specificDays != null) {
      for (var day in specificDays!) {
        if (day < 1 || day > 7) return false;
      }
    }

    return true;
  }

  /// Get validation error message
  String? get validationError {
    if (totalMinutes < 5) {
      return 'Minimum interval is 5 minutes';
    }
    if (totalMinutes > (365 * 24 * 60)) {
      return 'Maximum interval is 365 days';
    }
    if (endDate != null) {
      if (endDate!.month == 2 && endDate!.day == 29) {
        final year = endDate!.year;
        final isLeapYear =
            (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        if (!isLeapYear) {
          return 'Feb 29 only exists in leap years';
        }
      }
    }
    return null;
  }

  /// Check if this config matches an existing repeat type
  /// Returns the repeat type name if it matches, null otherwise
  String? matchesExistingRepeatType() {
    if (specificDays != null) return null; // Custom day selection = no match

    if (days == 1 && hours == 0 && minutes == 0) {
      return 'Daily';
    }
    if (days == 7 && hours == 0 && minutes == 0) {
      return 'Weekly';
    }
    // Note: Monthly is approximate, so we don't match it
    return null;
  }

  /// Format the interval as a human-readable string
  String formatInterval() {
    final normalized = this.normalized;
    List<String> parts = [];

    if (normalized.days > 0) {
      parts.add('${normalized.days} day${normalized.days > 1 ? 's' : ''}');
    }
    if (normalized.hours > 0) {
      parts.add('${normalized.hours} hour${normalized.hours > 1 ? 's' : ''}');
    }
    if (normalized.minutes > 0) {
      parts.add(
          '${normalized.minutes} minute${normalized.minutes > 1 ? 's' : ''}');
    }

    if (parts.isEmpty) return '0 minutes';
    return parts.join(' and ');
  }

  /// Format specific days as a readable string
  String formatSpecificDays() {
    if (specificDays == null || specificDays!.isEmpty) {
      return 'every day';
    }

    final sortedDays = specificDays!.toList()..sort();

    // Check for common patterns
    if (sortedDays.length == 7) {
      return 'every day';
    }
    if (sortedDays.toString() == '[1, 2, 3, 4, 5]') {
      return 'Mon - Fri';
    }
    if (sortedDays.toString() == '[6, 7]') {
      return 'Sat - Sun';
    }

    // Check for consecutive days
    if (_isConsecutive(sortedDays)) {
      return '${_dayName(sortedDays.first)} - ${_dayName(sortedDays.last)}';
    }

    // List individual days
    return sortedDays.map((d) => _dayName(d)).join(', ');
  }

  /// Check if days are consecutive
  bool _isConsecutive(List<int> days) {
    if (days.length < 2) return false;
    for (int i = 0; i < days.length - 1; i++) {
      if (days[i + 1] - days[i] != 1) return false;
    }
    return true;
  }

  /// Get day name abbreviation
  String _dayName(int day) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[day - 1];
  }

  /// Get full summary string
  String getSummary() {
    String interval = formatInterval();
    String dayPart = specificDays != null ? ' on ${formatSpecificDays()}' : '';
    String endPart = endDate != null
        ? ' until ${DateFormat('MMM d, y').format(endDate!)}'
        : '';

    return 'Will repeat every $interval$dayPart$endPart';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'minutes': minutes,
      'hours': hours,
      'days': days,
      'specificDays': specificDays?.toList(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory CustomRepeatConfig.fromJson(Map<String, dynamic> json) {
    return CustomRepeatConfig(
      minutes: json['minutes'] ?? 0,
      hours: json['hours'] ?? 0,
      days: json['days'] ?? 0,
      specificDays: json['specificDays'] != null
          ? Set<int>.from(json['specificDays'])
          : null,
      endDate:
          json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }

  /// Create a copy with updated fields
  CustomRepeatConfig copyWith({
    int? minutes,
    int? hours,
    int? days,
    Set<int>? specificDays,
    DateTime? endDate,
    bool clearSpecificDays = false,
    bool clearEndDate = false,
  }) {
    return CustomRepeatConfig(
      minutes: minutes ?? this.minutes,
      hours: hours ?? this.hours,
      days: days ?? this.days,
      specificDays: clearSpecificDays
          ? null
          : (specificDays ?? this.specificDays),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  @override
  String toString() => getSummary();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomRepeatConfig &&
          runtimeType == other.runtimeType &&
          minutes == other.minutes &&
          hours == other.hours &&
          days == other.days &&
          _setEquals(specificDays, other.specificDays) &&
          endDate == other.endDate;

  bool _setEquals(Set<int>? a, Set<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  int get hashCode =>
      minutes.hashCode ^
      hours.hashCode ^
      days.hashCode ^
      specificDays.hashCode ^
      endDate.hashCode;
}
