import 'package:flutter/material.dart';
import '../widgets/floating_nav_bar.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'add_reminder_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  NavTab _currentTab = NavTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          _buildCurrentScreen(),

          // Floating navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: FloatingNavBar(
                currentTab: _currentTab,
                onTabChanged: _onTabChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentTab) {
      case NavTab.home:
        return const HomeScreen();
      case NavTab.calendar:
        return _buildComingSoonScreen(
            'Calendar', Icons.calendar_today_outlined);
      case NavTab.add:
        // This won't be shown as add opens a modal
        return const HomeScreen();
      case NavTab.spaces:
        return _buildComingSoonScreen('Spaces', Icons.apps_outlined);
      case NavTab.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildComingSoonScreen(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Nothing-style geometric container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.1),
                      width: 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Corner accent
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(24),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      // Dot pattern
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Center icon
                      Center(
                        child: Icon(
                          icon,
                          size: 48,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.0,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.8),
                      ),
                ),
                const SizedBox(height: 12),

                // Coming soon text
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'COMING SOON',
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'This feature is in development.\nStay tuned for updates!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.5),
                        height: 1.5,
                        letterSpacing: 0.3,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onTabChanged(NavTab tab) {
    if (tab == NavTab.add) {
      // Open add reminder as modal instead of changing tab
      _showAddReminderModal();
    } else {
      setState(() {
        _currentTab = tab;
      });
    }
  }

  void _showAddReminderModal() {
    Navigator.of(context)
        .push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddReminderScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Nothing Phone-inspired slide up animation
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
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
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
      ),
    )
        .then((_) {
      // Refresh the home screen when returning from add reminder
      if (_currentTab == NavTab.home) {
        setState(() {});
      }
    });
  }
}
