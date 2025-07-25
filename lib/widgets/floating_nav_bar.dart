import 'package:flutter/material.dart';
import 'dart:ui';

enum NavTab { home, calendar, add, spaces, settings }

class FloatingNavBar extends StatefulWidget {
  final NavTab currentTab;
  final ValueChanged<NavTab> onTabChanged;

  const FloatingNavBar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didUpdateWidget(FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab != widget.currentTab) {
      _slideController.forward();
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Enhanced responsive sizing
    final navBarHeight = _getResponsiveHeight(screenWidth);
    final horizontalPadding = _getHorizontalPadding(screenWidth);
    final showLabels = _shouldShowLabels(screenWidth);
    final iconSize = _getIconSize(screenWidth);
    final fontSize = _getFontSize(screenWidth);

    return Container(
      margin: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        bottomPadding > 0 ? 8 : 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_getBorderRadius(screenWidth)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: navBarHeight,
            decoration: BoxDecoration(
              color: _getNavBarColor(isDark),
              borderRadius:
                  BorderRadius.circular(_getBorderRadius(screenWidth)),
              border: Border.all(
                color: _getBorderColor(isDark),
                width: 0.5,
              ),
              boxShadow: _getBoxShadows(isDark),
            ),
            child: Stack(
              children: [
                // Animated background indicator
                AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return _buildActiveIndicator(
                        context, screenWidth, showLabels, isDark);
                  },
                ),
                // Navigation items
                Row(
                  children: [
                    _buildNavItem(
                      context,
                      NavTab.home,
                      Icons.home_outlined,
                      Icons.home,
                      'Home',
                      showLabels,
                      iconSize,
                      fontSize,
                      isDark,
                    ),
                    _buildNavItem(
                      context,
                      NavTab.calendar,
                      Icons.calendar_today_outlined,
                      Icons.calendar_today,
                      'Calendar',
                      showLabels,
                      iconSize,
                      fontSize,
                      isDark,
                    ),
                    _buildCenterAddButton(context, iconSize, isDark),
                    _buildNavItem(
                      context,
                      NavTab.spaces,
                      Icons.apps_outlined,
                      Icons.apps,
                      'Spaces',
                      showLabels,
                      iconSize,
                      fontSize,
                      isDark,
                    ),
                    _buildNavItem(
                      context,
                      NavTab.settings,
                      Icons.settings_outlined,
                      Icons.settings,
                      'Settings',
                      showLabels,
                      iconSize,
                      fontSize,
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveIndicator(
      BuildContext context, double screenWidth, bool showLabels, bool isDark) {
    final itemWidth = _calculateItemWidth(screenWidth);
    final indicatorLeft = _calculateIndicatorPosition(itemWidth);
    final indicatorHeight = _getIndicatorHeight(screenWidth);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      left: indicatorLeft,
      top: (72 - indicatorHeight) / 2, // Center vertically
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_scaleAnimation.value * 0.1),
            child: Container(
              width: itemWidth - 8,
              height: indicatorHeight,
              decoration: BoxDecoration(
                color: _getIndicatorColor(isDark),
                borderRadius: BorderRadius.circular(indicatorHeight / 2),
                border: Border.all(
                  color: _getIndicatorBorderColor(isDark),
                  width: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavTab tab,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
    bool showLabels,
    double iconSize,
    double fontSize,
    bool isDark,
  ) {
    final isActive = widget.currentTab == tab;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => widget.onTabChanged(tab),
          child: Container(
            height: 72,
            padding: EdgeInsets.symmetric(
              horizontal: _getItemPadding(MediaQuery.of(context).size.width),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with smooth transition
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    isActive ? activeIcon : inactiveIcon,
                    key: ValueKey('${tab.name}_${isActive}'),
                    size: iconSize,
                    color: _getIconColor(isActive, isDark),
                  ),
                ),

                // Label with conditional visibility and responsive sizing
                if (showLabels) ...[
                  SizedBox(
                      height:
                          _getLabelSpacing(MediaQuery.of(context).size.width)),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: _getTextColor(isActive, isDark),
                      letterSpacing: 0.5,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(
      BuildContext context, double iconSize, bool isDark) {
    final isActive = widget.currentTab == NavTab.add;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = _getAddButtonSize(screenWidth);

    return Expanded(
      child: Container(
        height: 72,
        padding: EdgeInsets.all(_getAddButtonPadding(screenWidth)),
        child: AnimatedScale(
          scale: isActive ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(buttonSize / 2),
              onTap: () => widget.onTabChanged(NavTab.add),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: _getAddButtonColor(isDark),
                  borderRadius: BorderRadius.circular(buttonSize / 2),
                  boxShadow: [
                    BoxShadow(
                      color: _getAddButtonShadowColor(isDark),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: iconSize + 4, // Slightly larger for add button
                  color: _getAddButtonIconColor(isDark),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Responsive helper methods
  double _getResponsiveHeight(double screenWidth) {
    if (screenWidth < 320) return 64.0;
    if (screenWidth < 400) return 68.0;
    return 72.0;
  }

  double _getHorizontalPadding(double screenWidth) {
    if (screenWidth < 320) return 12.0;
    if (screenWidth < 400) return 16.0;
    if (screenWidth > 500) return 24.0;
    return 20.0;
  }

  bool _shouldShowLabels(double screenWidth) {
    return screenWidth >= 320; // More aggressive - show labels on most phones
  }

  double _getIconSize(double screenWidth) {
    if (screenWidth < 320) return 20.0;
    if (screenWidth < 400) return 22.0;
    return 24.0;
  }

  double _getFontSize(double screenWidth) {
    if (screenWidth < 320) return 8.0;
    if (screenWidth < 400) return 9.0;
    return 10.0;
  }

  double _getBorderRadius(double screenWidth) {
    if (screenWidth < 400) return 32.0;
    return 36.0;
  }

  double _getItemPadding(double screenWidth) {
    if (screenWidth < 320) return 2.0;
    return 4.0;
  }

  double _getLabelSpacing(double screenWidth) {
    if (screenWidth < 400) return 2.0;
    return 4.0;
  }

  double _getAddButtonSize(double screenWidth) {
    if (screenWidth < 320) return 44.0;
    if (screenWidth < 400) return 48.0;
    return 50.0;
  }

  double _getAddButtonPadding(double screenWidth) {
    if (screenWidth < 400) return 9.0;
    return 11.0;
  }

  double _getIndicatorHeight(double screenWidth) {
    if (screenWidth < 400) return 52.0;
    return 56.0;
  }

  // Calculation helper methods
  double _calculateItemWidth(double screenWidth) {
    final horizontalPadding = _getHorizontalPadding(screenWidth) * 2;
    return (screenWidth - horizontalPadding) / 5;
  }

  double _calculateIndicatorPosition(double itemWidth) {
    final tabIndex = widget.currentTab.index;
    if (widget.currentTab == NavTab.add) {
      return -100; // Off screen for add button
    }
    return (itemWidth * tabIndex) + 4;
  }

  // Color helper methods - INVERTED COLORS
  Color _getNavBarColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.9) // White in dark mode
        : Colors.black.withValues(alpha: 0.85); // Black in light mode
  }

  Color _getBorderColor(bool isDark) {
    return isDark
        ? Colors.black.withValues(alpha: 0.1) // Dark border in dark mode
        : Colors.white.withValues(alpha: 0.15); // Light border in light mode
  }

  Color _getIndicatorColor(bool isDark) {
    return isDark
        ? Colors.black.withValues(alpha: 0.12) // Dark indicator in dark mode
        : Colors.white.withValues(alpha: 0.12); // Light indicator in light mode
  }

  Color _getIndicatorBorderColor(bool isDark) {
    return isDark
        ? Colors.black.withValues(alpha: 0.2) // Dark border in dark mode
        : Colors.white.withValues(alpha: 0.2); // Light border in light mode
  }

  Color _getIconColor(bool isActive, bool isDark) {
    if (isDark) {
      // Dark mode = white navbar, so use dark icons
      return isActive ? Colors.black : Colors.black.withValues(alpha: 0.7);
    } else {
      // Light mode = black navbar, so use light icons
      return isActive ? Colors.white : Colors.white.withValues(alpha: 0.7);
    }
  }

  Color _getTextColor(bool isActive, bool isDark) {
    if (isDark) {
      // Dark mode = white navbar, so use dark text
      return isActive ? Colors.black : Colors.black.withValues(alpha: 0.7);
    } else {
      // Light mode = black navbar, so use light text
      return isActive ? Colors.white : Colors.white.withValues(alpha: 0.7);
    }
  }

  Color _getAddButtonColor(bool isDark) {
    return isDark
        ? Colors.black // Dark button in dark mode (contrast with white navbar)
        : Colors
            .white; // Light button in light mode (contrast with black navbar)
  }

  Color _getAddButtonIconColor(bool isDark) {
    return isDark
        ? Colors.white // Light icon in dark mode
        : Colors.black; // Dark icon in light mode
  }

  Color _getAddButtonShadowColor(bool isDark) {
    return isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.15);
  }

  List<BoxShadow> _getBoxShadows(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.25),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: isDark
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.1),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
    ];
  }
}
