// lib/widgets/filter_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/filter_state.dart';
import '../models/sort_option.dart';
import '../models/space.dart';
import '../services/spaces_service.dart';

class FilterBottomSheet extends StatefulWidget {
  final FilterState initialState;
  final Function(FilterState) onApply;
  final VoidCallback? onRefresh;
  final Function(String)? onSearch;

  const FilterBottomSheet({
    super.key,
    required this.initialState,
    required this.onApply,
    this.onRefresh,
    this.onSearch,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet>
    with TickerProviderStateMixin {
  late FilterState _currentState;
  List<Space> _spaces = [];
  late AnimationController _slideController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _loadSpaces();
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await SpacesService.getSpaces();
      if (mounted) {
        setState(() {
          _spaces = spaces;
        });
      }
    } catch (e) {
      if (mounted) {}
    }
  }

  void _updateState(FilterState newState) {
    setState(() => _currentState = newState);
  }

  void _handleRefresh() {
    HapticFeedback.lightImpact();
    setState(() => _currentState = _currentState.reset());
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  void _handleSearch() {
    HapticFeedback.lightImpact();
    if (widget.onSearch != null) {
      widget.onSearch!(_currentState.searchQuery);
    }
  }

  void _showSortOptions() {
    HapticFeedback.lightImpact();
    _showSortDropdown();
  }

  void _handleApply() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onApply(_currentState);
  }

  void _handleCancel() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Refresh (Clear All)
          _buildHeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Clear All',
            onTap: _handleRefresh,
          ),

          const SizedBox(width: 16),

          // Search
          _buildHeaderAction(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onTap: _handleSearch,
          ),

          const Spacer(),

          // Filter Title
          Text(
            'Filter',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
          ),

          const Spacer(),

          // Sort (Dynamic Icon)
          _buildHeaderAction(
            icon: SortOption.getIconForType(_currentState.sortOption.type),
            tooltip: 'Sort',
            onTap: _showSortOptions,
          ),

          const SizedBox(width: 16),

