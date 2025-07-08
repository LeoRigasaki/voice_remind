import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'add_reminder_screen.dart';
import 'settings_screen.dart';
import 'filtered_reminders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _fabAnimationController;
  late AnimationController _refreshAnimationController;
  Timer? _realTimeTimer;

  // Stream subscription for real-time updates
  late final Stream<List<Reminder>> _remindersStream;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Initialize stream
    _remindersStream = StorageService.remindersStream;

    // Load initial data
    StorageService.refreshData();

    // Start real-time timer for countdown updates
    _startRealTimeTimer();

    // Start FAB animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fabAnimationController.forward();
      }
    });
  }

// Navigate to settings screen
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _refreshAnimationController.dispose();
    _realTimeTimer?.cancel();
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

  Future<void> _refreshReminders() async {
    _refreshAnimationController.forward();
    try {
      await StorageService.refreshData();
      if (mounted) {
        setState(() => _error = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
    _refreshAnimationController.reset();
  }

  Future<void> _addReminder() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddReminderScreen(),
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
        const SnackBar(
          content: Text('Reminder created successfully!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating reminder: $e'),
            behavior: SnackBarBehavior.floating,
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
        const SnackBar(
          content: Text('Reminder updated successfully!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text(
          'Are you sure you want to delete "${reminder.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await StorageService.deleteReminder(reminder.id);
        await NotificationService.cancelReminder(reminder.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reminder deleted'),
              behavior: SnackBarBehavior.floating,
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
            ),
          );
        }
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

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'VoiceRemind',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w300,
                letterSpacing: -1.2,
              ),
        ),
        expandedTitleScale: 1.0,
      ),
      actions: [
        // Clean minimal icon buttons
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: IconButton(
            icon: RotationTransition(
              turns: _refreshAnimationController,
              child: Icon(
                Icons.refresh,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: _refreshReminders,
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _openSettings,
            tooltip: 'Settings',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.notification_add_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () async {
              await NotificationService.showImmediateNotification(
                title: 'Test Notification',
                body: 'If you see this, notifications are working! 🎉',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Test notification sent!'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            tooltip: 'Test Notification',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToFilteredReminders(FilterType filterType) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FilteredRemindersScreen(
          filterType: filterType,
          allReminders: _reminders,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Nothing Phone-inspired slide transition
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: FadeTransition(
              opacity: animation.drive(
                Tween(begin: 0.0, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeOut)),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildStatsCards(List<Reminder> reminders) {
    final total = reminders.length;
    final completed = reminders.where((r) => r.isCompleted).length;
    final pending = reminders.where((r) => r.isPending).length;
    final overdue = reminders.where((r) => r.isOverdue).length;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Expanded(
              child: _buildCleanStatCard(
                'TOTAL',
                total.toString(),
                FilterType.total,
                isHighlight: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCleanStatCard(
                'PENDING',
                pending.toString(),
                FilterType.pending,
                isHighlight: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCleanStatCard(
                'DONE',
                completed.toString(),
                FilterType.completed,
                isHighlight: false,
              ),
            ),
            if (overdue > 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildCleanStatCard(
                  'OVERDUE',
                  overdue.toString(),
                  FilterType.overdue,
                  isHighlight: true, // Only overdue gets red accent
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCleanStatCard(String title, String value, FilterType filterType,
      {required bool isHighlight}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFFFF3B30) // Nothing red for overdue
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5)),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _navigateToFilteredReminders(filterType),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with minimal styling - no arrow to avoid overflow
                Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6D6D70),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),

                // Value with emphasis
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isHighlight
                          ? const Color(0xFFFF3B30) // Red for overdue
                          : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersList(List<Reminder> reminders) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Nothing-style error icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Red accent corner
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      // Center icon
                      Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 32,
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ERROR LOADING',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFFF3B30),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        height: 1.4,
                        letterSpacing: 0.1,
                      ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _refreshReminders,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Text(
                          'RETRY',
                          style: TextStyle(
                            color: Color(0xFFFF3B30),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (reminders.isEmpty) {
      return SliverFillRemaining(
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Dot pattern
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Center icon
                      Center(
                        child: Icon(
                          Icons.voice_over_off_outlined,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'NO REMINDERS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap ADD REMINDER to create\nyour first voice reminder',
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
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final reminder = reminders[index];
          return _buildReminderCard(reminder);
        },
        childCount: reminders.length,
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final isOverdue = reminder.isOverdue;
    final statusColor = reminder.isCompleted
        ? Colors.green
        : isOverdue
            ? Colors.red
            : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Slidable(
        // Unique key for each reminder
        key: ValueKey(reminder.id),

        // The end action pane is the one at the right or the bottom side.
        endActionPane: ActionPane(
          // A motion is a widget used to control how the pane animates.
          motion: const BehindMotion(),
          extentRatio: 0.35, // Actions take 35% of the width

          // Clean Nothing-inspired design
          children: [
            // Edit Action
            Expanded(
              child: Container(
                margin:
                    const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A), // Nothing's signature dark
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
                  color: const Color(0xFF1A1A1A), // Nothing's signature dark
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
                            color: Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Delete',
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
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
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
                        // Clean status indicator
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

                        // Title with clean typography
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

                        // Real-time countdown and circular progress indicator
                        if (!reminder.isCompleted) ...[
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Circular progress indicator
                              SizedBox(
                                width: 32,
                                height: 32,
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
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Progressive time display
                              Text(
                                _formatTimeRemaining(reminder.scheduledTime),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isOverdue
                                          ? Colors.red
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Completed status badge
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Description with minimal styling
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

                    // Clean bottom row
                    Row(
                      children: [
                        // Minimal time display
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

                        // Minimal status text
                        Text(
                          reminder.statusText.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: statusColor.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshReminders,
        child: StreamBuilder<List<Reminder>>(
          stream: _remindersStream,
          initialData: _reminders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _error = snapshot.error.toString();
            } else if (snapshot.hasData) {
              _reminders = snapshot.data!;
              _error = null;
              _isLoading = false;
            }

            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                _buildStatsCards(_reminders),
                _buildRemindersList(_reminders),
                // Add bottom padding for FAB
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimationController.value,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _addReminder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 14,
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ADD REMINDER',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
