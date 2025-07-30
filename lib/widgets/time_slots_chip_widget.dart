import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reminder.dart';

/// Subtle and minimalist chip widget for multi-time reminders
class TimeSlotsChipWidget extends StatefulWidget {
  final List<TimeSlot> timeSlots;
  final String? selectedTimeSlotId;
  final ValueChanged<String> onTimeSlotSelected;
  final bool showArrows;
  final double chipHeight;
  final EdgeInsets padding;
  final bool isCompact;

  const TimeSlotsChipWidget({
    super.key,
    required this.timeSlots,
    this.selectedTimeSlotId,
    required this.onTimeSlotSelected,
    this.showArrows = true,
    this.chipHeight = 32.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 4.0),
    this.isCompact = false,
  });

  @override
  State<TimeSlotsChipWidget> createState() => _TimeSlotsChipWidgetState();
}

class _TimeSlotsChipWidgetState extends State<TimeSlotsChipWidget>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _slideController;
  int _currentPage = 0;
  final int _chipsPerPage = 4; // Increased from 3 to show more chips

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController.forward();

    // Set initial page to show selected chip
    if (widget.selectedTimeSlotId != null) {
      final selectedIndex = widget.timeSlots
          .indexWhere((slot) => slot.id == widget.selectedTimeSlotId);
      if (selectedIndex != -1) {
        _currentPage = selectedIndex ~/ _chipsPerPage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              _currentPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TimeSlotsChipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update current page if selected time slot changed
    if (widget.selectedTimeSlotId != oldWidget.selectedTimeSlotId &&
        widget.selectedTimeSlotId != null) {
      final selectedIndex = widget.timeSlots
          .indexWhere((slot) => slot.id == widget.selectedTimeSlotId);
      if (selectedIndex != -1) {
        final newPage = selectedIndex ~/ _chipsPerPage;
        if (newPage != _currentPage) {
          setState(() => _currentPage = newPage);
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  int get _totalPages => (widget.timeSlots.length / _chipsPerPage).ceil();

  bool get _canGoBack => _currentPage > 0;
  bool get _canGoForward => _currentPage < _totalPages - 1;
  bool get _shouldShowNavigation =>
      widget.showArrows && widget.timeSlots.length > _chipsPerPage;

  void _goToPreviousPage() {
    if (_canGoBack) {
      HapticFeedback.lightImpact();
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_canGoForward) {
      HapticFeedback.lightImpact();
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onChipTapped(TimeSlot timeSlot) {
    HapticFeedback.selectionClick();
    widget.onTimeSlotSelected(timeSlot.id);
  }

  // IMPROVED: More subtle color scheme
  Color _getChipBackgroundColor(
      TimeSlot timeSlot, bool isSelected, bool isDark) {
    if (isSelected) {
      return Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    }

    switch (timeSlot.status) {
      case ReminderStatus.completed:
        return isDark
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.1);
      case ReminderStatus.overdue:
        return isDark
            ? Colors.red.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.1);
      case ReminderStatus.pending:
        return isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05);
    }
  }

  Color _getChipBorderColor(TimeSlot timeSlot, bool isSelected, bool isDark) {
    if (isSelected) {
      return Theme.of(context).colorScheme.primary.withValues(alpha: 0.4);
    }

    switch (timeSlot.status) {
      case ReminderStatus.completed:
        return Colors.green.withValues(alpha: 0.3);
      case ReminderStatus.overdue:
        return Colors.red.withValues(alpha: 0.3);
      case ReminderStatus.pending:
        return Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
    }
  }

  Color _getChipTextColor(TimeSlot timeSlot, bool isSelected, bool isDark) {
    if (isSelected) {
      return Theme.of(context).colorScheme.primary;
    }

    switch (timeSlot.status) {
      case ReminderStatus.completed:
        return isDark ? Colors.green.shade300 : Colors.green.shade700;
      case ReminderStatus.overdue:
        return isDark ? Colors.red.shade300 : Colors.red.shade700;
      case ReminderStatus.pending:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  // IMPROVED: Minimal status indicator
  Widget? _getStatusIndicator(TimeSlot timeSlot, bool isSelected) {
    if (isSelected) return null; // Don't show status when selected

    switch (timeSlot.status) {
      case ReminderStatus.completed:
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        );
      case ReminderStatus.overdue:
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
      case ReminderStatus.pending:
        return null;
    }
  }

  // IMPROVED: Cleaner chip design
  Widget _buildChip(TimeSlot timeSlot, bool isDark) {
    final isSelected = timeSlot.id == widget.selectedTimeSlotId;
    final chipBackgroundColor =
        _getChipBackgroundColor(timeSlot, isSelected, isDark);
    final chipBorderColor = _getChipBorderColor(timeSlot, isSelected, isDark);
    final textColor = _getChipTextColor(timeSlot, isSelected, isDark);
    final statusIndicator = _getStatusIndicator(timeSlot, isSelected);

    final screenWidth = MediaQuery.of(context).size.width;
    final isVeryCompact = screenWidth < 350 || widget.isCompact;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: widget.chipHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onChipTapped(timeSlot),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVeryCompact ? 8 : 10,
              vertical: isVeryCompact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: chipBackgroundColor,
              border: Border.all(
                color: chipBorderColor,
                width: isSelected ? 1.0 : 0.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status indicator (subtle dot)
                if (statusIndicator != null) ...[
                  statusIndicator,
                  SizedBox(width: isVeryCompact ? 4 : 6),
                ],

                // Time text
                Text(
                  isVeryCompact
                      ? timeSlot.formattedTime24
                      : timeSlot.formattedTime,
                  style: TextStyle(
                    color: textColor,
                    fontSize: isVeryCompact ? 11 : 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // IMPROVED: Subtle navigation arrows
  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool enabled,
    required bool isDark,
  }) {
    return AnimatedOpacity(
      opacity: enabled ? 0.8 : 0.3,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 24,
          height: widget.chipHeight,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainer
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  List<Widget> _getVisibleChips() {
    final startIndex = _currentPage * _chipsPerPage;
    final endIndex =
        (startIndex + _chipsPerPage).clamp(0, widget.timeSlots.length);
    return widget.timeSlots
        .sublist(startIndex, endIndex)
        .map((slot) =>
            _buildChip(slot, Theme.of(context).brightness == Brightness.dark))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        padding: widget.padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left navigation arrow (more subtle)
            if (_shouldShowNavigation) ...[
              _buildNavigationButton(
                icon: Icons.chevron_left,
                onPressed: _goToPreviousPage,
                enabled: _canGoBack,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
            ],

            // Chips container
            Flexible(
              child: widget.timeSlots.length <= _chipsPerPage
                  ? Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: widget.timeSlots
                          .map((slot) => _buildChip(slot, isDark))
                          .toList(),
                    )
                  : SizedBox(
                      height: widget.chipHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) {
                          setState(() => _currentPage = page);
                        },
                        itemCount: _totalPages,
                        itemBuilder: (context, pageIndex) {
                          final visibleChips = _getVisibleChips();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: visibleChips.asMap().entries.map((entry) {
                              final index = entry.key;
                              final chip = entry.value;
                              return Flexible(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right:
                                        index < visibleChips.length - 1 ? 6 : 0,
                                  ),
                                  child: chip,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
            ),

            // Right navigation arrow (more subtle)
            if (_shouldShowNavigation) ...[
              const SizedBox(width: 8),
              _buildNavigationButton(
                icon: Icons.chevron_right,
                onPressed: _goToNextPage,
                enabled: _canGoForward,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact version for use in tight spaces
class CompactTimeSlotsChipWidget extends StatelessWidget {
  final List<TimeSlot> timeSlots;
  final String? selectedTimeSlotId;
  final ValueChanged<String> onTimeSlotSelected;

  const CompactTimeSlotsChipWidget({
    super.key,
    required this.timeSlots,
    this.selectedTimeSlotId,
    required this.onTimeSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TimeSlotsChipWidget(
      timeSlots: timeSlots,
      selectedTimeSlotId: selectedTimeSlotId,
      onTimeSlotSelected: onTimeSlotSelected,
      chipHeight: 28,
      isCompact: true,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      showArrows: false, // No arrows in compact mode
    );
  }
}

/// Extension for finding next auto-select time slot
extension TimeSlotsChipHelper on List<TimeSlot> {
  /// Get the next pending time slot that should be auto-selected
  TimeSlot? get nextPendingSlot {
    if (isEmpty) return null;

    final now = DateTime.now();
    final currentTimeInMinutes = now.hour * 60 + now.minute;

    // First try to find next pending slot after current time
    final futurePendingSlots = where((slot) =>
        slot.status == ReminderStatus.pending &&
        slot.timeInMinutes > currentTimeInMinutes).toList();

    if (futurePendingSlots.isNotEmpty) {
      futurePendingSlots
          .sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
      return futurePendingSlots.first;
    }

    // If no future slots, find the first pending slot (wrap around)
    final pendingSlots =
        where((slot) => slot.status == ReminderStatus.pending).toList();
    if (pendingSlots.isNotEmpty) {
      pendingSlots.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
      return pendingSlots.first;
    }

    // If no pending slots, return first slot
    return isNotEmpty ? first : null;
  }
}
