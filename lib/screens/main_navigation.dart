// lib/screens/main_navigation.dart
import 'package:flutter/material.dart';
import '../widgets/floating_nav_bar.dart';
import '../services/theme_service.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'spaces_screen.dart';
import '../widgets/ai_add_reminder_modal.dart';
import 'calendar_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  NavTab _currentTab = NavTab.home;

  @override
  void initState() {
    super.initState();
    // Listen to theme changes to rebuild the navigation
    ThemeService.themeStream.listen((_) {
      if (mounted) {
        setState(() {
          // Force rebuild when theme changes
        });
      }
    });
  }

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
        return const CalendarScreen();
      case NavTab.add:
        // This won't be shown as add opens a modal
        return const HomeScreen();
      case NavTab.spaces:
        return const SpacesScreen();
      case NavTab.settings:
        // Pass isFromNavbar: true when accessed via navbar
        return const SettingsScreen(isFromNavbar: true);
    }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return const AIAddReminderModal();
      },
    ).then((_) {
      // Refresh the home screen when returning from add reminder
      if (_currentTab == NavTab.home) {
        setState(() {});
      }
    });
  }
}
