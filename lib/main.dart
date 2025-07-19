import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/spaces_service.dart';
import 'services/theme_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
import 'screens/main_navigation.dart';

// Global notification plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.initialize();

  // Initialize storage
  await StorageService.initialize();

  // Initialize spaces service
  await SpacesService.initialize();

  // Initialize theme service
  await ThemeService.initialize();

  runApp(const VoiceRemindApp());
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

  @override
  void initState() {
    super.initState();
    _navigatorKey = GlobalKey<NavigatorState>();
    WidgetsBinding.instance.addObserver(this);

    // Listen to theme changes
    _setupThemeListener();

    // Perform auto update check
    _performAutoUpdateCheck();
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
    // Dispose services when app is closed
    StorageService.dispose();
    ThemeService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes back to foreground
      StorageService.refreshData();

      // Check for updates when app comes to foreground
      _performAutoUpdateCheck();
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
