import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/search_widget.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../models/filter_state.dart';
import '../models/sort_option.dart';
import '../widgets/reminder_card_widget.dart';

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

  // Search functionality
  bool _isSearchMode = false;
  String _searchQuery = '';
  // Selection mode for bulk actions
  bool _isSelectionMode = false;
  final Set<String> _selectedReminders = {};
  late AnimationController _selectionAnimationController;

  // Stream subscription for real-time updates
  late final Stream<List<Reminder>> _remindersStream;
  FilterState _filterState = const FilterState();

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

  void _openSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchMode = true;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchMode = false;
      _searchQuery = '';
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
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
          await StorageService.refreshData();
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
      await _refreshReminders();
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
                          color: const Color(0xFFFF453A),
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
                    Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: _openSearch,
                  tooltip: 'Search',
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
          allReminders: (filterType == FilterType.total ||
                  filterType == FilterType.pending ||
                  filterType == FilterType.completed ||
                  filterType == FilterType.overdue)
              ? _reminders
              : null,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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

  Widget _buildFilterButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFilters = _filterState.hasActiveFilters;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: hasFilters
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFilters
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: hasFilters ? 1.0 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showFilterBottomSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Dynamic sort icon based on current sort
                Icon(
                  SortOption.getIconForType(_filterState.sortOption.type),
                  size: 18,
                  color: hasFilters
                      ? Theme.of(context).colorScheme.primary
                      : (isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6D6D70)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter',
                  style: TextStyle(
                    color: hasFilters
                        ? Theme.of(context).colorScheme.primary
                        : (isDark
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF6D6D70)),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (hasFilters)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getActiveFilterCount().toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Icon(
                  Icons.tune_outlined,
                  size: 16,
                  color: hasFilters
                      ? Theme.of(context).colorScheme.primary
                      : (isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6D6D70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _getActiveFilterSummary(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _clearAllFilters,
            child: Icon(
              Icons.close,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        initialState: _filterState,
        onApply: _applyFilters,
        onRefresh: _clearAllFilters,
        onSearch: _handleFilterSearch,
      ),
    );
  }

  void _applyFilters(FilterState newState) {
    setState(() {
      _filterState = newState;
    });
    // The StreamBuilder will automatically update with the new filters
  }

  void _clearAllFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _filterState = _filterState.reset();
    });
  }

  void _handleFilterSearch(String query) {
    setState(() {
      _filterState = _filterState.copyWith(searchQuery: query);
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_filterState.status != FilterStatus.all) count++;
    if (_filterState.selectedSpaceId != null) count++;
    if (_filterState.dateRange != FilterDateRange.allTime) count++;
    if (_filterState.timeOfDay != FilterTimeOfDay.anyTime) count++;
    if (_filterState.searchQuery.isNotEmpty) count++;
    return count;
  }

  String _getActiveFilterSummary() {
    List<String> active = [];
    if (_filterState.status != FilterStatus.all) {
      active.add(_filterState.statusLabel);
    }
    if (_filterState.dateRange != FilterDateRange.allTime) {
      active.add(_filterState.dateRangeLabel);
    }
    if (_filterState.selectedSpaceId != null) {
      active.add('Space');
    }

    if (active.isEmpty) return 'Active';
    if (active.length == 1) return active.first;
    return '${active.length} filters';
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

  Widget _buildQuickFilters() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            // Pinned quick filters (if any are active)
            if (_filterState.hasActiveFilters) ...[
              _buildActiveFilterChip(),
              const SizedBox(width: 8),
            ],

            // Main Filter Button
            Expanded(
              child: _buildFilterButton(),
            ),
          ],
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
    // Get the current displayed reminders list
    List<Reminder> displayReminders;
    if (_searchQuery.isNotEmpty) {
      // Legacy search mode
      displayReminders = _reminders.where((reminder) {
        final titleMatch =
            reminder.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final descriptionMatch = reminder.description
                ?.toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false;
        return titleMatch || descriptionMatch;
      }).toList();
    } else {
      // Use new filter system
      displayReminders = _filterState.applyFilters(_reminders);
    }

    // Find the correct index in the displayed list
    final index = displayReminders.indexOf(reminder);

    return ReminderCardWidget(
      reminder: reminder,
      searchQuery: _searchQuery,
      isSelectionMode: _isSelectionMode,
      isSelected: _selectedReminders.contains(reminder.id),
      allReminders: displayReminders, // Use the filtered/displayed list
      currentIndex: index >= 0 ? index : 0, // Use the index in displayed list
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(reminder.id);
        }
      },
      onSelectionToggle: () => _toggleSelection(reminder.id),
      onEdit: _editReminder,
      onDelete: _deleteReminder,
      onAddToSpace: _showSpaceSelector,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
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

                // Apply filters using the new filter state
                List<Reminder> displayReminders;
                if (_searchQuery.isNotEmpty) {
                  // Legacy search mode
                  displayReminders = _reminders.where((reminder) {
                    final titleMatch = reminder.title
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase());
                    final descriptionMatch = reminder.description
                            ?.toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ??
                        false;
                    return titleMatch || descriptionMatch;
                  }).toList();
                } else {
                  // Use new filter system
                  displayReminders = _filterState.applyFilters(_reminders);
                }

                return CustomScrollView(
                  slivers: [
                    _buildAppBar(),

                    // Show search results summary when searching
                    if (_searchQuery.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SearchResultsSummary(
                          resultCount: displayReminders.length,
                          searchQuery: _searchQuery,
                        ),
                      ),

                    // Show stats and filters only when not searching
                    if (!_isSearchMode) _buildStatsCards(_reminders),
                    if (!_isSearchMode) _buildQuickFilters(),

                    _buildRemindersList(displayReminders),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                );
              },
            ),
          ),

          // Search overlay (covers entire screen when active)
          if (_isSearchMode)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Column(
                  children: [
                    SearchWidget(
                      onSearchChanged: _onSearchChanged,
                      onClose: _closeSearch,
                      hintText: 'Search reminders...',
                    ),
                    Expanded(
                      child: _searchQuery.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Start typing to search',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: () {
                                final filtered = _reminders.where((reminder) {
                                  final titleMatch = reminder.title
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase());
                                  final descriptionMatch = reminder.description
                                          ?.toLowerCase()
                                          .contains(
                                              _searchQuery.toLowerCase()) ??
                                      false;
                                  return titleMatch || descriptionMatch;
                                }).toList();
                                return filtered.length;
                              }(),
                              itemBuilder: (context, index) {
                                final filtered = _reminders.where((reminder) {
                                  final titleMatch = reminder.title
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase());
                                  final descriptionMatch = reminder.description
                                          ?.toLowerCase()
                                          .contains(
                                              _searchQuery.toLowerCase()) ??
                                      false;
                                  return titleMatch || descriptionMatch;
                                }).toList();
                                return _buildReminderCard(filtered[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
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

class HighlightedText extends StatelessWidget {
  final String text;
  final String searchTerm;
  final TextStyle? defaultStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.searchTerm,
    this.defaultStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (searchTerm.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerSearchTerm, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
        break;
      }

      if (index > start) {
        spans.add(
            TextSpan(text: text.substring(start, index), style: defaultStyle));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: defaultStyle?.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + searchTerm.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class SearchResultsSummary extends StatelessWidget {
  final int resultCount;
  final String searchQuery;

  const SearchResultsSummary({
    super.key,
    required this.resultCount,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 16,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            '$resultCount result${resultCount == 1 ? '' : 's'} for "$searchQuery"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}
