// lib/models/sort_option.dart

import 'package:flutter/material.dart';

enum SortType {
  dateCreated,
  alphabetical,
  scheduledTime,
  space,
  status,
}

enum SortOrder {
  ascending,
  descending,
}

class SortOption {
  final SortType type;
  final SortOrder order;
  final String label;
  final IconData icon;

  const SortOption({
    required this.type,
    required this.order,
    required this.label,
    required this.icon,
  });

  // Predefined sort options
  static const List<SortOption> defaultOptions = [
    SortOption(
      type: SortType.dateCreated,
      order: SortOrder.descending,
      label: 'Date Created (Newest)',
      icon: Icons.calendar_today_outlined,
    ),
    SortOption(
      type: SortType.dateCreated,
      order: SortOrder.ascending,
      label: 'Date Created (Oldest)',
      icon: Icons.calendar_today_outlined,
    ),
    SortOption(
      type: SortType.alphabetical,
      order: SortOrder.ascending,
      label: 'Alphabetical (A-Z)',
      icon: Icons.sort_by_alpha,
    ),
    SortOption(
      type: SortType.alphabetical,
      order: SortOrder.descending,
      label: 'Alphabetical (Z-A)',
      icon: Icons.sort_by_alpha,
    ),
    SortOption(
      type: SortType.scheduledTime,
      order: SortOrder.ascending,
      label: 'Scheduled Time (Soonest)',
      icon: Icons.access_time_outlined,
    ),
    SortOption(
      type: SortType.scheduledTime,
      order: SortOrder.descending,
      label: 'Scheduled Time (Latest)',
      icon: Icons.access_time_outlined,
    ),
    SortOption(
      type: SortType.space,
      order: SortOrder.ascending,
      label: 'Space (A-Z)',
      icon: Icons.folder_outlined,
    ),
    SortOption(
      type: SortType.status,
      order: SortOrder.ascending,
      label: 'Status (Pending First)',
      icon: Icons.check_circle_outline,
    ),
    SortOption(
      type: SortType.status,
      order: SortOrder.descending,
      label: 'Status (Completed First)',
      icon: Icons.check_circle_outline,
    ),
  ];

  // Get icon based on sort type (for dynamic filter icon)
  static IconData getIconForType(SortType type) {
    switch (type) {
      case SortType.dateCreated:
        return Icons.calendar_today_outlined;
      case SortType.alphabetical:
        return Icons.sort_by_alpha;
      case SortType.scheduledTime:
        return Icons.access_time_outlined;
      case SortType.space:
        return Icons.folder_outlined;
      case SortType.status:
        return Icons.check_circle_outline;
    }
  }

  // Get default sort option
  static SortOption get defaultSort => defaultOptions.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortOption &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          order == other.order;

  @override
  int get hashCode => type.hashCode ^ order.hashCode;

  @override
  String toString() => 'SortOption(type: $type, order: $order, label: $label)';
}
