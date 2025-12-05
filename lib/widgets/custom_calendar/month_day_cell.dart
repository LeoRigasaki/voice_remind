// Month day cell - Individual day in calendar grid
import 'package:flutter/material.dart';
import '../../models/calendar_event.dart';

/// A single day cell in the month calendar grid
/// Shows date number, event dots, and handles interactions
class MonthDayCell extends StatefulWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final bool isToday;
  final bool isInCurrentMonth;
  final bool isSelected;
  final bool isDraggingOver;
  final VoidCallback onTap;
  final Function(CalendarEvent)? onEventDragStart;
  final VoidCallback? onEventDropped;

  const MonthDayCell({
    super.key,
    required this.date,
    required this.events,
    required this.isToday,
    required this.isInCurrentMonth,
    required this.isSelected,
    required this.isDraggingOver,
    required this.onTap,
    this.onEventDragStart,
    this.onEventDropped,
  });

  @override
  State<MonthDayCell> createState() => _MonthDayCellState();
}

class _MonthDayCellState extends State<MonthDayCell> {
  bool _isDragTarget = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<CalendarEvent>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragTarget = true);
        return true;
      },
      onLeave: (data) {
        setState(() => _isDragTarget = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _isDragTarget = false);
        widget.onEventDropped?.call();
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _getBackgroundColor(theme, isDark),
              borderRadius: BorderRadius.circular(8),
              border: _getBorder(theme, isDark),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 6),
                _buildDateNumber(theme),
                const SizedBox(height: 6),
                Expanded(
                  child: _buildEventDots(theme),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get background color based on state
  Color _getBackgroundColor(ThemeData theme, bool isDark) {
    if (_isDragTarget) {
      return theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1);
    }
    if (widget.isSelected) {
      return theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.15);
    }
    if (widget.isToday) {
      return theme.colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.05);
    }
    if (!widget.isInCurrentMonth) {
      return theme.colorScheme.surface.withValues(alpha: isDark ? 0.3 : 0.5);
    }
    return theme.colorScheme.surface;
  }

  /// Get border based on state
  Border _getBorder(ThemeData theme, bool isDark) {
    if (_isDragTarget) {
      return Border.all(
        color: theme.colorScheme.primary,
        width: 2,
      );
    }
    if (widget.isSelected) {
      return Border.all(
        color: theme.colorScheme.primary,
        width: 2,
      );
    }
    if (widget.isToday) {
      return Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
        width: 2,
      );
    }
    return Border.all(
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
      width: 1,
    );
  }

  /// Build date number
  Widget _buildDateNumber(ThemeData theme) {
    return Text(
      '${widget.date.day}',
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: widget.isToday ? FontWeight.w700 : FontWeight.w600,
        color: _getDateTextColor(theme),
        fontSize: widget.isToday ? 16 : 14,
      ),
    );
  }

  /// Get date text color
  Color _getDateTextColor(ThemeData theme) {
    if (widget.isToday) {
      return theme.colorScheme.primary;
    }
    if (!widget.isInCurrentMonth) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.4);
    }
    if (widget.isSelected) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.onSurface;
  }

  /// Build event dots (max 3 visible + count)
  Widget _buildEventDots(ThemeData theme) {
    if (widget.events.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort events: incomplete first, then by time
    final sortedEvents = List<CalendarEvent>.from(widget.events)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1; // Incomplete first
        }
        return a.startTime.compareTo(b.startTime);
      });

    const maxVisibleDots = 3;
    final visibleEvents = sortedEvents.take(maxVisibleDots).toList();
    final remainingCount = widget.events.length - maxVisibleDots;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Event dots
          ...visibleEvents.map((event) => _buildEventDot(event, theme)),

          // "+N more" text if needed
          if (remainingCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '+$remainingCount',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a single event dot (draggable)
  Widget _buildEventDot(CalendarEvent event, ThemeData theme) {
    final dot = Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: event.isCompleted
            ? event.color.withValues(alpha: 0.4)
            : event.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: event.color,
          width: 0.5,
        ),
      ),
    );

    // Make dot draggable
    return LongPressDraggable<CalendarEvent>(
      data: event,
      feedback: Material(
        elevation: 8,
        shape: const CircleBorder(),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: event.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: event.color.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: dot,
      ),
      onDragStarted: () {
        widget.onEventDragStart?.call(event);
      },
      child: dot,
    );
  }
}
