// [lib]/main.dart
import 'package:flutter/material.dart';
import 'package:voice_remind/models/reminder.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/spaces_service.dart';
import 'services/calendar_service.dart';
import 'services/theme_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
import 'screens/main_navigation.dart';
import 'services/ai_reminder_service.dart';
import 'services/voice_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/alarm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Method channel for boot reschedule
const MethodChannel _rescheduleChannel =
    MethodChannel('com.example.voice_remind/reschedule');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up method channel handler for boot reschedule
  _rescheduleChannel.setMethodCallHandler((call) async {
    if (call.method == 'rescheduleFromBoot') {
      debugPrint('========================================');
      debugPrint('📞 RECEIVED BOOT RESCHEDULE CALL FROM NATIVE');
      debugPrint('========================================');

      try {
        // Get all pending reminders
        final reminders = await StorageService.getReminders();
        debugPrint('📋 Found ${reminders.length} reminders to check');

        int rescheduled = 0;
        for (final reminder in reminders) {
          if (reminder.status == ReminderStatus.pending &&
              reminder.isNotificationEnabled) {
            final useAlarm =
                await StorageService.getUseAlarmInsteadOfNotification();

            if (useAlarm) {
              await AlarmService.setAlarmReminder(reminder);
            } else {
              await NotificationService.scheduleReminder(reminder);
            }

            rescheduled++;
            debugPrint('✅ Rescheduled: ${reminder.title}');
          }
        }

        debugPrint('========================================');
        debugPrint('✅ BOOT RESCHEDULE COMPLETE: $rescheduled reminders');
        debugPrint('========================================');

        return rescheduled;
      } catch (e, stackTrace) {
        debugPrint('❌ Error during boot reschedule: $e');
        debugPrint('Stack: $stackTrace');
        throw PlatformException(
            code: 'RESCHEDULE_ERROR', message: e.toString());
      }
    }
  });

  // Load environment variables with better error handling
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded');
  } catch (e) {
    debugPrint(
        '⚠️ No .env file found, will rely on user-provided keys if needed');
  }

  // Initialize storage first (required for AI service to load user keys)
  await StorageService.initialize();
  debugPrint('✅ Storage service initialized');

  // Initialize AI service with proper user key loading
  await _initializeAIService();

  // CRITICAL: Initialize NotificationService FIRST (includes action listeners)
  await NotificationService.initialize();
  debugPrint('✅ Notification service initialized');

  // CRITICAL: Initialize notification action listeners
  await NotificationService.initializeActionListeners();
  debugPrint('✅ Notification action listeners initialized');

  await NotificationService.checkAndReinitializeAfterBoot();

  // Request full-screen intent permission for alarms (Android 10+)
  await NotificationService.requestFullScreenPermission();
  debugPrint('✅ Full-screen permission requested');

  // Then initialize AlarmService (depends on NotificationService)
  await _initializeAlarmService();

  // Initialize spaces service
  await SpacesService.initialize();
  debugPrint('✅ Spaces service initialized');

  // Initialize calendar service
  await CalendarService.initialize();
  debugPrint('✅ Calendar service initialized');

  // Initialize theme service
  await ThemeService.initialize();
  debugPrint('✅ Theme service initialized');

  // Initialize voice service
  await _initializeVoiceService();

  // Check if device was rebooted - reschedule all alarms if needed
  await _handleBootReschedule();

  runApp(const VoiceRemindApp());
}