          // Close
          _buildHeaderAction(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onTap: _handleCancel,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdowns(),
              const SizedBox(height: 24),
              _buildQuickFilters(),
              const SizedBox(height: 24),
              _buildPinnedFiltersPlaceholder(),
              const SizedBox(height: 32),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdowns() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatusDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _buildSpaceDropdown()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDateDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _buildTimeDropdown()),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Builder(
      builder: (buttonContext) => _buildDropdownContainer(
        label: 'Status',
        value: _currentState.statusLabel,
        onTap: () => _showStatusPicker(buttonContext),
      ),
    );
  }

  Widget _buildSpaceDropdown() {
    return Builder(
      builder: (buttonContext) => _buildDropdownContainer(
        label: 'Space',
        value: _getSpaceLabel(),
        onTap: () => _showSpacePicker(buttonContext),
      ),
    );
  }

  Widget _buildDateDropdown() {
    return Builder(
      builder: (buttonContext) => _buildDropdownContainer(
        label: 'Date',
        value: _getSmartDateLabel(),
        onTap: () => _showDatePicker(buttonContext),
      ),
    );
  }

  Widget _buildTimeDropdown() {
    return Builder(
      builder: (buttonContext) => _buildDropdownContainer(
        label: 'Time',
        value: _getSmartTimeLabel(),
        onTap: () => _showTimePicker(buttonContext),
      ),
    );
  }

  Widget _buildDropdownContainer({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Quick Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
            ),
            const Spacer(),
            _buildGridToggle(
              isGrid: _currentState.isGridView,
              onToggle: (value) => _updateState(
                _currentState.copyWith(isGridView: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildQuickFilterChips(),
      ],
    );
  }

  Widget _buildGridToggle({
    required bool isGrid,
    required Function(bool) onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: Icons.view_list_rounded,
            isSelected: !isGrid,
            onTap: () => onToggle(false),
          ),
          _buildToggleButton(
            icon: Icons.grid_view_rounded,
            isSelected: isGrid,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Icon(
            icon,
            size: 16,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips() {
    final quickFilters = [
      {'label': 'Today', 'value': FilterDateRange.today},
      {'label': 'Tomorrow', 'value': FilterDateRange.tomorrow},
      {'label': 'Overdue', 'value': FilterStatus.overdue},
      {'label': 'Completed', 'value': FilterStatus.completed},
    ];

    if (_currentState.isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: quickFilters.length,
        itemBuilder: (context, index) {
          final filter = quickFilters[index];
          return _buildFilterChip(
            label: filter['label'] as String,
            isSelected: _isQuickFilterSelected(filter['value']),
            onTap: () => _handleQuickFilterTap(filter['value']),
          );
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickFilters.map((filter) {
        return _buildFilterChip(
          label: filter['label'] as String,
          isSelected: _isQuickFilterSelected(filter['value']),
          onTap: () => _handleQuickFilterTap(filter['value']),
        );
      }).toList(),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFF7F7F7)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedFiltersPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: 32,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Pinned Filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coming Soon',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Cancel',
            onTap: _handleCancel,
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Apply',
            onTap: _handleApply,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isPrimary
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isPrimary
            ? null
            : Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isPrimary
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for dropdown pickers with FIXED positioning
  void _showStatusPicker(BuildContext buttonContext) {
    HapticFeedback.lightImpact();
    _showDropdownMenu<FilterStatus>(
      items: FilterStatus.values.map((status) {
        String label;
        switch (status) {
          case FilterStatus.all:
            label = 'All';
            break;
          case FilterStatus.pending:
            label = 'Pending';
            break;
          case FilterStatus.completed:
            label = 'Completed';
            break;
          case FilterStatus.overdue:
            label = 'Overdue';
            break;
        }
        return DropdownMenuItem(value: status, child: Text(label));
      }).toList(),
      value: _currentState.status,
      onChanged: (value) => _updateState(_currentState.copyWith(status: value)),
      buttonContext: buttonContext,
    );
  }

  void _showSpacePicker(BuildContext buttonContext) {
    HapticFeedback.lightImpact();
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All Spaces')),
      ..._spaces.map((space) => DropdownMenuItem(
            value: space.id,
            child: Row(
              children: [
                Icon(space.icon, size: 16, color: space.color),
                const SizedBox(width: 8),
                Text(space.name),
              ],
            ),
          )),
    ];

    _showDropdownMenu<String?>(
      items: items,
      value: _currentState.selectedSpaceId,
      onChanged: (value) => _updateState(_currentState.copyWith(
        selectedSpaceId: value,
        clearSpaceId: value == null,
      )),
      buttonContext: buttonContext,
    );
  }

  void _showDatePicker(BuildContext buttonContext) {
    HapticFeedback.lightImpact();
    _showDropdownMenu<FilterDateRange>(
      items: FilterDateRange.values.map((range) {
        String label = _getDateRangeLabel(range);
        return DropdownMenuItem(value: range, child: Text(label));
      }).toList(),
      value: _currentState.dateRange,
      onChanged: (value) async {
        if (value == FilterDateRange.customRange) {
          await _selectCustomDateRange();
        } else {
          _updateState(
              _currentState.copyWith(dateRange: value, clearCustomDates: true));
        }
      },
      buttonContext: buttonContext,
    );
  }

  void _showTimePicker(BuildContext buttonContext) {
    HapticFeedback.lightImpact();
    _showDropdownMenu<FilterTimeOfDay>(
      items: FilterTimeOfDay.values.map((time) {
        String label = _getTimeOfDayLabel(time);
        return DropdownMenuItem(value: time, child: Text(label));
      }).toList(),
      value: _currentState.timeOfDay,
      onChanged: (value) async {
        if (value == FilterTimeOfDay.customTime) {
          await _selectCustomTimeRange();
        } else {
          _updateState(_currentState.copyWith(timeOfDay: value));
        }
      },
      buttonContext: buttonContext,
    );
  }

  void _showSortDropdown() {
    _showDropdownMenu<SortOption>(
      items: SortOption.defaultOptions.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Row(
            children: [
              Icon(option.icon, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(option.label)),
            ],
          ),
        );
      }).toList(),
      value: _currentState.sortOption,
      onChanged: (value) =>
          _updateState(_currentState.copyWith(sortOption: value)),
    );
  }

  // FIXED dropdown positioning method
  void _showDropdownMenu<T>({
    required List<DropdownMenuItem<T>> items,
    required T value,
    required Function(T?) onChanged,
    BuildContext? buttonContext,
  }) {
    final targetContext = buttonContext ?? context;
    final RenderBox renderBox = targetContext.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Clamp left so dropdown doesn't go off screen
    final double minLeft = 8.0;
    final double maxLeft = screenWidth - size.width - 8.0;
    final double adjustedLeft =
        (minLeft < maxLeft) ? position.dx.clamp(minLeft, maxLeft) : minLeft;
    final double dropdownTop =
        (position.dy + size.height + 8).clamp(0, screenHeight - 200);

    showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        adjustedLeft,
        dropdownTop,
        screenWidth - adjustedLeft - size.width,
        0,
      ),
      items: items.map((item) {
        return PopupMenuItem<T>(
          value: item.value,
          child: item.child,
        );
      }).toList(),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width * 1.5,
      ),
    ).then((selectedValue) {
      if (selectedValue != null) {
        onChanged(selectedValue);
      }
    });
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _currentState.customStartDate != null &&
              _currentState.customEndDate != null
          ? DateTimeRange(
              start: _currentState.customStartDate!,
              end: _currentState.customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  surface: Theme.of(context).colorScheme.surface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      _updateState(_currentState.copyWith(
        dateRange: FilterDateRange.customRange,
        customStartDate: range.start,
        customEndDate: range.end,
      ));
    }
  }

  Future<void> _selectCustomTimeRange() async {
    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select start time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (startTime != null && mounted) {
      final TimeOfDay? endTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: (startTime.hour + 2) % 24,
          minute: startTime.minute,
        ),
        helpText: 'Select end time',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(),
            ),
            child: child!,
          );
        },
      );

      if (endTime != null) {
        _updateState(
          _currentState.copyWith(
            timeOfDay: FilterTimeOfDay.customTime,
            customStartTime: startTime,
            customEndTime: endTime,
          ),
        );

        if (mounted) {
          debugPrint(
            'Custom time range: ${startTime.format(context)} - ${endTime.format(context)}',
          );
        }
      }
    }
  }

  // Helper methods for smart labels
  String _getSmartDateLabel() {
    final now = DateTime.now();

    switch (_currentState.dateRange) {
      case FilterDateRange.allTime:
        return 'All Time';
      case FilterDateRange.today:
        return 'Today';
      case FilterDateRange.tomorrow:
        return 'Tomorrow';
      case FilterDateRange.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return 'This Week (${_formatShortDate(weekStart)} - ${_formatShortDate(weekEnd)})';
      case FilterDateRange.nextWeek:
        final nextWeekStart = now.add(Duration(days: 7 - now.weekday + 1));
        final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
        return 'Next Week (${_formatShortDate(nextWeekStart)} - ${_formatShortDate(nextWeekEnd)})';
      case FilterDateRange.thisMonth:
        final monthName = _getMonthName(now.month);
        return 'This Month ($monthName ${now.year})';
      case FilterDateRange.customRange:
        if (_currentState.customStartDate != null &&
            _currentState.customEndDate != null) {
          return 'Custom (${_formatShortDate(_currentState.customStartDate!)} - ${_formatShortDate(_currentState.customEndDate!)})';
        }
        return 'Custom Range';
    }
  }

  String _getSmartTimeLabel() {
    switch (_currentState.timeOfDay) {
      case FilterTimeOfDay.anyTime:
        return 'Any Time';
      case FilterTimeOfDay.morning:
        return 'Morning (6 AM - 12 PM)';
      case FilterTimeOfDay.afternoon:
        return 'Afternoon (12 PM - 6 PM)';
      case FilterTimeOfDay.evening:
        return 'Evening (6 PM - 10 PM)';
      case FilterTimeOfDay.night:
        return 'Night (10 PM - 6 AM)';
      case FilterTimeOfDay.customTime:
        if (_currentState.customStartTime != null &&
            _currentState.customEndTime != null) {
          final start = _currentState.customStartTime!.format(context);
          final end = _currentState.customEndTime!.format(context);
          return 'Custom ($start - $end)';
        }
        return 'Custom Time Range';
    }
  }

  String _getDateRangeLabel(FilterDateRange range) {
    final now = DateTime.now();

    switch (range) {
      case FilterDateRange.allTime:
        return 'All Time';
      case FilterDateRange.today:
        return 'Today';
      case FilterDateRange.tomorrow:
        return 'Tomorrow';
      case FilterDateRange.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return 'This Week (${_formatShortDate(weekStart)} - ${_formatShortDate(weekEnd)})';
      case FilterDateRange.nextWeek:
        final nextWeekStart = now.add(Duration(days: 7 - now.weekday + 1));
        final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
        return 'Next Week (${_formatShortDate(nextWeekStart)} - ${_formatShortDate(nextWeekEnd)})';
      case FilterDateRange.thisMonth:
        final monthName = _getMonthName(now.month);
        return 'This Month ($monthName ${now.year})';
      case FilterDateRange.customRange:
        return 'Custom Range';
    }
  }

  String _getTimeOfDayLabel(FilterTimeOfDay time) {
    switch (time) {
      case FilterTimeOfDay.anyTime:
        return 'Any Time';
      case FilterTimeOfDay.morning:
        return 'Morning (6 AM - 12 PM)';
      case FilterTimeOfDay.afternoon:
        return 'Afternoon (12 PM - 6 PM)';
      case FilterTimeOfDay.evening:
        return 'Evening (6 PM - 10 PM)';
      case FilterTimeOfDay.night:
        return 'Night (10 PM - 6 AM)';
      case FilterTimeOfDay.customTime:
        return 'Custom Time Range';
    }
  }

  String _formatShortDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Helper methods
  String _getSpaceLabel() {
    if (_currentState.selectedSpaceId == null) return 'All';
    final space = _spaces.firstWhere(
      (s) => s.id == _currentState.selectedSpaceId,
      orElse: () => Space(
        id: '',
        name: 'Unknown',
        color: Colors.grey,
        icon: Icons.folder,
        createdAt: DateTime.now(),
      ),
    );
    return space.name;
  }

  bool _isQuickFilterSelected(dynamic value) {
    if (value is FilterDateRange) {
      return _currentState.dateRange == value;
    } else if (value is FilterStatus) {
      return _currentState.status == value;
    }
    return false;
  }

  void _handleQuickFilterTap(dynamic value) {
    HapticFeedback.lightImpact();
    if (value is FilterDateRange) {
      _updateState(_currentState.copyWith(dateRange: value));
    } else if (value is FilterStatus) {
      _updateState(_currentState.copyWith(status: value));
    }
  }
}
