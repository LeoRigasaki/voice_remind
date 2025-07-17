import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/space.dart';
import '../services/spaces_service.dart';

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

  // Selection mode for bulk actions
  bool _isSelectionMode = false;
  final Set<String> _selectedReminders = {};
  late AnimationController _selectionAnimationController;

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
    _selectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _selectionAnimationController.dispose();
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

  // Enhanced toggle for circular progress area with haptic feedback
  Future<void> _toggleReminderStatus(Reminder reminder) async {
    // Add haptic feedback
    HapticFeedback.lightImpact();

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
    } catch (e) {
      debugPrint('Error updating reminder: $e');
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

  // Bulk actions
  Future<void> _bulkComplete() async {
    try {
      for (final id in _selectedReminders) {
        final reminder = _reminders.firstWhere((r) => r.id == id);
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
        final reminder = _reminders.firstWhere((r) => r.id == id);
        if (reminder.isCompleted) {
          await StorageService.updateReminderStatus(id, ReminderStatus.pending);
          if (reminder.scheduledTime.isAfter(DateTime.now())) {
            await NotificationService.scheduleReminder(
              reminder.copyWith(status: ReminderStatus.pending),
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

  // Show space selector bottom sheet
  void _showSpaceSelector(List<String> reminderIds) async {
    final spaces = await SpacesService.getSpaces();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Add to Space',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${reminderIds.length} reminder${reminderIds.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Create new space option
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF28A745).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF28A745),
                    size: 20,
                  ),
                ),
                title: const Text('Create New Space'),
                subtitle: const Text('Quick create and assign'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showQuickSpaceCreation(reminderIds);
                },
              ),

              if (spaces.isNotEmpty) ...[
                const Divider(),
                // Existing spaces
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: spaces.length,
                    itemBuilder: (context, index) {
                      final space = spaces[index];
                      final textColor = space.color.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: space.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            space.icon,
                            color: textColor,
                            size: 20,
                          ),
                        ),
                        title: Text(space.name),
                        subtitle: FutureBuilder<int>(
                          future:
                              StorageService.getSpaceReminderCount(space.id),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Text(
                                '$count reminder${count == 1 ? '' : 's'}');
                          },
                        ), // TODO: Get actual count
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _assignRemindersToSpace(reminderIds, space.id);
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

// Quick space creation dialog
  void _showQuickSpaceCreation(List<String> reminderIds) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Space'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Space name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                await _createSpaceAndAssign(
                    reminderIds, controller.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

// Create new space and assign reminders
  Future<void> _createSpaceAndAssign(
      List<String> reminderIds, String spaceName) async {
    try {
      final spaces = await SpacesService.getSpaces();
      const availableColors = SpaceColors.presetColors;
      const availableIcons = SpaceIcons.presetIcons;

      // Use next available color and icon
      final colorIndex = spaces.length % availableColors.length;
      final iconIndex = spaces.length % availableIcons.length;

      final newSpace = Space(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: spaceName,
        color: availableColors[colorIndex],
        icon: availableIcons[iconIndex],
        createdAt: DateTime.now(),
      );

      await SpacesService.addSpace(newSpace);
      await _assignRemindersToSpace(reminderIds, newSpace.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Created "$spaceName" and assigned ${reminderIds.length} reminder${reminderIds.length == 1 ? '' : 's'}'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View Space',
              onPressed: () => _navigateToNewSpace(newSpace),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating space: $e');
    }
  }

  void _navigateToNewSpace(Space space) async {
    final spaceReminders = await StorageService.getRemindersBySpace(space.id);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FilteredRemindersScreen(
            filterType: FilterType.total,
            allReminders: spaceReminders,
            customTitle: space.name,
            customIcon: space.icon,
            customColor: space.color,
          ),
        ),
      );
    }
  }