Future<void> _rescheduleAllPendingReminders() async {
  try {
    debugPrint('🔄 ========================================');
    debugPrint('🔄 CHECKING FOR PENDING REMINDERS TO RESCHEDULE');
    debugPrint('🔄 ========================================');

    final reminders = await StorageService.getReminders();
    final now = DateTime.now();

    // CRITICAL FIX: Include ALL pending reminders, even if overdue
    // For repeating reminders that became overdue, we need to reschedule them
    final pendingReminders = reminders
        .where(
            (r) => r.status == ReminderStatus.pending && r.isNotificationEnabled
            // Removed: r.scheduledTime.isAfter(now) - reschedule even overdue ones
            )
        .toList();

    debugPrint('📋 Found ${pendingReminders.length} pending reminders');

    if (pendingReminders.isEmpty) {
      debugPrint('✅ No pending reminders to reschedule');
      return;
    }

    int rescheduled = 0;
    int missedCount = 0;
    final List<Reminder> missedRecurring = [];

    for (final reminder in pendingReminders) {
      try {
        // For overdue repeating reminders, calculate next occurrence
        DateTime scheduleTime = reminder.scheduledTime;

        if (scheduleTime.isBefore(now) &&
            reminder.repeatType != RepeatType.none) {
          debugPrint(
              '⚠️ Reminder "${reminder.title}" is overdue, calculating next occurrence...');

          missedRecurring.add(reminder);
          missedCount++;

          // Keep adding repeat interval until we get a future date
          while (scheduleTime.isBefore(now)) {
            switch (reminder.repeatType) {
              case RepeatType.daily:
                scheduleTime = scheduleTime.add(const Duration(days: 1));
                break;
              case RepeatType.weekly:
                scheduleTime = scheduleTime.add(const Duration(days: 7));
                break;
              case RepeatType.monthly:
                scheduleTime = DateTime(
                  scheduleTime.year,
                  scheduleTime.month + 1,
                  scheduleTime.day,
                  scheduleTime.hour,
                  scheduleTime.minute,
                );
                break;
              case RepeatType.none:
                break;
            }
          }

          // Update the reminder with the new time
          final updatedReminder = reminder.copyWith(
            scheduledTime: scheduleTime,
            updatedAt: DateTime.now(),
          );

          await StorageService.updateReminder(updatedReminder);
          await NotificationService.scheduleReminder(updatedReminder);

          debugPrint(
              '✅ Rescheduled (missed recurring): ${reminder.title} @ $scheduleTime');
        } else {
          // Not overdue, just reschedule as-is
          await NotificationService.scheduleReminder(reminder);
          debugPrint(
              '✅ Rescheduled: ${reminder.title} @ ${reminder.scheduledTime}');
        }

        rescheduled++;
      } catch (e) {
        debugPrint('❌ Failed to reschedule ${reminder.title}: $e');
      }
    }

    debugPrint('🔄 ========================================');
    debugPrint(
        '🎉 RESCHEDULE COMPLETE: $rescheduled/${pendingReminders.length}');
    if (missedCount > 0) {
      debugPrint(
          '⚠️ Missed recurring reminders: $missedCount (rescheduled for next occurrence)');
    }
    debugPrint('🔄 ========================================');
  } catch (e) {
    debugPrint('❌ Error rescheduling reminders: $e');
  }
}

/// Handles boot-time alarm rescheduling
Future<void> _handleBootReschedule() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final needsBootReschedule = prefs.getBool('needs_boot_reschedule') ?? false;

    if (needsBootReschedule) {
      debugPrint('🔄 ========================================');
      debugPrint('🔄 BOOT DETECTED - RESCHEDULING ALL ALARMS');
      debugPrint('🔄 ========================================');

      await _rescheduleAllPendingReminders();
      await prefs.setBool('needs_boot_reschedule', false);

      debugPrint('✅ Boot reschedule completed successfully');
      debugPrint('🔄 ========================================');
    } else {
      debugPrint('📱 Normal app launch - checking for pending reminders');
      await _rescheduleAllPendingReminders();
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Error in boot reschedule handler: $e');
    debugPrint('Stack trace: $stackTrace');

    try {
      await _rescheduleAllPendingReminders();
    } catch (fallbackError) {
      debugPrint('❌ Fallback reschedule also failed: $fallbackError');
    }
  }
}

Future<void> _initializeVoiceService() async {
  try {
    debugPrint('🎤 Initializing Voice service...');

    // Check if voice service is available
    final isAvailable = await VoiceService.isAvailable();
    if (!isAvailable) {
      debugPrint('⚠️ Voice service not available - permissions needed');
      return;
    }

    // Initialize voice service
    await VoiceService.initialize();
    debugPrint('✅ Voice service initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Voice service initialization failed: $e');
    debugPrint(
        '💡 Voice features will be disabled until permissions are granted');
    // Don't throw - let the app continue without voice initially
  }
}

