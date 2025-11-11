import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/reminder.dart';
import '../models/custom_repeat_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/space_tag_widget.dart';
import '../widgets/time_slots_chip_widget.dart';

class ReminderDetailsBottomSheet extends StatefulWidget {
  final Reminder reminder;
  final List<Reminder> allReminders;
  final int currentIndex;
  final Function(Reminder)? onEdit;
  final Function(Reminder)? onDelete;
  final VoidCallback? onStatusToggle;

  const ReminderDetailsBottomSheet({
    super.key,
    required this.reminder,
    required this.allReminders,
    required this.currentIndex,
    this.onEdit,
    this.onDelete,
    this.onStatusToggle,
  });

  @override
  State<ReminderDetailsBottomSheet> createState() =>
      _ReminderDetailsBottomSheetState();
}

class _ReminderDetailsBottomSheetState extends State<ReminderDetailsBottomSheet>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _slideController;
  late AnimationController _fadeController;

  // Real-time updates
  Timer? _realTimeTimer;

  // Multi-time state
  String? _selectedTimeSlotId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize selected time slot for current reminder
    _initializeSelectedTimeSlot();

    // Start real-time timer for live updates
    _startRealTimeTimer();

    _slideController.forward();
    _fadeController.forward();
  }

  void _initializeSelectedTimeSlot() {
    final currentReminder = widget.allReminders[_currentIndex];
    if (currentReminder.hasMultipleTimes) {
      final nextSlot =
          currentReminder.nextPendingSlot ?? currentReminder.timeSlots.first;
      _selectedTimeSlotId = nextSlot.id;
    } else {
      _selectedTimeSlotId = null;
    }
  }

  void _startRealTimeTimer() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Force rebuild for real-time countdown updates
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _realTimeTimer?.cancel();
    super.dispose();
  }

  void _navigateToPrevious() {
    if (_currentIndex > 0) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex--;
        _initializeSelectedTimeSlot();
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToNext() {
    if (_currentIndex < widget.allReminders.length - 1) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex++;
        _initializeSelectedTimeSlot();
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTimeSlotSelected(String timeSlotId) {
    setState(() {
      _selectedTimeSlotId = timeSlotId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      )),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle and Header
            _buildHeader(),

            // Page View for Reminders
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentIndex = index;
                    _initializeSelectedTimeSlot();
                  });
                },
                itemCount: widget.allReminders.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeController,
                    child: _buildReminderDetails(widget.allReminders[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canGoPrevious = _currentIndex > 0;
    final canGoNext = _currentIndex < widget.allReminders.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Navigation Header
          Row(
            children: [
              // Previous Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canGoPrevious
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canGoPrevious
                        ? Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2)
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: canGoPrevious ? _navigateToPrevious : null,
                    child: Icon(
                      Icons.chevron_left,
                      color: canGoPrevious
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Title and Counter
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Reminder Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} of ${widget.allReminders.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),

              // Next Button
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canGoNext
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canGoNext
                        ? Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2)
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: canGoNext ? _navigateToNext : null,
                    child: Icon(
                      Icons.chevron_right,
                      color: canGoNext
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderDetails(Reminder reminder) {
    final now = DateTime.now();
    final isOverdue = reminder.hasMultipleTimes
        ? reminder.overallStatus == ReminderStatus.overdue
        : !reminder.isCompleted && reminder.scheduledTime.isBefore(now);

    final statusColor = reminder.hasMultipleTimes
        ? _getMultiTimeStatusColor(reminder)
        : (reminder.isCompleted
            ? const Color(0xFF28A745)
            : isOverdue
                ? const Color(0xFFDC3545)
                : Theme.of(context).colorScheme.primary);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          _buildStatusBadge(reminder, statusColor),

          const SizedBox(height: 20),

          // Title
          Text(
            reminder.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: reminder.hasMultipleTimes
                      ? (reminder.overallStatus == ReminderStatus.completed
                          ? TextDecoration.lineThrough
                          : null)
                      : (reminder.isCompleted
                          ? TextDecoration.lineThrough
                          : null),
                ),
          ),

          const SizedBox(height: 16),

          // Space Tag
          if (reminder.spaceId != null) ...[
            SpaceTagWidget(
              spaceId: reminder.spaceId!,
              fontSize: 13,
              horizontalPadding: 12,
              verticalPadding: 6,
            ),
            const SizedBox(height: 16),
          ],

          // Description (for single-time or overall description)
          if (reminder.description?.isNotEmpty == true) ...[
            _buildDetailSection(
              'Description',
              Icons.description_outlined,
              reminder.description!,
            ),
            const SizedBox(height: 20),
          ],

          // Multi-Time Section or Single Time Section
          if (reminder.hasMultipleTimes) ...[
            _buildMultiTimeSection(reminder),
            const SizedBox(height: 20),
          ] else ...[
            _buildSingleTimeSection(reminder),
            const SizedBox(height: 20),
          ],

          // Repeat Info
          if (reminder.repeatType != RepeatType.none) ...[
            _buildDetailSection(
              'Repeat',
              Icons.repeat,
              _getRepeatText(reminder.repeatType, reminder.customRepeatConfig),
            ),
            const SizedBox(height: 20),
          ],

          // Creation Date
          _buildDetailSection(
            'Created',
            Icons.add_circle_outline,
            DateFormat('MMM d, y • h:mm a').format(reminder.createdAt),
          ),

          const SizedBox(height: 32),

          // Action Buttons
          _buildActionButtons(reminder),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Reminder reminder, Color statusColor) {
    final statusText = reminder.hasMultipleTimes
        ? _getMultiTimeStatusText(reminder)
        : reminder.statusText;

    final statusIcon = reminder.hasMultipleTimes
        ? _getMultiTimeStatusIcon(reminder)
        : (reminder.isCompleted
            ? Icons.check_circle_outline
            : (reminder.isOverdue
                ? Icons.error_outline
                : Icons.schedule_outlined));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          if (reminder.hasMultipleTimes) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(reminder.progressPercentage * 100).round()}%',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiTimeSection(Reminder reminder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Interactive Chip Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Multiple Times',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${reminder.timeSlots.length} slots',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive chips
              TimeSlotsChipWidget(
                timeSlots: reminder.timeSlots,
                selectedTimeSlotId: _selectedTimeSlotId,
                onTimeSlotSelected: _onTimeSlotSelected,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Individual Time Slots List
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Time Slots',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time slots list
              for (int i = 0; i < reminder.timeSlots.length; i++)
                _buildTimeSlotRow(reminder, reminder.timeSlots[i],
                    i < reminder.timeSlots.length - 1),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress Summary
        _buildProgressSummary(reminder),
      ],
    );
  }

  Widget _buildTimeSlotRow(
      Reminder reminder, TimeSlot timeSlot, bool showDivider) {
    final isSelected = timeSlot.id == _selectedTimeSlotId;
    final slotColor = _getTimeSlotColor(reminder, timeSlot);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: slotColor,
                  shape: BoxShape.circle,
                ),
                child: timeSlot.isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 8,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Time and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeSlot.formattedTime,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                    ),
                    if (timeSlot.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        timeSlot.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status and action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _getTimeSlotStatusText(reminder, timeSlot),
                    style: TextStyle(
                      color: slotColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _toggleTimeSlotStatus(timeSlot),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: slotColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: slotColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        timeSlot.isCompleted ? Icons.refresh : Icons.check,
                        size: 12,
                        color: slotColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildProgressSummary(Reminder reminder) {
    final completedCount =
        reminder.timeSlots.where((slot) => slot.isCompleted).length;
    final totalCount = reminder.timeSlots.length;
    final progressPercentage = reminder.progressPercentage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Progress Summary',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          LinearProgressIndicator(
            value: progressPercentage,
            backgroundColor:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getMultiTimeStatusColor(reminder),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedCount of $totalCount completed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              Text(
                '${(progressPercentage * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getMultiTimeStatusColor(reminder),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTimeSection(Reminder reminder) {
    final now = DateTime.now();
    final isOverdue =
        !reminder.isCompleted && reminder.scheduledTime.isBefore(now);
    final statusColor = reminder.isCompleted
        ? const Color(0xFF28A745)
        : isOverdue
            ? const Color(0xFFDC3545)
            : Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Date & Time
        _buildDetailSection(
          'Scheduled Time',
          Icons.schedule_outlined,
          DateFormat('EEEE, MMMM d, y • h:mm a').format(reminder.scheduledTime),
        ),

        const SizedBox(height: 20),

        // Time Remaining/Overdue
        _buildDetailSection(
          reminder.isCompleted
              ? 'Completed'
              : isOverdue
                  ? 'Overdue'
                  : 'Time Remaining',
          reminder.isCompleted
              ? Icons.check_circle_outline
              : isOverdue
                  ? Icons.error_outline
                  : Icons.timer_outlined,
          reminder.isCompleted
              ? 'Task completed'
              : _formatTimeRemaining(reminder.scheduledTime),
          color: statusColor,
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, IconData icon, String content,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: color ??
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color ??
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Reminder reminder) {
    return Column(
      children: [
        // Primary Action Row
        Row(
          children: [
            // Toggle Status Button
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: reminder.hasMultipleTimes
                      ? (reminder.overallStatus == ReminderStatus.completed
                          ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                          : const Color(0xFF28A745).withValues(alpha: 0.1))
                      : (reminder.isCompleted
                          ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                          : const Color(0xFF28A745).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: reminder.hasMultipleTimes
                        ? (reminder.overallStatus == ReminderStatus.completed
                            ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                            : const Color(0xFF28A745).withValues(alpha: 0.3))
                        : (reminder.isCompleted
                            ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                            : const Color(0xFF28A745).withValues(alpha: 0.3)),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await _toggleReminderStatus(reminder);
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          reminder.hasMultipleTimes
                              ? (reminder.overallStatus ==
                                      ReminderStatus.completed
                                  ? Icons.refresh
                                  : Icons.check_circle_outline)
                              : (reminder.isCompleted
                                  ? Icons.refresh
                                  : Icons.check),
                          color: reminder.hasMultipleTimes
                              ? (reminder.overallStatus ==
                                      ReminderStatus.completed
                                  ? const Color(0xFF007AFF)
                                  : const Color(0xFF28A745))
                              : (reminder.isCompleted
                                  ? const Color(0xFF007AFF)
                                  : const Color(0xFF28A745)),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          reminder.hasMultipleTimes
                              ? (reminder.overallStatus ==
                                      ReminderStatus.completed
                                  ? 'REOPEN ALL'
                                  : 'COMPLETE ALL')
                              : (reminder.isCompleted ? 'REOPEN' : 'COMPLETE'),
                          style: TextStyle(
                            color: reminder.hasMultipleTimes
                                ? (reminder.overallStatus ==
                                        ReminderStatus.completed
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF28A745))
                                : (reminder.isCompleted
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF28A745)),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Edit Button
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEdit?.call(reminder);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EDIT',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Delete Button
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFDC3545).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFDC3545).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call(reminder);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC3545),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'DELETE',
                    style: TextStyle(
                      color: Color(0xFFDC3545),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Multi-time helper methods
  Color _getMultiTimeStatusColor(Reminder reminder) {
    switch (reminder.overallStatus) {
      case ReminderStatus.completed:
        return const Color(0xFF28A745);
      case ReminderStatus.overdue:
        return const Color(0xFFDC3545);
      case ReminderStatus.pending:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getMultiTimeStatusText(Reminder reminder) {
    switch (reminder.overallStatus) {
      case ReminderStatus.completed:
        return 'All Complete';
      case ReminderStatus.overdue:
        return 'Some Overdue';
      case ReminderStatus.pending:
        return 'In Progress';
    }
  }

  IconData _getMultiTimeStatusIcon(Reminder reminder) {
    switch (reminder.overallStatus) {
      case ReminderStatus.completed:
        return Icons.check_circle_outline;
      case ReminderStatus.overdue:
        return Icons.error_outline;
      case ReminderStatus.pending:
        return Icons.schedule_outlined;
    }
  }

  Color _getTimeSlotColor(Reminder reminder, TimeSlot timeSlot) {
    if (timeSlot.isCompleted) {
      return const Color(0xFF28A745);
    } else if (timeSlot.isOverdueFor(reminder.scheduledTime)) {
      return const Color(0xFFDC3545);
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

  String _getTimeSlotStatusText(Reminder reminder, TimeSlot timeSlot) {
    if (timeSlot.isCompleted) {
      return 'DONE';
    } else if (timeSlot.isOverdueFor(reminder.scheduledTime)) {
      return 'OVERDUE';
    } else {
      return 'PENDING';
    }
  }

  Future<void> _toggleTimeSlotStatus(TimeSlot timeSlot) async {
    HapticFeedback.lightImpact();

    try {
      final reminder = widget.allReminders[_currentIndex];
      final newStatus = timeSlot.isCompleted
          ? ReminderStatus.pending
          : ReminderStatus.completed;

      await StorageService.updateTimeSlotStatus(
        reminder.id,
        timeSlot.id,
        newStatus,
      );

      if (newStatus == ReminderStatus.completed) {
        await NotificationService.cancelTimeSlotNotification(
          reminder.id,
          timeSlot.id,
        );
      } else {
        // Reschedule notification for this slot
        final updatedReminder =
            await StorageService.getReminderById(reminder.id);
        if (updatedReminder != null) {
          await NotificationService.scheduleTimeSlotNotifications(
            updatedReminder,
            [timeSlot.copyWith(status: newStatus)],
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating time slot: $e');
    }
  }

  Future<void> _toggleReminderStatus(Reminder reminder) async {
    HapticFeedback.lightImpact();

    try {
      if (reminder.hasMultipleTimes) {
        // For multi-time reminders, toggle all pending slots
        final targetStatus = reminder.overallStatus == ReminderStatus.completed
            ? ReminderStatus.pending
            : ReminderStatus.completed;

        for (final timeSlot in reminder.timeSlots) {
          if (targetStatus == ReminderStatus.completed) {
            // Complete all pending slots
            if (timeSlot.status == ReminderStatus.pending) {
              await StorageService.updateTimeSlotStatus(
                reminder.id,
                timeSlot.id,
                ReminderStatus.completed,
              );
              await NotificationService.cancelTimeSlotNotification(
                reminder.id,
                timeSlot.id,
              );
            }
          } else {
            // Reopen all completed slots
            if (timeSlot.status == ReminderStatus.completed) {
              await StorageService.updateTimeSlotStatus(
                reminder.id,
                timeSlot.id,
                ReminderStatus.pending,
              );
            }
          }
        }

        // Reschedule notifications if reopening
        if (targetStatus == ReminderStatus.pending) {
          final updatedReminder =
              await StorageService.getReminderById(reminder.id);
          if (updatedReminder != null) {
            await NotificationService.scheduleReminder(updatedReminder);
          }
        }
      } else {
        // Single-time reminder logic
        final newStatus = reminder.isCompleted
            ? ReminderStatus.pending
            : ReminderStatus.completed;

        await StorageService.updateReminderStatus(reminder.id, newStatus);

        if (newStatus == ReminderStatus.completed) {
          await NotificationService.cancelReminder(reminder.id);
        } else if (reminder.scheduledTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleReminder(
            reminder.copyWith(status: newStatus),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating reminder: $e');
    }
  }

  String _formatTimeRemaining(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);

    if (difference.isNegative) {
      final overdueDuration = now.difference(reminderTime);
      if (overdueDuration.inDays > 0) {
        return '${overdueDuration.inDays} day${overdueDuration.inDays == 1 ? '' : 's'} overdue';
      } else if (overdueDuration.inHours > 0) {
        return '${overdueDuration.inHours} hour${overdueDuration.inHours == 1 ? '' : 's'} overdue';
      } else {
        return '${overdueDuration.inMinutes} minute${overdueDuration.inMinutes == 1 ? '' : 's'} overdue';
      }
    }

    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;

    if (totalDays > 7) {
      return 'In $totalDays days';
    } else if (totalDays >= 1) {
      return 'In $totalDays day${totalDays == 1 ? '' : 's'}';
    } else if (totalHours >= 1) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return 'In $totalHours hour${totalHours == 1 ? '' : 's'}';
      }
      return 'In ${totalHours}h ${remainingMinutes}m';
    } else if (totalMinutes >= 1) {
      return 'In $totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
    } else {
      return 'Any moment now';
    }
  }

  String _getRepeatText(RepeatType repeat, CustomRepeatConfig? customConfig) {
    switch (repeat) {
      case RepeatType.none:
        return 'No repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.custom:
        if (customConfig != null) {
          return customConfig.formatInterval();
        }
        return 'Custom';
    }
  }
}