// Assign reminders to space
  Future<void> _assignRemindersToSpace(
      List<String> reminderIds, String spaceId) async {
    try {
      for (final reminderId in reminderIds) {
        final reminder = await StorageService.getReminderById(reminderId);
        if (reminder != null) {
          final updatedReminder = reminder.copyWith(spaceId: spaceId);
          await StorageService.updateReminder(updatedReminder);
        }
      }

      if (_isSelectionMode) {
        _exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Error assigning reminders: $e');
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

  // Direct delete without confirmation
  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      await StorageService.deleteReminder(reminder.id);
      await NotificationService.cancelReminder(reminder.id);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
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
      expandedHeight: _isSelectionMode ? 140 : 120,
      floating: true,
      snap: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: _isSelectionMode
            ? Row(
                children: [
                  Text(
                    '${_selectedReminders.length} selected',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.8,
                          color: const Color(0xFFFF453A), // Nothing red
                        ),
                  ),
                ],
              )
            : Text(
                'VoiceRemind',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.2,
                    ),
              ),
        expandedTitleScale: 1.0,
      ),
      actions: _isSelectionMode
          ? [
              // Bulk action buttons
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
              Container(
                margin: const EdgeInsets.only(right: 4),
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
                  icon: const Icon(Icons.folder_outlined, size: 20),
                  onPressed: () =>
                      _showSpaceSelector(_selectedReminders.toList()),
                  tooltip: 'Add to Space',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF007AFF),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
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
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _exitSelectionMode,
                  tooltip: 'Cancel',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ]
          : [
              // Regular action buttons
              Container(
                margin: const EdgeInsets.only(right: 4),
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
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
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
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
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
                    // Test notification sent - no toast shown
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

    // Calculate number of cards to determine responsiveness
    final cardCount = overdue > 0 ? 4 : 3;
    final screenWidth = MediaQuery.of(context).size.width;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            _buildResponsiveStatCard(
              'TOTAL',
              total.toString(),
              FilterType.total,
              cardCount,
              screenWidth,
              isHighlight: false,
            ),
            const SizedBox(width: 12),
            _buildResponsiveStatCard(
              'PENDING',
              pending.toString(),
              FilterType.pending,
              cardCount,
              screenWidth,
              isHighlight: false,
            ),
            const SizedBox(width: 12),
            _buildResponsiveStatCard(
              'DONE',
              completed.toString(),
              FilterType.completed,
              cardCount,
              screenWidth,
              isHighlight: false,
            ),
            if (overdue > 0) ...[
              const SizedBox(width: 12),
              _buildResponsiveStatCard(
                'OVERDUE',
                overdue.toString(),
                FilterType.overdue,
                cardCount,
                screenWidth,
                isHighlight: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveStatCard(String title, String value,
      FilterType filterType, int cardCount, double screenWidth,
      {required bool isHighlight}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Responsive calculations
    final availableWidth = screenWidth - 32; // 16px padding on each side
    final spacingWidth = (cardCount - 1) * 12; // 12px spacing between cards
    final cardWidth = (availableWidth - spacingWidth) / cardCount;

    // Auto-scale based on card width and content
    final responsivePadding = _getResponsivePadding(cardWidth);
    final titleFontSize = _getResponsiveTitleFontSize(cardWidth, title.length);
    final valueFontSize = _getResponsiveValueFontSize(cardWidth);
    final cardHeight = _getResponsiveCardHeight(screenWidth);

    return Expanded(
      child: Container(
        height: cardHeight,
        constraints: const BoxConstraints(
          minWidth: 60, // Prevent cards from becoming too narrow
          maxWidth: double.infinity,
        ),
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
              padding: EdgeInsets.symmetric(
                horizontal: responsivePadding,
                vertical: 8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Auto-scaling title
                  SizedBox(
                    height: 16,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF6D6D70),
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ),

                  // Auto-scaling value
                  SizedBox(
                    height: cardHeight -
                        40, // Remaining space for value (minus padding and title)
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: isHighlight
                                ? const Color(0xFFFF3B30) // Red for overdue
                                : (isDark ? Colors.white : Colors.black),
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Responsive helper methods for auto-scaling
  double _getResponsivePadding(double cardWidth) {
    if (cardWidth < 70) return 6.0; // Very narrow cards
    if (cardWidth < 90) return 8.0; // Narrow cards
    if (cardWidth < 120) return 10.0; // Normal cards
    return 12.0; // Wide cards
  }

  double _getResponsiveTitleFontSize(double cardWidth, int textLength) {
    // Factor in both card width and text length
    final baseSize = cardWidth < 70
        ? 8.0
        : cardWidth < 90
            ? 9.0
            : cardWidth < 120
                ? 10.0
                : 11.0;

    // Adjust for longer text
    if (textLength > 6) {
      // "PENDING", "OVERDUE"
      return baseSize - 1.0;
    }
    return baseSize;
  }

  double _getResponsiveValueFontSize(double cardWidth) {
    if (cardWidth < 70) return 18.0; // Very narrow cards
    if (cardWidth < 90) return 20.0; // Narrow cards
    if (cardWidth < 120) return 22.0; // Normal cards
    return 24.0; // Wide cards
  }

  double _getResponsiveCardHeight(double screenWidth) {
    if (screenWidth < 320) return 65.0; // Very small screens
    if (screenWidth < 400) return 68.0; // Small screens
    return 70.0; // Normal screens
  }

  // Enhanced small filter buttons after stats
  Widget _buildQuickFilters() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            _buildSmallFilterButton('Today', Icons.today_outlined, () {
              // Filter today's reminders
              final today = DateTime.now();
              final todayReminders = _reminders.where((r) {
                return r.scheduledTime.year == today.year &&
                    r.scheduledTime.month == today.month &&
                    r.scheduledTime.day == today.day;
              }).toList();

              _showFilteredResults('Today', todayReminders);
            }),
            const SizedBox(width: 8),
            _buildSmallFilterButton('This Week', Icons.date_range_outlined, () {
              // Filter this week's reminders
              final now = DateTime.now();
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              final weekEnd = weekStart.add(const Duration(days: 6));

              final weekReminders = _reminders.where((r) {
                return r.scheduledTime.isAfter(weekStart) &&
                    r.scheduledTime
                        .isBefore(weekEnd.add(const Duration(days: 1)));
              }).toList();

              _showFilteredResults('This Week', weekReminders);
            }),
            const SizedBox(width: 8),
            _buildSmallFilterButton('Recent', Icons.history_outlined, () {
              // Show recently completed
              final recentCompleted =
                  _reminders.where((r) => r.isCompleted).take(10).toList();

              _showFilteredResults('Recently Completed', recentCompleted);
            }),
            const SizedBox(width: 8),
            // Advanced filter button for future features
            _buildAdvancedFilterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallFilterButton(
      String label, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6D6D70),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF6D6D70),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Advanced filter button for future features
  // Advanced filter button for future features
  Widget _buildAdvancedFilterButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _showAdvancedFilters, // Changed from showing snackbar
          child: Icon(
            Icons.tune_outlined,
            size: 16,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
      ),
    );
  }

// Add this new method for advanced filters
  void _showAdvancedFilters() async {
    final spaces = await SpacesService.getSpaces();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Filter Reminders',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // All reminders option
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.apps,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text('All Reminders'),
                subtitle: Text('${_reminders.length} reminders'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showFilteredResults('All Reminders', _reminders);
                },
              ),

              if (spaces.isNotEmpty) ...[
                const Divider(),

                // Space filters
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: spaces.length,
                    itemBuilder: (context, index) {
                      final space = spaces[index];
                      final textColor = space.color.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: space.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            space.icon,
                            color: textColor,
                            size: 20,
                          ),
                        ),
                        title: Text(space.name),
                        subtitle: FutureBuilder<int>(
                          future:
                              StorageService.getSpaceReminderCount(space.id),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Text(
                                '$count reminder${count == 1 ? '' : 's'}');
                          },
                        ),
                        onTap: () async {
                          final ctx =
                              context; // Store the context in a local variable
                          final spaceReminders =
                              await StorageService.getRemindersBySpace(
                                  space.id);
                          if (!ctx.mounted) return; // Add a mounted check
                          Navigator.of(ctx).pop();
                          _showFilteredResults(space.name, spaceReminders);
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilteredResults(String title, List<Reminder> filteredReminders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${filteredReminders.length} reminders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // List
              Expanded(
                child: filteredReminders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reminders found',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different filter',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredReminders.length,
                        itemBuilder: (context, index) {
                          return _buildReminderCard(filteredReminders[index]);
                        },
                      ),
              ),
            ],
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

    final isSelected = _selectedReminders.contains(reminder.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Slidable(
        // Unique key for each reminder
        key: ValueKey(reminder.id),

        // The end action pane is the one at the right or the bottom side.
        endActionPane: ActionPane(
          // A motion is a widget used to control how the pane animates.
          motion: const BehindMotion(),
          extentRatio: 0.52, // Actions take 35% of the width

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

            // Add to Space Action
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
                    onTap: () => _showSpaceSelector([reminder.id]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF007AFF).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF007AFF)
                                  .withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.folder_outlined,
                            color: Color(0xFF007AFF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Space',
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
        child: GestureDetector(
          onLongPress: () {
            if (!_isSelectionMode) {
              _enterSelectionMode(reminder.id);
            }
          },
          // Enhanced long press with reduced delay
          onLongPressStart: (details) {
            HapticFeedback.selectionClick(); // Immediate feedback
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A) // Nothing dark gray
                      : const Color(0xFFF5F5F5)) // Nothing light gray
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFF453A) // Nothing red accent
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isSelectionMode
                    ? () => _toggleSelection(reminder.id)
                    : null, // Remove main card tap when not in selection mode
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Selection checkbox or status indicator
                          if (_isSelectionMode)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFF453A)
                                    : Colors.transparent, // Nothing red
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFFF453A), // Nothing red
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            )
                          else
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
                          if (!_isSelectionMode) ...[
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // CONSISTENT: Same size container for all reminder states
                                GestureDetector(
                                  onTap: () => _toggleReminderStatus(reminder),
                                  child: Container(
                                    width: 48, // Consistent size
                                    height: 48, // Consistent size
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(24),
                                      // Theme-reactive border
                                      border: Border.all(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                                .withValues(alpha: 0.2)
                                            : Colors.black
                                                .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: reminder.isCompleted
                                          ? Icon(
                                              Icons.check_circle,
                                              size: 24,
                                              color: statusColor,
                                            )
                                          : Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Circular progress
                                                SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: CustomPaint(
                                                    painter:
                                                        CircularCountdownPainter(
                                                      progress:
                                                          _calculateProgress(
                                                              reminder),
                                                      backgroundColor:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .outline
                                                              .withValues(
                                                                  alpha: 0.2),
                                                      progressColor: isOverdue
                                                          ? const Color(
                                                              0xFFDC3545)
                                                          : (Theme.of(context)
                                                                      .brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors.white
                                                              : Colors.black),
                                                      strokeWidth: 2.5,
                                                    ),
                                                  ),
                                                ),
                                                // Subtle completion hint
                                                Icon(
                                                  Icons.check,
                                                  size: 12,
                                                  color: (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Time display (consistent for all states)
                                Text(
                                  reminder.isCompleted
                                      ? 'DONE'
                                      : _formatTimeRemaining(
                                          reminder.scheduledTime),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: reminder.isCompleted
                                            ? statusColor
                                            : isOverdue
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
                          ],
                        ],
                      ),

                      // Description with minimal styling
                      if (reminder.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          reminder.description!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
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
                _buildQuickFilters(),
                _buildRemindersList(_reminders),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
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
