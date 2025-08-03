// [lib/screens]/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart' as kalender;
import 'package:intl/intl.dart';
import '../widgets/calendar_view_widget.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../widgets/quick_add_event_dialog.dart';

/// Responsive calendar screen with enhanced UI and theme reactivity
/// Always shows today's date when opened
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  late TabController _viewTabController;
  late AnimationController _fabAnimationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _headerFadeAnimation;

  // Calendar view configurations
  late List<kalender.ViewConfiguration> _viewConfigurations;
  int _currentViewIndex = 1; // Start with week view

  // Calendar state - Always start with today
  DateTime _currentDate = DateTime.now();
  List<CalendarEvent> _todayEvents = [];
  List<CalendarEvent> _upcomingEvents = [];

  // References to calendar widgets
  final GlobalKey<CalendarViewWidgetState> _calendarKey =
      GlobalKey<CalendarViewWidgetState>();

  // Responsive breakpoints
  static const double _tabletBreakpoint = 600;
  static const double _desktopBreakpoint = 1200;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeViewConfigurations();
    _ensureShowingToday(); // Always show today when screen opens
    _loadCalendarData();
    _listenToCalendarUpdates();
  }

  void _initializeAnimations() {
    _viewTabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _currentViewIndex,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));

    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _viewTabController.addListener(() {
      if (_viewTabController.indexIsChanging) {
        setState(() {
          _currentViewIndex = _viewTabController.index;
        });
        // When view changes, ensure we're still showing today
        _ensureShowingToday();
      }
    });

    // Start animations
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fabAnimationController.forward();
      }
    });
  }

  void _initializeViewConfigurations() {
    _viewConfigurations = [
      // Day view
      kalender.MultiDayViewConfiguration.singleDay(),

      // Week view
      kalender.MultiDayViewConfiguration.week(),

      // Month view
      kalender.MonthViewConfiguration.singleMonth(),

      // Schedule view
      kalender.ScheduleViewConfiguration.continuous(),
    ];
  }

  /// Ensure calendar is showing today's date
  void _ensureShowingToday() {
    final now = DateTime.now();
    setState(() {
      _currentDate = now;
    });

    // Navigate to today in the calendar widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calendarKey.currentState?.navigateToToday();
    });
  }

  Future<void> _loadCalendarData() async {
    try {
      _todayEvents = CalendarService.instance.getTodayEvents();
      _upcomingEvents = CalendarService.instance.getUpcomingEvents(days: 7);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading calendar data: $e');
    }
  }

  void _listenToCalendarUpdates() {
    CalendarService.instance.eventsStream.listen((events) {
      if (mounted) {
        _loadCalendarData();
      }
    });

    CalendarService.instance.selectedDateStream.listen((date) {
      if (mounted) {
        setState(() {
          _currentDate = date;
        });
      }
    });
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    _fabAnimationController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= _tabletBreakpoint;
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body:
              isDesktop ? _buildDesktopLayout() : _buildMobileLayout(isTablet),
          floatingActionButton: _buildFloatingActionButton(),
          floatingActionButtonLocation: isTablet
              ? FloatingActionButtonLocation.endFloat
              : FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildMobileLayout(bool isTablet) {
    return Column(
      children: [
        // Fixed header instead of SliverAppBar
        _buildResponsiveHeader(isTablet),
        // Calendar view
        Expanded(
          child: _buildCalendarView(isTablet),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Side panel for desktop
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              _buildDesktopSideHeader(),
              Expanded(child: _buildSidePanel()),
            ],
          ),
        ),
        // Main calendar area
        Expanded(
          child: Column(
            children: [
              _buildDesktopMainHeader(),
              Expanded(child: _buildCalendarView(true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveHeader(bool isTablet) {
    return FadeTransition(
      opacity: _headerFadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(isTablet),
                SizedBox(height: isTablet ? 20 : 16),
                _buildViewTabs(isTablet),
                SizedBox(height: isTablet ? 16 : 12),
                _buildNavigationControls(isTablet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSideHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calendar',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _getDateRangeText(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMainHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildViewTabs(true),
          const Spacer(),
          _buildNavigationControls(true),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's events
          _buildEventsSection(
            'Today',
            _todayEvents,
            Icons.today,
          ),

          const SizedBox(height: 24),

          // Upcoming events
          _buildEventsSection(
            'Upcoming',
            _upcomingEvents.take(5).toList(),
            Icons.upcoming,
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(
      String title, List<CalendarEvent> events, IconData icon) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${events.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Text(
            'No events',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          )
        else
          ...events.map((event) => _buildEventListItem(event)),
      ],
    );
  }

  Widget _buildEventListItem(CalendarEvent event) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: event.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: event.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration:
                        event.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!event.isAllDay) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.jm().format(event.startTime),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Calendar',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: isTablet ? 32 : null,
                    ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _getDateRangeText(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontSize: isTablet ? 16 : null,
                        ),
                  ),
                  // Show "Today" indicator when showing current date
                  if (_isShowingToday()) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Today events badge
        if (_todayEvents.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 12,
              vertical: isTablet ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.today,
                  size: isTablet ? 18 : 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_todayEvents.length}',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildViewTabs(bool isTablet) {
    return Container(
      height: isTablet ? 52 : 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: TabBar(
        controller: _viewTabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        labelStyle: TextStyle(
          fontSize: isTablet ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isTablet ? 16 : 14,
          fontWeight: FontWeight.w500,
        ),
        dividerHeight: 0,
        tabs: const [
          Tab(text: 'Day'),
          Tab(text: 'Week'),
          Tab(text: 'Month'),
          Tab(text: 'Agenda'),
        ],
      ),
    );
  }

  Widget _buildNavigationControls(bool isTablet) {
    return Row(
      children: [
        _buildNavButton(
          icon: Icons.chevron_left,
          onTap: () => _calendarKey.currentState?.navigateToPrevious(),
          isTablet: isTablet,
        ),

        SizedBox(width: isTablet ? 12 : 8),

        _buildNavButton(
          icon: Icons.today,
          onTap: () {
            // Enhanced today button - always go to today
            _ensureShowingToday();
            _calendarKey.currentState?.navigateToToday();
          },
          isToday: true, // Special styling for today button
          isTablet: isTablet,
        ),

        SizedBox(width: isTablet ? 12 : 8),

        _buildNavButton(
          icon: Icons.chevron_right,
          onTap: () => _calendarKey.currentState?.navigateToNext(),
          isTablet: isTablet,
        ),

        if (isTablet) const Spacer(),

        // Quick stats
        if (_upcomingEvents.isNotEmpty) ...[
          SizedBox(width: isTablet ? 16 : 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 8,
              vertical: isTablet ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_upcomingEvents.length} upcoming',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isToday = false,
    bool isTablet = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 12 : 8),
            child: Icon(
              icon,
              size: isTablet ? 24 : 20,
              color: isToday
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16 : 8),
      child: CalendarViewWidget(
        key: _calendarKey,
        viewConfiguration: _viewConfigurations[_currentViewIndex],
        onEventTapped: _onEventTapped,
        onEventEdit: _onEventEdit,
        onEventDelete: _onEventDelete,
        onDateSelected: _onDateSelected,
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: FloatingActionButton.extended(
        onPressed: _showQuickAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }

  /// Check if we're currently showing today's date
  bool _isShowingToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDay =
        DateTime(_currentDate.year, _currentDate.month, _currentDate.day);

    return currentDay.isAtSameMomentAs(today);
  }

  String _getDateRangeText() {
    switch (_currentViewIndex) {
      case 0: // Day
        return DateFormat('EEEE, MMMM d, y').format(_currentDate);
      case 1: // Week
        final startOfWeek =
            _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d, y').format(endOfWeek)}';
      case 2: // Month
        return DateFormat('MMMM y').format(_currentDate);
      case 3: // Schedule
        return 'Schedule View';
      default:
        return DateFormat('MMMM y').format(_currentDate);
    }
  }

  void _onEventTapped(CalendarEvent event) {
    debugPrint('Event tapped: ${event.title}');
    // Event details are now handled by CalendarViewWidget
  }

  void _onEventEdit(CalendarEvent event) {
    debugPrint('Event edit: ${event.title}');
    // Edit handling is done in CalendarViewWidget
  }

  void _onEventDelete(CalendarEvent event) {
    debugPrint('Event delete: ${event.title}');
    // Delete handling is done in CalendarViewWidget
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _currentDate = date;
    });
    CalendarService.instance.updateSelectedDate(date);
  }

  Future<void> _showQuickAddDialog() async {
    // Show dialog with current date as default
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => QuickAddEventDialog(
        initialDateTime: _currentDate,
      ),
    );
  }
}
