// lib/widgets/multi_time_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reminder.dart';

class MultiTimeSection extends StatefulWidget {
  final List<TimeSlot> timeSlots;
  final ValueChanged<List<TimeSlot>> onTimeSlotsChanged;
  final bool isMultiTime;
  final ValueChanged<bool> onMultiTimeToggle;
  final TimeOfDay? initialSingleTime;
  final ValueChanged<TimeOfDay>? onSingleTimeChanged;
  final String? singleTimeLabel;
  final bool showToggleButton;
  final bool isCompact;
  final EdgeInsets padding;
  final String addButtonText;
  final int maxTimeSlots;

  const MultiTimeSection({
    super.key,
    required this.timeSlots,
    required this.onTimeSlotsChanged,
    required this.isMultiTime,
    required this.onMultiTimeToggle,
    this.initialSingleTime,
    this.onSingleTimeChanged,
    this.singleTimeLabel = 'Time',
    this.showToggleButton = true,
    this.isCompact = false,
    this.padding = const EdgeInsets.all(16.0),
    this.addButtonText = 'Add Time',
    this.maxTimeSlots = 10,
  });

  @override
  State<MultiTimeSection> createState() => _MultiTimeSectionState();
}

class _MultiTimeSectionState extends State<MultiTimeSection>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _expandController;
  final ScrollController _scrollController = ScrollController();
  late TimeOfDay _currentSingleTime;

  // For validation
  final Map<String, String?> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _currentSingleTime = widget.initialSingleTime ?? TimeOfDay.now();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    if (widget.isMultiTime) {
      _expandController.value = 1.0;
    }
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _expandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MultiTimeSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialSingleTime != null &&
        widget.initialSingleTime != oldWidget.initialSingleTime) {
      _currentSingleTime = widget.initialSingleTime!;
    }

    if (widget.isMultiTime != oldWidget.isMultiTime) {
      if (widget.isMultiTime) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  Future<void> _selectSingleTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _currentSingleTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _currentSingleTime) {
      setState(() {
        _currentSingleTime = picked;
      });

      widget.onSingleTimeChanged?.call(picked);

      HapticFeedback.lightImpact();
    }
  }

  void _toggleMultiTime() {
    HapticFeedback.selectionClick();

    if (widget.isMultiTime) {
      // Switch to single time mode
      widget.onMultiTimeToggle(false);
      widget.onTimeSlotsChanged([]);
    } else {
      // Switch to multi time mode
      widget.onMultiTimeToggle(true);

      final initialSlot = TimeSlot(
        time: _currentSingleTime,
        description: null,
      );
      widget.onTimeSlotsChanged([initialSlot]);
    }
  }

  void _addTimeSlot() {
    if (widget.timeSlots.length >= widget.maxTimeSlots) {
      _showMaxSlotsReachedSnackBar();
      return;
    }

    HapticFeedback.lightImpact();

    // Find a good default time (next hour or reasonable time)
    final now = TimeOfDay.now();
    TimeOfDay defaultTime = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: 0,
    );

    // Avoid duplicate times
    while (widget.timeSlots.any((slot) =>
        slot.time.hour == defaultTime.hour &&
        slot.time.minute == defaultTime.minute)) {
      defaultTime = TimeOfDay(
        hour: (defaultTime.hour + 1) % 24,
        minute: defaultTime.minute,
      );
    }

    final newSlot = TimeSlot(
      time: defaultTime,
      description: null,
    );

    final updatedSlots = [...widget.timeSlots, newSlot];
    widget.onTimeSlotsChanged(updatedSlots);

    // Scroll to show new slot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeTimeSlot(String timeSlotId) {
    HapticFeedback.lightImpact();

    final updatedSlots =
        widget.timeSlots.where((slot) => slot.id != timeSlotId).toList();

    widget.onTimeSlotsChanged(updatedSlots);

    // Remove validation error if exists
    setState(() {
      _validationErrors.remove(timeSlotId);
    });

    // If no slots left, switch back to single time mode
    if (updatedSlots.isEmpty && widget.showToggleButton) {
      widget.onMultiTimeToggle(false);
    }
  }

  // Simplified inline time editing
  Future<void> _editTimeSlotInline(TimeSlot timeSlot) async {
    final result = await showTimePicker(
      context: context,
      initialTime: timeSlot.time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      HapticFeedback.selectionClick();

      final updatedSlots = widget.timeSlots.map((slot) {
        return slot.id == timeSlot.id ? slot.copyWith(time: result) : slot;
      }).toList();

      widget.onTimeSlotsChanged(updatedSlots);

      // Clear validation error for this slot
      setState(() {
        _validationErrors.remove(timeSlot.id);
      });
    }
  }

  void _showMaxSlotsReachedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.maxTimeSlots} time slots allowed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _validateTimeSlots() {
    _validationErrors.clear();

    // Check for duplicate times
    final timeMap = <String, List<TimeSlot>>{};
    for (final slot in widget.timeSlots) {
      final timeKey = '${slot.time.hour}:${slot.time.minute}';
      timeMap[timeKey] = (timeMap[timeKey] ?? [])..add(slot);
    }

    for (final entry in timeMap.entries) {
      if (entry.value.length > 1) {
        for (final slot in entry.value) {
          _validationErrors[slot.id] = 'Duplicate time';
        }
      }
    }

    return _validationErrors.isEmpty;
  }

  Widget _buildSingleTimeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.singleTimeLabel ?? 'Time',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectSingleTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentSingleTime.format(context),
                    style: Theme.of(context).textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.edit,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),

        // IMPROVED: Multi-time option positioned below single time
        if (widget.showToggleButton) ...[
          const SizedBox(height: 16),
          _buildMultiTimeToggle(),
        ],
      ],
    );
  }

  // NEW: Subtle toggle option below single time
  Widget _buildMultiTimeToggle() {
    return GestureDetector(
      onTap: _toggleMultiTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Add multiple times',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // IMPROVED: Simplified time slot design
  Widget _buildTimeSlotChip(TimeSlot timeSlot) {
    final hasError = _validationErrors.containsKey(timeSlot.id);

    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editTimeSlotInline(timeSlot),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasError
                  ? Colors.red.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.surfaceContainer,
              border: hasError
                  ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                  : null,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeSlot.formattedTime,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: hasError
                            ? Colors.red.shade700
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _removeTimeSlot(timeSlot.id),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: hasError
                        ? Colors.red.shade700
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiTimeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Multiple Times',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            if (widget.showToggleButton)
              TextButton.icon(
                onPressed: _toggleMultiTime,
                icon: const Icon(Icons.remove, size: 16),
                label: const Text('Single Time'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // IMPROVED: Chip-based time slots layout
        if (widget.timeSlots.isNotEmpty) ...[
          Wrap(
            children: widget.timeSlots
                .map((slot) => _buildTimeSlotChip(slot))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.timeSlots.length < widget.maxTimeSlots)
          GestureDetector(
            onTap: _addTimeSlot,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.addButtonText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),

        // Summary
        if (widget.timeSlots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${widget.timeSlots.length} time${widget.timeSlots.length == 1 ? '' : 's'} scheduled',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Validate time slots
    _validateTimeSlots();

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        padding: widget.padding,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: widget.isMultiTime
              ? _buildMultiTimeView()
              : _buildSingleTimeView(),
        ),
      ),
    );
  }
}

/// Compact version for use in modals or tight spaces
class CompactMultiTimeSection extends StatelessWidget {
  final List<TimeSlot> timeSlots;
  final ValueChanged<List<TimeSlot>> onTimeSlotsChanged;
  final bool isMultiTime;
  final ValueChanged<bool> onMultiTimeToggle;
  final TimeOfDay? initialSingleTime;

  const CompactMultiTimeSection({
    super.key,
    required this.timeSlots,
    required this.onTimeSlotsChanged,
    required this.isMultiTime,
    required this.onMultiTimeToggle,
    this.initialSingleTime,
  });

  @override
  Widget build(BuildContext context) {
    return MultiTimeSection(
      timeSlots: timeSlots,
      onTimeSlotsChanged: onTimeSlotsChanged,
      isMultiTime: isMultiTime,
      onMultiTimeToggle: onMultiTimeToggle,
      initialSingleTime: initialSingleTime,
      onSingleTimeChanged: null,
      isCompact: true,
      padding: const EdgeInsets.all(12),
      addButtonText: 'Add Time',
      maxTimeSlots: 8, // Reduced for compact version
    );
  }
}
