import 'package:flutter/material.dart';

enum NavTab { home, calendar, add, spaces, settings }

class FloatingNavBar extends StatelessWidget {
  final NavTab currentTab;
  final Function(NavTab) onTabChanged;

  const FloatingNavBar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(20),
      height: 72,
      decoration: BoxDecoration(
        //Inverted theme - dark navbar in light mode, light navbar in dark mode
        color: isDark
            ? Colors.white.withValues(alpha: 0.75) // Light navbar in dark mode
            : const Color(0xFF1C1C1E)
                .withValues(alpha: 0.8), // Dark navbar in light mode
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context,
            NavTab.home,
            Icons.home_outlined,
            Icons.home,
            'Home',
          ),
          _buildNavItem(
            context,
            NavTab.calendar,
            Icons.calendar_today_outlined,
            Icons.calendar_today,
            'Calendar',
          ),
          _buildCenterAddButton(context),
          _buildNavItem(
            context,
            NavTab.spaces,
            Icons.apps_outlined,
            Icons.apps,
            'Spaces',
          ),
          _buildNavItem(
            context,
            NavTab.settings,
            Icons.settings_outlined,
            Icons.settings,
            'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavTab tab,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
  ) {
    final isActive = currentTab == tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isComingSoon = tab == NavTab.calendar || tab == NavTab.spaces;

    return GestureDetector(
      onTap: isComingSoon ? null : () => onTabChanged(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with background for active state
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark
                        ? Colors.black.withValues(alpha: 0.12) // Inverted
                        : Colors.white.withValues(alpha: 0.2)) // Inverted
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                size: 20,
                color: isComingSoon
                    ? (isDark
                        ? Colors.black.withValues(alpha: 0.4) // Inverted
                        : Colors.white.withValues(alpha: 0.4)) // Inverted
                    : isActive
                        ? (isDark ? Colors.black : Colors.white) // Inverted
                        : (isDark
                            ? Colors.black.withValues(alpha: 0.8) // Inverted
                            : Colors.white.withValues(alpha: 0.8)), // Inverted
              ),
            ),
            const SizedBox(height: 4),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.5,
                color: isComingSoon
                    ? (isDark
                        ? Colors.black.withValues(alpha: 0.4) // Inverted
                        : Colors.white.withValues(alpha: 0.4)) // Inverted
                    : isActive
                        ? (isDark ? Colors.black : Colors.white) // Inverted
                        : (isDark
                            ? Colors.black.withValues(alpha: 0.8) // Inverted
                            : Colors.white.withValues(alpha: 0.8)), // Inverted
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onTabChanged(NavTab.add),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          // Keep add button the same (contrast with navbar)
          color: isDark ? Colors.white : Colors.black,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: 24,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
        //Removed the annoying grey dot completely
      ),
    );
  }
}
