// [lib/widgets]/time_slots_chip_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reminder.dart';

/// Modern, responsive chip widget for multi-time reminders with horizontal scrolling
class TimeSlotsChipWidget extends StatefulWidget {
  final List<TimeSlot> timeSlots;
  final String? selectedTimeSlotId;
  final ValueChanged<String> onTimeSlotSelected;
  final double chipHeight;
  final EdgeInsets padding;
  final bool isCompact;
  final bool showScrollHint;

  const TimeSlotsChipWidget({
    super.key,
    required this.timeSlots,
    this.selectedTimeSlotId,
    required this.onTimeSlotSelected,
    this.chipHeight = 36.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.isCompact = false,
    this.showScrollHint = true,
  });

  @override
  State<TimeSlotsChipWidget> createState() => _TimeSlotsChipWidgetState();
}

class _TimeSlotsChipWidgetState extends State<TimeSlotsChipWidget>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _slideController;
  late AnimationController _hintController;
  bool _showLeftHint = false;
  bool _showRightHint = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _hintController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController.forward();

    // Add scroll listener for hints
    _scrollController.addListener(_updateScrollHints);

    // Auto-scroll to selected chip and show hints
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedChip();
      _updateScrollHints();
      if (widget.showScrollHint && widget.timeSlots.length > 3) {
        _showScrollHints();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _hintController.dispose();
    _scrollController.removeListener(_updateScrollHints);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TimeSlotsChipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTimeSlotId != oldWidget.selectedTimeSlotId) {
      _scrollToSelectedChip();
    }
  }

  void _updateScrollHints() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    setState(() {
      _showLeftHint = currentScroll > 20;
      _showRightHint = currentScroll < maxScroll - 20;
    });
  }

  void _showScrollHints() {
    if (widget.timeSlots.length > 3) {
      _hintController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _hintController.reverse();
        });
      });
    }
  }

  void _scrollToSelectedChip() {
    if (widget.selectedTimeSlotId == null || !_scrollController.hasClients) {
      return;
    }

    final selectedIndex = widget.timeSlots
        .indexWhere((slot) => slot.id == widget.selectedTimeSlotId);

    if (selectedIndex != -1) {
      final chipWidth = _getChipWidth();
      final spacing = 8.0;
      final targetPosition = (selectedIndex * (chipWidth + spacing)) -
          (MediaQuery.of(context).size.width / 2) +
          (chipWidth / 2);

      _scrollController.animateTo(
        targetPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  double _getChipWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (widget.isCompact || screenWidth < 350) return 70.0;
    return 85.0;
  }

  void _onChipTapped(TimeSlot timeSlot) {
    HapticFeedback.selectionClick();
    widget.onTimeSlotSelected(timeSlot.id);
  }

  // Modern Material 3 inspired color scheme
  Color _getChipBackgroundColor(
      TimeSlot timeSlot, bool isSelected, ColorScheme colorScheme) {
    if (isSelected) {
      return colorScheme.primaryContainer;
    }

    switch (timeSlot.status) {
      case ReminderStatus.completed:
        return Colors.green
            .withValues(alpha: 0.85); // Clean green for completed
      case ReminderStatus.overdue:
        return colorScheme.errorContainer.withValues(alpha: 0.7);
      case ReminderStatus.pending:
        return colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    }
  }

  Color _getChipTextColor(
      TimeSlot timeSlot, bool isSelected, ColorScheme colorScheme) {
    if (isSelected) {
      return colorScheme.onPrimaryContainer;
    }

    switch (timeSlot.status) {
      case ReminderStatus.completed:
        return Colors.white; // White text on green background
      case ReminderStatus.overdue:
        return colorScheme.onErrorContainer;
      case ReminderStatus.pending:
        return colorScheme.onSurface;
    }
  }

  // Subtle status indicator with modern design - NO indicator for completed chips
  Widget? _getStatusIndicator(
      TimeSlot timeSlot, bool isSelected, ColorScheme colorScheme) {
    // Never show status indicator when selected or completed
    if (isSelected ||
        timeSlot.status == ReminderStatus.pending ||
        timeSlot.status == ReminderStatus.completed) {
      return null;
    }

    // Only show red dot for overdue
    if (timeSlot.status == ReminderStatus.overdue) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: colorScheme.error,
          shape: BoxShape.circle,
        ),
      );
    }

    return null;
  }

  Widget _buildChip(TimeSlot timeSlot, ColorScheme colorScheme) {
    final isSelected = timeSlot.id == widget.selectedTimeSlotId;
    final chipWidth = _getChipWidth();
    final isVeryCompact =
        widget.isCompact || MediaQuery.of(context).size.width < 350;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: chipWidth,
      height: widget.chipHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onChipTapped(timeSlot),
          borderRadius: BorderRadius.circular(widget.chipHeight / 2),
          child: Container(
            decoration: BoxDecoration(
              color: _getChipBackgroundColor(timeSlot, isSelected, colorScheme),
              borderRadius: BorderRadius.circular(widget.chipHeight / 2),
              border: isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      width:
                          2.0, // Slightly thicker border for better visibility
                    )
                  : timeSlot.status == ReminderStatus.completed
                      ? Border.all(
                          color: Colors.green.shade700.withValues(alpha: 0.3),
                          width: 1.0,
                        )
                      : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : timeSlot.status == ReminderStatus.completed
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status indicator (only for overdue, never for completed or selected)
                if (_getStatusIndicator(timeSlot, isSelected, colorScheme) !=
                    null) ...[
                  _getStatusIndicator(timeSlot, isSelected, colorScheme)!,
                  SizedBox(width: isVeryCompact ? 4 : 6),
                ],

                // Time text - clean and simple
                Flexible(
                  child: Text(
                    isVeryCompact
                        ? timeSlot.formattedTime24
                        : timeSlot.formattedTime,
                    style: TextStyle(
                      color:
                          _getChipTextColor(timeSlot, isSelected, colorScheme),
                      fontSize: isVeryCompact ? 12 : 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : timeSlot.status == ReminderStatus.completed
                              ? FontWeight.w600
                              : FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollHint({required bool isLeft}) {
    return AnimatedBuilder(
      animation: _hintController,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: _hintController.value * 0.7,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 24,
            height: widget.chipHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
                end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context)
                      .scaffoldBackgroundColor
                      .withValues(alpha: 0),
                ],
              ),
            ),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.outline.withValues(
                    alpha: _hintController.value * 0.8,
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollIndicator() {
    if (widget.timeSlots.length <= 3) return const SizedBox.shrink();

    return Container(
      height: 3,
      margin: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              if (!_scrollController.hasClients) {
                return const SizedBox.shrink();
              }

              final maxScroll = _scrollController.position.maxScrollExtent;
              final currentScroll = _scrollController.position.pixels;
              final indicatorWidth = constraints.maxWidth * 0.6;
              final indicatorPosition = (currentScroll / maxScroll) *
                  (constraints.maxWidth - indicatorWidth);

              return Stack(
                children: [
                  // Track
                  Container(
                    width: double.infinity,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  // Indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 100),
                    left: indicatorPosition,
                    child: Container(
                      width: indicatorWidth,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timeSlots.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main scrollable chips container
            SizedBox(
              height: widget.chipHeight,
              child: Stack(
                children: [
                  // Scrollable chips
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false, // Hide scrollbar for cleaner look
                      ),
                      child: ListView.separated(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.timeSlots.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return _buildChip(
                              widget.timeSlots[index], colorScheme);
                        },
                      ),
                    ),
                  ),

                  // Left scroll hint
                  if (_showLeftHint && widget.showScrollHint)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _buildScrollHint(isLeft: true),
                    ),

                  // Right scroll hint
                  if (_showRightHint && widget.showScrollHint)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _buildScrollHint(isLeft: false),
                    ),
                ],
              ),
            ),

            // Scroll indicator for many chips
            _buildScrollIndicator(),
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
      chipHeight: 32,
      isCompact: true,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      showScrollHint: false, // No hints in compact mode
    );
  }
}

/// Minimal version for very constrained spaces
class MinimalTimeSlotsChipWidget extends StatelessWidget {
  final List<TimeSlot> timeSlots;
  final String? selectedTimeSlotId;
  final ValueChanged<String> onTimeSlotSelected;

  const MinimalTimeSlotsChipWidget({
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      showScrollHint: false,
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

  /// Get a summary string for display (e.g., "3 pending, 2 completed")
  String get statusSummary {
    final pending =
        where((slot) => slot.status == ReminderStatus.pending).length;
    final completed =
        where((slot) => slot.status == ReminderStatus.completed).length;
    final overdue =
        where((slot) => slot.status == ReminderStatus.overdue).length;

    final parts = <String>[];
    if (pending > 0) parts.add('$pending pending');
    if (completed > 0) parts.add('$completed completed');
    if (overdue > 0) parts.add('$overdue overdue');

    return parts.join(', ');
  }
}
