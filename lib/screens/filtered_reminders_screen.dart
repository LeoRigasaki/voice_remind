import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'add_reminder_screen.dart';

enum FilterType { total, pending, completed, overdue }

class FilteredRemindersScreen extends StatefulWidget {
  final FilterType filterType;
  final List<Reminder> allReminders;

  const FilteredRemindersScreen({
    super.key,
    required this.filterType,
    required this.allReminders,
  });

  @override
  State<FilteredRemindersScreen> createState() =>
      _FilteredRemindersScreenState();
}

class _FilteredRemindersScreenState extends State<FilteredRemindersScreen>
    with TickerProviderStateMixin {
  List<Reminder> _filteredReminders = [];
  Timer? _realTimeTimer;
  late AnimationController _fadeController;
  StreamSubscription<List<Reminder>>? _remindersSubscription;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _applyFilter();
    _startRealTimeTimer();
    _listenToReminderChanges();

    // Start fade animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _realTimeTimer?.cancel();
    _remindersSubscription?.cancel();
    super.dispose();
  }

  void _startRealTimeTimer() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Force rebuild to update countdown timers
        });
      }
    });
  }

  void _listenToReminderChanges() {
    _remindersSubscription = StorageService.remindersStream.listen((reminders) {
      if (mounted) {
        setState(() {
          _filteredReminders = _filterReminders(reminders);
        });
      }
    });
  }

  void _applyFilter() {
    _filteredReminders = _filterReminders(widget.allReminders);
  }

  List<Reminder> _filterReminders(List<Reminder> reminders) {
    final now = DateTime.now();

    switch (widget.filterType) {
      case FilterType.total:
        return reminders;
      case FilterType.pending:
        return reminders
            .where((r) => !r.isCompleted && r.scheduledTime.isAfter(now))
            .toList();
      case FilterType.completed:
        return reminders.where((r) => r.isCompleted).toList();
      case FilterType.overdue:
        return reminders
            .where((r) => !r.isCompleted && r.scheduledTime.isBefore(now))
            .toList();
    }
  }

  String get _screenTitle {
    switch (widget.filterType) {
      case FilterType.total:
        return 'ALL REMINDERS';
      case FilterType.pending:
        return 'PENDING';
      case FilterType.completed:
        return 'COMPLETED';
      case FilterType.overdue:
        return 'OVERDUE';
    }
  }

  Color get _accentColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.filterType) {
      case FilterType.total:
        return isDark ? const Color(0xFF007AFF) : const Color(0xFF0066CC);
      case FilterType.pending:
        return isDark ? const Color(0xFF32D74B) : const Color(0xFF10B981);
      case FilterType.completed:
        return const Color(0xFF28A745); // Warmer green
      case FilterType.overdue:
        return const Color(0xFFDC3545); // Softer red
    }
  }

  IconData get _screenIcon {
    switch (widget.filterType) {
      case FilterType.total:
        return Icons.list_rounded;
      case FilterType.pending:
        return Icons.schedule_outlined;
      case FilterType.completed:
        return Icons.check_circle_outline;
      case FilterType.overdue:
        return Icons.error_outline;
    }
  }

  // Toggle reminder completion status
  Future<void> _toggleReminderStatus(Reminder reminder) async {
    try {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == ReminderStatus.completed
                  ? 'Reminder completed! 🎉'
                  : 'Reminder reopened',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating reminder: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddReminderScreen(reminder: reminder),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminder updated successfully!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      await StorageService.deleteReminder(reminder.id);
      await NotificationService.cancelReminder(reminder.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reminder deleted'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await StorageService.addReminder(reminder);
                  if (reminder.isNotificationEnabled &&
                      reminder.scheduledTime.isAfter(DateTime.now())) {
                    await NotificationService.scheduleReminder(reminder);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error restoring reminder: $e'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting reminder: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  // Progressive detail time formatting function
  String _formatTimeRemaining(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);

    if (difference.isNegative) {
      final overdueDuration = now.difference(reminderTime);
      if (overdueDuration.inDays > 0) {
        return 'Overdue ${overdueDuration.inDays}d';
      } else if (overdueDuration.inHours > 0) {
        return 'Overdue ${overdueDuration.inHours}h';
      } else {
        return 'Overdue ${overdueDuration.inMinutes}m';
      }
    }

    final totalMinutes = difference.inMinutes;
    final totalHours = difference.inHours;
    final totalDays = difference.inDays;

    // > 1 week: "Jan 15" (just date)
    if (totalDays > 7) {
      return DateFormat('MMM dd').format(reminderTime);
    }
    // 1-7 days: "3 days"
    else if (totalDays >= 1) {
      return '$totalDays day${totalDays == 1 ? '' : 's'}';
    }
    // 1-24 hours: "5h 30m"
    else if (totalHours >= 1) {
      final remainingMinutes = totalMinutes % 60;
      if (remainingMinutes == 0) {
        return '${totalHours}h';
      }
      return '${totalHours}h ${remainingMinutes}m';
    }
    // < 1 hour but >= 10 min: "25 min"
    else if (totalMinutes >= 10) {
      return '$totalMinutes min';
    }
    // < 10 min: "3 min 45s"
    else {
      final seconds = difference.inSeconds % 60;
      if (totalMinutes == 0) {
        return '${seconds}s';
      }
      return '$totalMinutes min ${seconds}s';
    }
  }

  // Calculate progress (0.0 to 1.0) for circular indicator
  double _calculateProgress(Reminder reminder) {
    final now = DateTime.now();
    final createdTime = reminder.createdAt;
    final scheduledTime = reminder.scheduledTime;

    // If reminder is completed, show full progress
    if (reminder.isCompleted) return 1.0;

    // Calculate total duration from creation to scheduled time
    final totalDuration = scheduledTime.difference(createdTime);

    // If total duration is 0 or negative, return 0
    if (totalDuration.inMilliseconds <= 0) return 0.0;

    // Calculate elapsed duration from creation to now
    final elapsedDuration = now.difference(createdTime);

    // Calculate progress
    final progress =
        elapsedDuration.inMilliseconds / totalDuration.inMilliseconds;

    // Clamp between 0.0 and 1.0
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Nothing Phone-inspired app bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: Container(
              margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                children: [
                  // Nothing-style accent indicator
                  Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _screenTitle,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.2,
                          fontSize: 20,
                        ),
                  ),
                ],
              ),
              expandedTitleScale: 1.0,
            ),
          ),

          // Count header with Nothing styling
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeController,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _accentColor.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _screenIcon,
                            size: 16,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _filteredReminders.length.toString(),
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_filteredReminders.isNotEmpty)
                      Text(
                        'TAP TO TOGGLE',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Reminders list or empty state
          _filteredReminders.isEmpty
              ? _buildEmptyState()
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return FadeTransition(
                        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _fadeController,
                            curve: Interval(
                              0.1 + (index * 0.1).clamp(0.0, 0.9),
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: _buildNothingReminderCard(
                            _filteredReminders[index], index),
                      );
                    },
                    childCount: _filteredReminders.length,
                  ),
                ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: FadeTransition(
        opacity: _fadeController,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Nothing-style geometric icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Corner accent
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      // Center icon
                      Center(
                        child: Icon(
                          _screenIcon,
                          size: 32,
                          color: _accentColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'NO $_screenTitle',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _accentColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getEmptyMessage(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (widget.filterType) {
      case FilterType.total:
        return 'You haven\'t created any reminders yet.\nTap ADD REMINDER to get started.';
      case FilterType.pending:
        return 'No pending reminders.\nYou\'re all caught up!';
      case FilterType.completed:
        return 'No completed reminders yet.\nComplete some to see them here.';
      case FilterType.overdue:
        return 'No overdue reminders.\nGreat job staying on track!';
    }
  }

  Widget _buildNothingReminderCard(Reminder reminder, int index) {
    final now = DateTime.now();
    final isOverdue =
        !reminder.isCompleted && reminder.scheduledTime.isBefore(now);

    // Warmer, softer colors - Nothing Phone inspired
    final statusColor = reminder.isCompleted
        ? const Color(0xFF28A745) // Warmer green instead of bright green
        : isOverdue
            ? const Color(0xFFDC3545) // Softer red instead of bright red
            : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF8E8E93)
                : const Color(0xFF6D6D70)); // Neutral gray

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Slidable(
        key: ValueKey(reminder.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.35,
          children: [
            // Edit Action
            Expanded(
              child: Container(
                margin:
                    const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _editReminder(reminder),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Delete Action
            Expanded(
              child: Container(
                margin:
                    const EdgeInsets.only(left: 2, right: 4, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _deleteReminder(reminder),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFDC3545).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFDC3545)
                                  .withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC3545),
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Delete',
                          style: TextStyle(
                            color: Color(0xFFDC3545),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
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
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _toggleReminderStatus(reminder),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Nothing-style status indicator
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusColor,
                              width: 1.5,
                            ),
                          ),
                          child: reminder.isCompleted
                              ? Icon(
                                  Icons.check,
                                  color: statusColor,
                                  size: 8,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // Title
                        Expanded(
                          child: Text(
                            reminder.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  decoration: reminder.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ),

                        // Time remaining with circular progress (like home screen)
                        if (!reminder.isCompleted) ...[
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Circular progress indicator
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CustomPaint(
                                  painter: CircularCountdownPainter(
                                    progress: _calculateProgress(reminder),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.2),
                                    progressColor: isOverdue
                                        ? const Color(
                                            0xFFDC3545) // Softer red for overdue
                                        : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors
                                                .black), // White for dark mode, black for light mode
                                    strokeWidth: 2.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Time display
                              Text(
                                _formatTimeRemaining(reminder.scheduledTime),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isOverdue
                                          ? const Color(
                                              0xFFDC3545) // Softer red for overdue
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(
                                                  alpha:
                                                      0.7), // Neutral for others
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Completed status badge with warmer green
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF28A745)
                                  .withValues(alpha: 0.1), // Warmer green
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF28A745)
                                    .withValues(alpha: 0.3), // Warmer green
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'DONE',
                              style: TextStyle(
                                color: Color(0xFF28A745), // Warmer green
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Description
                    if (reminder.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(
                        reminder.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 14,
                              height: 1.4,
                              letterSpacing: -0.1,
                            ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Bottom row
                    Row(
                      children: [
                        Text(
                          DateFormat('MMM dd • h:mm a')
                              .format(reminder.scheduledTime),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.2,
                                  ),
                        ),
                        const Spacer(),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for circular countdown progress indicator
class CircularCountdownPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  CircularCountdownPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate sweep angle (progress from 0 to 2π)
    final sweepAngle = 2 * math.pi * progress;

    // Draw arc starting from top (-π/2) and sweeping clockwise
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle, // Sweep angle
      false, // Don't use center
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is CircularCountdownPainter &&
        (oldDelegate.progress != progress ||
            oldDelegate.backgroundColor != backgroundColor ||
            oldDelegate.progressColor != progressColor ||
            oldDelegate.strokeWidth != strokeWidth);
  }
}
