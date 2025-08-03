// [lib/widgets]/event_details_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../models/reminder.dart';

/// Modern, redesigned event details bottom sheet with enhanced UI
class EventDetailsSheet extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleCompletion;

  const EventDetailsSheet({
    super.key,
    required this.event,
    this.onEdit,
    this.onDelete,
    this.onToggleCompletion,
  });

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _buildSheetContent(),
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildDetailsSection(),
          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced status indicator
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.event.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.event.color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              widget.event.isCompleted
                  ? Icons.check_circle_rounded
                  : widget.event.statusIcon,
              color: widget.event.statusColor,
              size: 24,
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Title and status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: widget.event.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                  color: widget.event.isCompleted
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              // Status badge
              _buildStatusBadge(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    Color badgeColor;
    String statusText;
    IconData statusIcon;

    switch (widget.event.status) {
      case ReminderStatus.completed:
        badgeColor = Colors.green;
        statusText = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      case ReminderStatus.overdue:
        badgeColor = Colors.red;
        statusText = 'Overdue';
        statusIcon = Icons.warning;
        break;
      case ReminderStatus.pending:
        badgeColor = Colors.blue;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 12,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description if available
        if (widget.event.description?.isNotEmpty == true) ...[
          _buildDescriptionCard(),
          const SizedBox(height: 16),
        ],

        // Time and date details
        _buildTimeCard(),

        // Additional details
        if (widget.event.spaceName != null ||
            widget.event.repeatType != RepeatType.none) ...[
          const SizedBox(height: 16),
          _buildAdditionalDetailsCard(),
        ],
      ],
    );
  }

  Widget _buildDescriptionCard() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.event.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.event.isAllDay ? Icons.today : Icons.schedule,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Time & Date',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date
          _buildDetailRow(
            Icons.calendar_today,
            DateFormat('EEEE, MMMM d, y').format(widget.event.startTime),
            theme,
          ),

          const SizedBox(height: 8),

          // Time
          _buildDetailRow(
            Icons.access_time,
            widget.event.isAllDay
                ? 'All day'
                : '${DateFormat.jm().format(widget.event.startTime)} (${widget.event.durationText})',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsCard() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Additional Details',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Space
          if (widget.event.spaceName != null) ...[
            _buildDetailRow(
              Icons.folder_outlined,
              widget.event.spaceName!,
              theme,
            ),
            if (widget.event.repeatType != RepeatType.none)
              const SizedBox(height: 8),
          ],

          // Repeat
          if (widget.event.repeatType != RepeatType.none)
            _buildDetailRow(
              Icons.repeat,
              _getRepeatText(),
              theme,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Primary actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onToggleCompletion,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  widget.event.isCompleted ? Icons.undo : Icons.check,
                ),
                label: Text(
                  widget.event.isCompleted
                      ? 'Mark Incomplete'
                      : 'Mark Complete',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.onEdit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Delete action
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: widget.onDelete,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Reminder'),
          ),
        ),
      ],
    );
  }

  String _getRepeatText() {
    switch (widget.event.repeatType) {
      case RepeatType.daily:
        return 'Repeats daily';
      case RepeatType.weekly:
        return 'Repeats weekly';
      case RepeatType.monthly:
        return 'Repeats monthly';
      case RepeatType.none:
        return 'No repeat';
    }
  }
}

/// Helper function to show the event details sheet
Future<void> showEventDetailsSheet({
  required BuildContext context,
  required CalendarEvent event,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onToggleCompletion,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    showDragHandle: false,
    builder: (context) => EventDetailsSheet(
      event: event,
      onEdit: onEdit,
      onDelete: onDelete,
      onToggleCompletion: onToggleCompletion,
    ),
  );
}
