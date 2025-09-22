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
  bool _isNavBarVisible = true;

  @override
  void initState() {
    super.initState();
    ThemeService.themeStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _showAddReminderModal,
      onDoubleTap: _forceShowNavBar,
      child: Scaffold(
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: _buildCurrentScreen(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: FloatingNavBar(
                  currentTab: _currentTab,
                  onTabChanged: _onTabChanged,
                  isVisible: _isNavBarVisible,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta ?? 0;

      if (scrollDelta > 2 && _isNavBarVisible) {
        setState(() {
          _isNavBarVisible = false;
        });
      } else if (scrollDelta < -2 && !_isNavBarVisible) {
        setState(() {
          _isNavBarVisible = true;
        });
      }

      if (notification.metrics.pixels <= 50 && !_isNavBarVisible) {
        setState(() {
          _isNavBarVisible = true;
        });
      }
    }

    if (notification is ScrollStartNotification) {
      if (notification.metrics.pixels <= 0) {
        setState(() {
          _isNavBarVisible = true;
        });
      }
    }

    return false;
  }

  void _forceShowNavBar() {
    setState(() {
      _isNavBarVisible = true;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_currentTab) {
      case NavTab.home:
        return const HomeScreen();
      case NavTab.calendar:
        return const CalendarScreen();
      case NavTab.add:
        return const HomeScreen();
      case NavTab.spaces:
        return const SpacesScreen();
      case NavTab.settings:
        return const SettingsScreen(isFromNavbar: true);
    }
  }

  void _onTabChanged(NavTab tab) {
    if (tab == NavTab.add) {
      _showAddReminderModal();
    } else {
      setState(() {
        _currentTab = tab;
        _isNavBarVisible = true;
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
      if (_currentTab == NavTab.home && mounted) {
        setState(() {});
      }
    });
  }
}
