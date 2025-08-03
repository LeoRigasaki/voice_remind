// [lib/widgets]/calendar_event_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../models/reminder.dart';

/// Modern, redesigned calendar event tile with enhanced UI and theme reactivity
class CalendarEventTile extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDragging;
  final bool showTimeInfo;
  final double? width;
  final double? height;

  const CalendarEventTile({
    super.key,
    required this.event,
    this.onTap,
    this.isSelected = false,
    this.isDragging = false,
    this.showTimeInfo = true,
    this.width,
    this.height,
  });

  @override
  State<CalendarEventTile> createState() => _CalendarEventTileState();
}

class _CalendarEventTileState extends State<CalendarEventTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _borderRadiusAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _borderRadiusAnimation = Tween<double>(
      begin: 8.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void didUpdateWidget(CalendarEventTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate when dragging or selection state changes
    if (widget.isDragging || widget.isSelected) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildTileContent(),
        );
      },
    );
  }

  Widget _buildTileContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Material(
              elevation: _elevationAnimation.value,
              borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
              shadowColor:
                  widget.event.color.withValues(alpha: isDark ? 0.3 : 0.2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(_borderRadiusAnimation.value),
                  gradient: _buildGradient(isDark),
                  border: _buildBorder(colorScheme, isDark),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(_borderRadiusAnimation.value),
                  child: _buildTileBody(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  LinearGradient _buildGradient(bool isDark) {
    final baseColor = widget.event.color;
    final isCompleted = widget.event.isCompleted;
    final isSelected = widget.isSelected;

    Color startColor;
    Color endColor;

    if (isCompleted) {
      // Muted gradient for completed items
      startColor = baseColor.withValues(alpha: isDark ? 0.15 : 0.12);
      endColor = baseColor.withValues(alpha: isDark ? 0.08 : 0.06);
    } else if (isSelected) {
      // Vibrant gradient for selected items
      startColor = baseColor.withValues(alpha: isDark ? 0.35 : 0.25);
      endColor = baseColor.withValues(alpha: isDark ? 0.25 : 0.15);
    } else {
      // Standard gradient for normal items
      startColor = baseColor.withValues(alpha: isDark ? 0.25 : 0.18);
      endColor = baseColor.withValues(alpha: isDark ? 0.15 : 0.10);
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: const [0.0, 1.0],
    );
  }

  Border _buildBorder(ColorScheme colorScheme, bool isDark) {
    if (widget.isSelected) {
      return Border.all(
        color: widget.event.color,
        width: 2.0,
      );
    } else if (widget.isDragging) {
      return Border.all(
        color: widget.event.color.withValues(alpha: 0.6),
        width: 1.5,
      );
    } else {
      return Border.all(
        color: widget.event.color.withValues(alpha: isDark ? 0.4 : 0.3),
        width: 1.0,
      );
    }
  }

  Widget _buildTileBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enhanced responsive breakpoints
        final isVerySmall =
            constraints.maxWidth < 70 || constraints.maxHeight < 35;
        final isSmall =
            constraints.maxWidth < 140 || constraints.maxHeight < 55;
        final isMedium =
            constraints.maxWidth < 200 || constraints.maxHeight < 80;

        if (isVerySmall) {
          return _buildMinimalContent();
        } else if (isSmall) {
          return _buildCompactContent();
        } else if (isMedium) {
          return _buildMediumContent(constraints);
        } else {
          return _buildFullContent(constraints);
        }
      },
    );
  }

  Widget _buildMinimalContent() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildStatusIndicator(size: 8),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.event.title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getTextColor(theme),
                decoration: widget.event.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContent() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with status and title
          Row(
            children: [
              _buildStatusIndicator(size: 10),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.event.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(theme),
                    decoration: widget.event.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Time info if space allows
          if (widget.showTimeInfo) ...[
            const SizedBox(height: 4),
            _buildCompactTimeInfo(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildMediumContent(BoxConstraints constraints) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with enhanced styling
          _buildEnhancedHeader(theme),

          // Description if available and space permits
          if (widget.event.description?.isNotEmpty == true &&
              constraints.maxHeight > 65) ...[
            const SizedBox(height: 6),
            _buildDescription(theme),
          ],

          // Footer with time and space info
          if (widget.showTimeInfo && constraints.maxHeight > 50) ...[
            const Spacer(),
            _buildMediumFooter(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildFullContent(BoxConstraints constraints) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced header with all features
          _buildEnhancedHeader(theme),

          // Description with better formatting
          if (widget.event.description?.isNotEmpty == true &&
              constraints.maxHeight > 80) ...[
            const SizedBox(height: 8),
            _buildDescription(theme),
          ],

          // Rich footer with all details
          if (widget.showTimeInfo) ...[
            const Spacer(),
            _buildRichFooter(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({double size = 12}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.event.statusColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.event.statusColor.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: widget.event.isCompleted
          ? Icon(
              Icons.check,
              size: size * 0.7,
              color: Colors.white,
            )
          : null,
    );
  }

  Widget _buildEnhancedHeader(ThemeData theme) {
    return Row(
      children: [
        _buildStatusIndicator(),
        const SizedBox(width: 8),

        Expanded(
          child: Text(
            widget.event.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: _getTextColor(theme),
              decoration:
                  widget.event.isCompleted ? TextDecoration.lineThrough : null,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Space indicator with modern styling
        if (widget.event.spaceName != null) ...[
          const SizedBox(width: 8),
          _buildSpaceChip(theme),
        ],
      ],
    );
  }

  Widget _buildSpaceChip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.event.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.event.color.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        widget.event.spaceName!,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: widget.event.color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDescription(ThemeData theme) {
    return Text(
      widget.event.description!,
      style: theme.textTheme.bodySmall?.copyWith(
        color: _getSecondaryTextColor(theme),
        height: 1.3,
        fontSize: 11,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildCompactTimeInfo(ThemeData theme) {
    return Row(
      children: [
        Icon(
          widget.event.isAllDay ? Icons.today : Icons.access_time,
          size: 10,
          color: _getSecondaryTextColor(theme),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _getTimeText(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getSecondaryTextColor(theme),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMediumFooter(ThemeData theme) {
    return Row(
      children: [
        Icon(
          widget.event.isAllDay ? Icons.today : Icons.access_time,
          size: 12,
          color: _getSecondaryTextColor(theme),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _getTimeText(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getSecondaryTextColor(theme),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.event.repeatType != RepeatType.none) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.repeat,
            size: 12,
            color: _getSecondaryTextColor(theme),
          ),
        ],
      ],
    );
  }

  Widget _buildRichFooter(ThemeData theme) {
    return Row(
      children: [
        // Time section
        Icon(
          widget.event.isAllDay ? Icons.today : Icons.schedule,
          size: 14,
          color: _getSecondaryTextColor(theme),
        ),
        const SizedBox(width: 6),

        Text(
          _getDetailedTimeText(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: _getSecondaryTextColor(theme),
            fontWeight: FontWeight.w500,
          ),
        ),

        const Spacer(),

        // Indicators row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.event.repeatType != RepeatType.none) ...[
              Icon(
                Icons.repeat,
                size: 12,
                color: _getSecondaryTextColor(theme),
              ),
              const SizedBox(width: 4),
            ],
            if (_isOverdue()) ...[
              Icon(
                Icons.warning_rounded,
                size: 12,
                color: theme.colorScheme.error,
              ),
            ],
          ],
        ),
      ],
    );
  }

  // Helper methods for text and colors
  Color _getTextColor(ThemeData theme) {
    if (widget.event.isCompleted) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }
    return theme.colorScheme.onSurface;
  }

  Color _getSecondaryTextColor(ThemeData theme) {
    if (widget.event.isCompleted) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.4);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.7);
  }

  String _getTimeText() {
    if (widget.event.isAllDay) return 'All day';
    return DateFormat.Hm().format(widget.event.startTime);
  }

  String _getDetailedTimeText() {
    if (widget.event.isAllDay) return 'All day';

    final timeFormat = DateFormat.Hm();
    final startTime = timeFormat.format(widget.event.startTime);
    final duration = widget.event.durationText;

    return '$startTime • $duration';
  }

  bool _isOverdue() {
    return !widget.event.isCompleted &&
        widget.event.startTime.isBefore(DateTime.now());
  }
}
