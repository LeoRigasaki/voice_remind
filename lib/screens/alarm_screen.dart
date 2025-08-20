// [lib/screens]/alarm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/reminder.dart';
import '../services/alarm_service.dart';
import '../services/storage_service.dart';

class AlarmScreen extends StatefulWidget {
  final Reminder reminder;
  final VoidCallback? onDismissed;
  final VoidCallback? onSnoozed;

  const AlarmScreen({
    super.key,
    required this.reminder,
    this.onDismissed,
    this.onSnoozed,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  static bool _isAnyAlarmScreenActive = false;

  Timer? _currentTimeTimer;
  Timer? _autoSnoozeTimer; // Auto-snooze timer
  DateTime _currentTime = DateTime.now();
  bool _isDismissing = false;
  bool _isSnoozing = false;
  bool _systemUISetup = false;
  bool _isAutoSnoozed = false; // Track if auto-snoozed

  int _snoozeMinutes = 10;
  int _remainingSeconds = 30; // Countdown for auto-snooze

  @override
  void initState() {
    super.initState();

    // Simple duplicate prevention
    if (_isAnyAlarmScreenActive) {
      debugPrint('⚠️ Another alarm screen is active - closing this one');
      Future.delayed(Duration.zero, () {
        if (mounted) {
          SystemNavigator.pop();
        }
      });
      return;
    }

    // Mark as active
    _isAnyAlarmScreenActive = true;

    _setupAnimations();
    _startCurrentTimeTimer();
    _loadDefaultSnooze();
    _startAutoSnoozeTimer();

    debugPrint('🖥️ Alarm screen activated for: ${widget.reminder.title}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_systemUISetup) {
      _setupSystemUI();
      _systemUISetup = true;
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  void _setupSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: const Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _startCurrentTimeTimer() {
    _currentTimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          setState(() {
            _currentTime = DateTime.now();
          });
        }
      },
    );
  }

  // Auto-snooze timer implementation
  void _startAutoSnoozeTimer() {
    _autoSnoozeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted && !_isDismissing && !_isSnoozing) {
          setState(() {
            _remainingSeconds--;
          });

          if (_remainingSeconds <= 0) {
            timer.cancel();
            _handleAutoSnooze();
          }
        }
      },
    );
  }

  Future<void> _handleAutoSnooze() async {
    if (_isDismissing || _isSnoozing || _isAutoSnoozed) return;

    setState(() {
      _isAutoSnoozed = true;
      _isSnoozing = true;
    });

    try {
      debugPrint('⏰ Auto-snoozing alarm after 30 seconds');

      await AlarmService.snoozeAlarm(
          widget.reminder.id, const Duration(minutes: 10));

      // Clear tracking
      _isAnyAlarmScreenActive = false;

      widget.onSnoozed?.call();

      if (mounted) {
        debugPrint('🖥️ Auto-snooze completed - closing alarm screen');
        SystemNavigator.pop();
      }
    } catch (e) {
      debugPrint('⚠️ Error auto-snoozing alarm: $e');
    }
  }

  Future<void> _loadDefaultSnooze() async {
    final snoozeConfig = await StorageService.getSnoozeConfiguration();
    final useCustom = snoozeConfig['useCustom'] as bool;
    final customMinutes = snoozeConfig['customMinutes'] as int;

    setState(() {
      _snoozeMinutes = useCustom ? customMinutes : 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button from opening main app
      onWillPop: () async {
        // Instead of going back, dismiss the alarm
        if (!_isDismissing && !_isSnoozing) {
          _handleDismiss();
        }
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        body: Container(
          decoration: _buildGradientBackground(),
          child: SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildMainContent()),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF000000),
          const Color(0xFF1A1A1A),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            DateFormat('HH:mm').format(_currentTime),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -4,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMMM d').format(_currentTime),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
          ),
          // Auto-snooze countdown
          if (!_isDismissing && !_isSnoozing && !_isAutoSnoozed) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: Text(
                'Auto-snooze in ${_remainingSeconds}s',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: const Icon(
                  Icons.alarm,
                  size: 80,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          Text(
            widget.reminder.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (widget.reminder.description?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(
              widget.reminder.description!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Scheduled for ${DateFormat('h:mm a').format(widget.reminder.scheduledTime)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _isDismissing || _isSnoozing ? null : _handleDismiss,
            backgroundColor: Colors.white.withOpacity(0.2),
            elevation: 0,
            shape: const CircleBorder(),
            child: _isDismissing
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Icon(
                    Icons.close,
                    size: 40,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.white, size: 40),
                onPressed: _snoozeMinutes > 1
                    ? () {
                        HapticFeedback.lightImpact();
                        setState(() => _snoozeMinutes--);
                      }
                    : null,
              ),
              Expanded(
                child: TextButton(
                  onPressed: _isSnoozing || _isDismissing
                      ? null
                      : () => _handleSnooze(Duration(minutes: _snoozeMinutes)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: _isSnoozing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Snooze $_snoozeMinutes mins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.white, size: 40),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _snoozeMinutes++);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleSnooze(Duration duration) async {
    if (_isSnoozing || _isDismissing) return;

    setState(() => _isSnoozing = true);

    try {
      HapticFeedback.mediumImpact();

      await AlarmService.snoozeAlarm(widget.reminder.id, duration);

      // Clear tracking
      _isAnyAlarmScreenActive = false;

      widget.onSnoozed?.call();

      if (mounted) {
        debugPrint('🖥️ Snooze completed - closing alarm screen');
        SystemNavigator.pop();
      }
    } catch (e) {
      debugPrint('⚠️ Error snoozing alarm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to snooze alarm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSnoozing = false);
      }
    }
  }

  Future<void> _handleDismiss() async {
    if (_isDismissing || _isSnoozing) return;

    setState(() => _isDismissing = true);

    try {
      HapticFeedback.mediumImpact();

      await AlarmService.dismissAlarm(widget.reminder.id);

      // Clear tracking
      _isAnyAlarmScreenActive = false;

      widget.onDismissed?.call();

      if (mounted) {
        debugPrint('🖥️ Dismiss completed - closing alarm screen');
        SystemNavigator.pop();
      }
    } catch (e) {
      debugPrint('⚠️ Error dismissing alarm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss alarm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDismissing = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _currentTimeTimer?.cancel();
    _autoSnoozeTimer?.cancel();

    // Clear tracking
    _isAnyAlarmScreenActive = false;

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    debugPrint('🖥️ Alarm screen disposed');

    super.dispose();
  }
}