Future<void> _initializeAIService() async {
  try {
    debugPrint('🔄 Initializing AI service...');

    // Try to initialize with user-stored keys first
    final selectedProvider = await StorageService.getSelectedAIProvider();

    if (selectedProvider != null && selectedProvider != 'none') {
      debugPrint('📱 Found user provider: $selectedProvider');

      String? userApiKey;
      if (selectedProvider == 'gemini') {
        userApiKey = await StorageService.getGeminiApiKey();
      } else if (selectedProvider == 'groq') {
        userApiKey = await StorageService.getGroqApiKey();
      }

      if (userApiKey != null && userApiKey.isNotEmpty) {
        debugPrint('🔑 Found user API key for $selectedProvider');
        await AIReminderService.initialize(
            customApiKey: userApiKey, provider: selectedProvider);
        debugPrint('✅ AI Service initialized with user $selectedProvider key');
        return;
      } else {
        debugPrint('⚠️ User selected $selectedProvider but no API key found');
      }
    }

    // Fallback to environment variables if no user keys
    debugPrint('🔄 Falling back to environment variables...');

    // Try Gemini from environment
    String? envApiKey = dotenv.env['GEMINI_API_KEY'];
    if (envApiKey != null && envApiKey.isNotEmpty) {
      debugPrint('🔑 Found Gemini key in environment');
      await AIReminderService.initialize(
          customApiKey: envApiKey, provider: 'gemini');
      debugPrint('✅ AI Service initialized with environment Gemini key');
      return;
    }

    // Try Groq from environment
    envApiKey = dotenv.env['GROQ_API_KEY'];
    if (envApiKey != null && envApiKey.isNotEmpty) {
      debugPrint('🔑 Found Groq key in environment');
      await AIReminderService.initialize(
          customApiKey: envApiKey, provider: 'groq');
      debugPrint('✅ AI Service initialized with environment Groq key');
      return;
    }

    // No keys found anywhere
    debugPrint('⚠️ No AI API keys found - AI features will be disabled');
    debugPrint(
        '💡 Users can configure API keys in Settings > AI Configuration');
  } catch (e) {
    debugPrint('❌ AI Service initialization failed: $e');
    debugPrint(
        '💡 Users can configure API keys in Settings > AI Configuration');
    // Don't throw - let the app continue without AI initially
  }
}

Future<void> _initializeAlarmService() async {
  try {
    debugPrint('⏰ Initializing Alarm service with awesome_notifications...');

    // Initialize alarm service (no more Alarm.init())
    await AlarmService.initialize();
    debugPrint('✅ Alarm service initialized successfully');
  } catch (e) {
    debugPrint('⚠️ Alarm service initialization failed: $e');
    debugPrint('💡 Alarm features will be disabled until resolved');
    // Don't throw - let the app continue without alarms initially
  }
}

// Helper function for reinitializing AI when users change settings
Future<void> reinitializeAIWithCustomKey(String apiKey, String provider) async {
  try {
    await AIReminderService.initialize(
        customApiKey: apiKey, provider: provider);
    debugPrint('✅ AI Service reinitialized with custom $provider key');
  } catch (e) {
    debugPrint('❌ Failed to initialize with custom key: $e');
    rethrow;
  }
}

class VoiceRemindApp extends StatefulWidget {
  const VoiceRemindApp({super.key});

  @override
  State<VoiceRemindApp> createState() => _VoiceRemindAppState();
}

