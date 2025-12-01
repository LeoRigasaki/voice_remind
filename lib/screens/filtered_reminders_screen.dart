import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'add_reminder_screen.dart';
import '../services/spaces_service.dart';
import '../widgets/reminder_card_widget.dart';
import '../widgets/ai_add_reminder_modal.dart';

enum FilterType { total, pending, completed, overdue, today, thisWeek, recent }

class FilteredRemindersScreen extends StatefulWidget {
  final FilterType filterType;
  final List<Reminder>? allReminders;
  final String? customTitle;
  final IconData? customIcon;
  final Color? customColor;
  final String? spaceId;

  const FilteredRemindersScreen({
    super.key,
    required this.filterType,
    this.allReminders,
    this.customTitle,
    this.customIcon,
    this.customColor,
    this.spaceId,
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
  String? _spaceId;

  // Selection mode for bulk actions
  bool _isSelectionMode = false;
  final Set<String> _selectedReminders = {};
  late AnimationController _selectionAnimationController;

  @override
  void initState() {
    super.initState();
    _spaceId = widget.spaceId;

    if (widget.customTitle != null && widget.allReminders?.isNotEmpty == true) {
      _spaceId = widget.allReminders!.first.spaceId;
    }
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _selectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _selectionAnimationController.dispose();
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
    _remindersSubscription =
        StorageService.remindersStream.listen((allReminders) async {
      if (mounted) {
        List<Reminder> remindersToFilter;

        if (_spaceId != null) {
          remindersToFilter =
              await StorageService.getRemindersBySpace(_spaceId!);
        } else if (widget.allReminders != null) {
          remindersToFilter = widget.allReminders!;
        } else {
          // For time-based filters, use all reminders
          remindersToFilter = allReminders;
        }

        setState(() {
          _filteredReminders = _filterReminders(remindersToFilter);
        });
      }
    });
  }

  void _applyFilter() async {
    List<Reminder> remindersToFilter;

    if (_spaceId != null) {
      remindersToFilter = await StorageService.getRemindersBySpace(_spaceId!);
    } else if (widget.allReminders != null) {
      remindersToFilter = widget.allReminders!;
    } else {
      // For time-based filters, get all reminders
      remindersToFilter = await StorageService.getReminders();
    }

    if (mounted) {
      setState(() {
        _filteredReminders = _filterReminders(remindersToFilter);
      });
    }
  }

  List<Reminder> _filterReminders(List<Reminder> reminders) {
    final now = DateTime.now();

    switch (widget.filterType) {
      case FilterType.total:
        return reminders;
      case FilterType.pending:
        return reminders
            .where((r) {
              final timeToCheck = r.snoozedUntil ?? r.scheduledTime;
              return !r.isCompleted && timeToCheck.isAfter(now);
            })
            .toList();
      case FilterType.completed:
        return reminders.where((r) => r.isCompleted).toList();
      case FilterType.overdue:
        return reminders
            .where((r) {
              final timeToCheck = r.snoozedUntil ?? r.scheduledTime;
              return !r.isCompleted && timeToCheck.isBefore(now);
            })
            .toList();
      case FilterType.today:
        return reminders.where((r) {
          return r.scheduledTime.year == now.year &&
              r.scheduledTime.month == now.month &&
              r.scheduledTime.day == now.day;
        }).toList();
      case FilterType.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return reminders.where((r) {
          return r.scheduledTime.isAfter(weekStart) &&
              r.scheduledTime.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
      case FilterType.recent:
        return reminders.where((r) => r.isCompleted).take(10).toList();
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
      case FilterType.today:
        return 'TODAY';
      case FilterType.thisWeek:
        return 'THIS WEEK';
      case FilterType.recent:
        return 'RECENT';
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
        return const Color(0xFF28A745);
      case FilterType.overdue:
        return const Color(0xFFDC3545);
      case FilterType.today:
        return isDark ? const Color(0xFFFF9500) : const Color(0xFFFF8C00);
      case FilterType.thisWeek:
        return isDark ? const Color(0xFF5856D6) : const Color(0xFF5856D6);
      case FilterType.recent:
        return isDark ? const Color(0xFF34C759) : const Color(0xFF30D158);
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
      case FilterType.today:
        return Icons.today_outlined;
      case FilterType.thisWeek:
        return Icons.date_range_outlined;
      case FilterType.recent:
        return Icons.history_outlined;
    }
  }

  // Enhanced selection mode functions with haptic feedback
  void _enterSelectionMode(String reminderId) {
    HapticFeedback.mediumImpact(); // Stronger feedback for selection mode
    setState(() {
      _isSelectionMode = true;
      _selectedReminders.add(reminderId);
    });
    _selectionAnimationController.forward();
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedReminders.clear();
    });
    _selectionAnimationController.reverse();
  }

  void _toggleSelection(String reminderId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedReminders.contains(reminderId)) {
        _selectedReminders.remove(reminderId);
        if (_selectedReminders.isEmpty) {
          _exitSelectionMode();
        }
      } else {
        _selectedReminders.add(reminderId);
      }
    });
  }

  // Select All / Deselect All functionality
  void _selectAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedReminders.addAll(_filteredReminders.map((r) => r.id));
    });
  }

  void _deselectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedReminders.clear();
    });
  }

  bool get _isAllSelected {
    return _filteredReminders.isNotEmpty &&
        _selectedReminders.length == _filteredReminders.length;
  }

  bool get _isPartiallySelected {
    return _selectedReminders.isNotEmpty && !_isAllSelected;
  }

  // Bulk actions
  Future<void> _bulkComplete() async {
    try {
      for (final id in _selectedReminders) {
        final reminder = _filteredReminders.firstWhere((r) => r.id == id);
        if (!reminder.isCompleted) {
          await StorageService.updateReminderStatus(
              id, ReminderStatus.completed);
          await NotificationService.cancelReminder(id);
        }
      }
      _exitSelectionMode();
    } catch (e) {
      debugPrint('Error completing reminders: $e');
    }
  }

  Future<void> _bulkUncomplete() async {
    try {
      for (final id in _selectedReminders) {
        final reminder = _filteredReminders.firstWhere((r) => r.id == id);
        if (reminder.isCompleted) {
          await StorageService.updateReminderStatus(id, ReminderStatus.pending);
          if (reminder.scheduledTime.isAfter(DateTime.now())) {
            await NotificationService.scheduleReminder(
              reminder.copyWith(
                status: ReminderStatus.pending,
                clearSnooze: true, // Clear snooze when uncompleting
              ),
            );
          }
        }
      }
      _exitSelectionMode();
    } catch (e) {
      debugPrint('Error reopening reminders: $e');
    }
  }

  Future<void> _bulkDelete() async {
    try {
      for (final id in _selectedReminders) {
        await StorageService.deleteReminder(id);
        await NotificationService.cancelReminder(id);
      }
      _exitSelectionMode();
    } catch (e) {
      debugPrint('Error deleting reminders: $e');
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
      // Reminder updated successfully - silent success
    }
  }

  // Direct delete without confirmation - toast removed
  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      await StorageService.deleteReminder(reminder.id);
      await NotificationService.cancelReminder(reminder.id);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  Widget _buildSpaceFAB() {
    final backgroundColor =
        widget.customColor ?? Theme.of(context).colorScheme.primary;
    final foregroundColor = backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return FloatingActionButton.extended(
      onPressed: () => _navigateToAddReminderInSpace(),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      label: const Text('Add Reminder'),
      icon: const Icon(Icons.add),
    );
  }

  Future<void> _navigateToAddReminderInSpace() async {
    if (_spaceId == null) return;

    // Get the space object
    final space = await SpacesService.getSpaceById(_spaceId!);
    if (space == null || !mounted) return;

    // Open AI modal with pre-selected space
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AIAddReminderModal(
          preSelectedSpace: space,
        );
      },
    );

    if (mounted) {
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _spaceId != null ? _buildSpaceFAB() : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: _isSelectionMode ? 140 : 120,
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: widget.customColor?.withValues(alpha: 0.1) ??
                Theme.of(context).scaffoldBackgroundColor,
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
                  _isSelectionMode ? Icons.close : Icons.arrow_back,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _isSelectionMode
                    ? _exitSelectionMode
                    : () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            actions: _isSelectionMode
                ? [
                    // Select All button - responsive (ADD THIS FIRST)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isAllSelected
                              ? Icons.deselect
                              : (_isPartiallySelected
                                  ? Icons.checklist
                                  : Icons.select_all),
                          size: 20,
                        ),
                        onPressed: _isAllSelected
                            ? _deselectAll
                            : _selectAll, // Fixed the typos here
                        tooltip: _isAllSelected ? 'Deselect All' : 'Select All',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF007AFF),
                        ),
                      ),
                    ),

                    // Your existing Complete Selected button
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF28A745).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        onPressed: _bulkComplete,
                        tooltip: 'Complete Selected',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF28A745),
                        ),
                      ),
                    ),

                    // Your existing Reopen Selected button
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _bulkUncomplete,
                        tooltip: 'Reopen Selected',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF007AFF),
                        ),
                      ),
                    ),

                    // Your existing Delete Selected button
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFDC3545).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: _bulkDelete,
                        tooltip: 'Delete Selected',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFFDC3545),
                        ),
                      ),
                    ),
                  ]
                : [],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: _isSelectionMode
                  ? Row(
                      children: [
                        Text(
                          '${_selectedReminders.length} selected',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.8,
                                color: const Color(0xFFFF453A), // Nothing red
                                fontSize: 18,
                              ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Custom title with accent indicator
                        Container(
                          width: 3,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.customColor ?? _accentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.customTitle ?? _screenTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
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
          if (!_isSelectionMode)
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
                          color: (widget.customColor ?? _accentColor)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (widget.customColor ?? _accentColor)
                                .withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.customIcon ?? _screenIcon,
                              size: 16,
                              color: widget.customColor ?? _accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _filteredReminders.length.toString(),
                              style: TextStyle(
                                color: widget.customColor ?? _accentColor,
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
                          'LONG PRESS TO SELECT',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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
      case FilterType.today:
        return 'No reminders scheduled for today.\nEnjoy your free time!';
      case FilterType.thisWeek:
        return 'No reminders scheduled for this week.\nYou\'re ahead of schedule!';
      case FilterType.recent:
        return 'No recently completed reminders.\nComplete some to see them here.';
    }
  }

  Widget _buildNothingReminderCard(Reminder reminder, int index) {
    return ReminderCardWidget(
      reminder: reminder,
      searchQuery: '',
      isSelectionMode: _isSelectionMode,
      isSelected: _selectedReminders.contains(reminder.id),
      allReminders: _filteredReminders,
      currentIndex: index,
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(reminder.id);
        }
      },
      onSelectionToggle: () => _toggleSelection(reminder.id),
      onEdit: _editReminder,
      onDelete: _deleteReminder,
      // Note: No onAddToSpace for filtered screen as it doesn't have space selector
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