class _VoiceRemindAppState extends State<VoiceRemindApp>
    with WidgetsBindingObserver {
  // Current theme mode for the app
  ThemeMode _themeMode = ThemeMode.system;
  late final GlobalKey<NavigatorState> _navigatorKey;

  // Enhanced lifecycle management
  AppLifecycleState? _lastLifecycleState;
  Timer? _backgroundUpdateChecker;
  bool _isAppInBackground = false;

  @override
  void initState() {
    super.initState();
    _navigatorKey = GlobalKey<NavigatorState>();
    WidgetsBinding.instance.addObserver(this);

    // Listen to theme changes
    _setupThemeListener();

    // Perform auto update check
    _performAutoUpdateCheck();

    // Start enhanced background update monitoring
    _startBackgroundUpdateMonitoring();
  }

  /// Force refresh all reminder data when critical updates occur
  Future<void> _forceCompleteRefresh() async {
    try {
      debugPrint('🔄 Force complete refresh initiated');

      // Multiple refresh strategies
      await StorageService.forceImmediateRefresh();
      await StorageService.refreshData();

      // Additional delayed refresh for any missed updates
      Timer(const Duration(milliseconds: 300), () async {
        await StorageService.checkForBackgroundUpdates();
      });

      debugPrint('🔄 Force complete refresh completed');
    } catch (e) {
      debugPrint('⚠️ Error in force complete refresh: $e');
    }
  }

  void _setupThemeListener() {
    // Set initial theme
    _themeMode = ThemeService.getThemeMode();

    // Listen for theme changes
    ThemeService.themeStream.listen((themeType) {
      if (mounted) {
        setState(() {
          _themeMode = ThemeService.getThemeMode();
        });
      }
    });
  }

  void _startBackgroundUpdateMonitoring() {
    _backgroundUpdateChecker = Timer.periodic(
      const Duration(seconds: 5), // More frequent monitoring
      (timer) async {
        if (!_isAppInBackground) {
          try {
            final hasUpdates = await StorageService.checkForBackgroundUpdates();
            if (hasUpdates) {
              debugPrint('🔄 Background update detected via active monitoring');
              await _forceCompleteRefresh();
            }
          } catch (e) {
            debugPrint('⚠️ Error in background update monitoring: $e');
          }
        }
      },
    );
  }

  Future<void> _performAutoUpdateCheck() async {
    try {
      // Wait a bit for the app to fully load
      await Future.delayed(const Duration(seconds: 2));

      final updateResult = await UpdateService.autoCheckForUpdates();

      if (updateResult != null &&
          updateResult.success &&
          updateResult.isUpdateAvailable &&
          _navigatorKey.currentContext != null) {
        // Show update dialog if update is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_navigatorKey.currentContext != null) {
            UpdateDialog.show(
              _navigatorKey.currentContext!,
              updateResult,
              isManualCheck: false,
            );
          }
        });
      }
    } catch (e) {
      // Silently handle auto-check errors
      debugPrint('Auto update check failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundUpdateChecker?.cancel();

    // Dispose services when app is closed
    StorageService.dispose();
    ThemeService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('📱 App lifecycle: $_lastLifecycleState → $state');

    // Handle app state changes
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }

    _lastLifecycleState = state;
  }

  void _handleAppResumed() async {
    debugPrint('📱 App resumed - refreshing data');
    _isAppInBackground = false;

    // Enhanced background update detection
    try {
      final hasBackgroundUpdates =
          await StorageService.checkForBackgroundUpdates();

      if (_lastLifecycleState == AppLifecycleState.paused ||
          _lastLifecycleState == AppLifecycleState.hidden) {
        debugPrint('📱 Coming from background - forcing complete refresh');
        await StorageService.forceRefreshFromBackgroundUpdate();
        await StorageService.forceImmediateRefresh();
      }

      // Delayed refresh for race conditions
      Timer(const Duration(milliseconds: 200), () async {
        await StorageService.checkForBackgroundUpdates();
      });

      if (hasBackgroundUpdates) {
        debugPrint('✅ Background updates processed successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Error in app resume handling: $e');
    }

    // Normal resume activities
    StorageService.refreshData();
    _reinitializeAIOnResume();
    _performAutoUpdateCheck();
  }

  void _handleAppPaused() {
    debugPrint('📱 App paused');
    _isAppInBackground = true;
  }

  void _handleAppInactive() {
    debugPrint('📱 App inactive');
    // Don't set background flag for inactive state as it's transitional
  }

  void _handleAppDetached() {
    debugPrint('📱 App detached');
    _isAppInBackground = true;
  }

  void _handleAppHidden() {
    debugPrint('📱 App hidden');
    _isAppInBackground = true;
  }

  Future<void> _reinitializeAIOnResume() async {
    try {
      // Check if AI configuration might have changed and reinitialize
      final currentProvider = await StorageService.getSelectedAIProvider();
      if (currentProvider != null && currentProvider != 'none') {
        // Only reinitialize if we're not already using the right provider
        if (AIReminderService.currentProvider != currentProvider) {
          debugPrint('🔄 Reinitializing AI service on app resume...');
          await _initializeAIService();
        }
      }
    } catch (e) {
      debugPrint('Failed to reinitialize AI on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'VoiceRemind',
      debugShowCheckedModeBanner: false,
      theme: _buildNothingLightTheme(),
      darkTheme: _buildNothingDarkTheme(),
      themeMode: _themeMode,
      home: const MainNavigation(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling, // Prevent text scaling issues
          ),
          child: child!,
        );
      },
    );
  }

  // Nothing-inspired Light Theme (Your original - kept intact!)
  ThemeData _buildNothingLightTheme() {
    const nothingWhite = Color(0xFFFAFAFA);
    const nothingBlack = Color(0xFF0A0A0A);
    const nothingGray = Color(0xFF8E8E93);
    const nothingLightGray = Color(0xFFF2F2F7);
    const nothingRed = Color(0xFFFF3B30);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Nothing-inspired color scheme
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: nothingBlack,
        onPrimary: nothingWhite,
        secondary: nothingGray,
        onSecondary: nothingWhite,
        error: nothingRed,
        onError: nothingWhite,
        surface: nothingWhite,
        onSurface: nothingBlack,
        surfaceContainerHighest: nothingLightGray,
        outline: nothingGray,
        outlineVariant: Color(0xFFE5E5EA),
      ),

      // Clean, minimal typography (Nothing style)
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          letterSpacing: -1.0,
          height: 1.1,
          color: nothingBlack,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          height: 1.2,
          color: nothingBlack,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          height: 1.3,
          color: nothingBlack,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.0,
          height: 1.4,
          color: nothingBlack,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: nothingBlack,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
          height: 1.4,
          color: nothingGray,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          height: 1.3,
          color: nothingGray,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: nothingBlack,
        ),
      ),

      // Clean button design
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: nothingBlack,
          foregroundColor: nothingWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // Minimal input design
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: nothingGray,
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: nothingGray,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: nothingBlack,
            width: 1.0,
          ),
        ),
        filled: true,
        fillColor: nothingLightGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(
          color: nothingGray,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: const TextStyle(
          color: nothingGray,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Clean app bar
      appBarTheme: const AppBarTheme(
        backgroundColor: nothingWhite,
        foregroundColor: nothingBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: nothingBlack,
          fontSize: 24,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: nothingBlack,
          size: 24,
        ),
      ),

      // Clean scaffold
      scaffoldBackgroundColor: nothingWhite,
    );
  }

  // Nothing-inspired Dark Theme (Your original - kept intact!)
  ThemeData _buildNothingDarkTheme() {
    const nothingBlack = Color(0xFF0A0A0A);
    const nothingWhite = Color(0xFFFAFAFA);
    const nothingDarkGray = Color(0xFF1C1C1E);
    const nothingGray = Color(0xFF8E8E93);
    const nothingLightGray = Color(0xFF2C2C2E);
    const nothingRed = Color(0xFFFF453A);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Nothing-inspired dark color scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: nothingWhite,
        onPrimary: nothingBlack,
        secondary: nothingGray,
        onSecondary: nothingBlack,
        error: nothingRed,
        onError: nothingBlack,
        surface: nothingBlack,
        onSurface: nothingWhite,
        surfaceContainerHighest: nothingLightGray,
        outline: nothingGray,
        outlineVariant: Color(0xFF3A3A3C),
      ),

      // Clean, minimal typography (Nothing style)
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          letterSpacing: -1.0,
          height: 1.1,
          color: nothingWhite,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          height: 1.2,
          color: nothingWhite,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          height: 1.3,
          color: nothingWhite,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.0,
          height: 1.4,
          color: nothingWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: nothingWhite,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
          height: 1.4,
          color: nothingGray,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          height: 1.3,
          color: nothingGray,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: nothingWhite,
        ),
      ),

      // Clean button design
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: nothingWhite,
          foregroundColor: nothingBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // Minimal input design
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF3A3A3C),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF3A3A3C),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: nothingWhite,
            width: 1.0,
          ),
        ),
        filled: true,
        fillColor: nothingDarkGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(
          color: nothingGray,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: const TextStyle(
          color: nothingGray,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Clean app bar
      appBarTheme: const AppBarTheme(
        backgroundColor: nothingBlack,
        foregroundColor: nothingWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: nothingWhite,
          fontSize: 24,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(
          color: nothingWhite,
          size: 24,
        ),
      ),

      // Clean scaffold
      scaffoldBackgroundColor: nothingBlack,
    );
  }
}
