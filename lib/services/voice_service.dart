import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/reminder.dart';
import 'ai_reminder_service.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

enum VoiceState { idle, recording, processing, completed, error }

class VoiceService {
  static VoiceService? _instance;
  static VoiceService get instance => _instance ??= VoiceService._();
  VoiceService._();

  // Core components
  final SpeechToText _speechToText = SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // State management
  VoiceState _currentState = VoiceState.idle;
  String _currentTranscription = '';
  String? _audioFilePath;

  //  continuous speech handling
  Timer? _sessionRestartTimer;
  Timer? _silenceMonitorTimer;
  bool _hasValidSpeech = false;
  DateTime? _lastSpeechUpdate;
  String _cumulativeTranscription = ''; // Builds up over multiple sessions
  bool _isUserStillSpeaking = false;
  int _sessionCount = 0;
  static const int _maxSessions = 20; // Prevent infinite loops

  // User control
  bool _userRequestedStop = false;

  // Stream controllers for UI updates
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();
  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<List<Reminder>> _resultsController =
      StreamController<List<Reminder>>.broadcast();

  // Available locales
  List<String> _availableLocales = [];
  String _currentLocale = 'en_US';

  // Getters for streams
  Stream<VoiceState> get stateStream => _stateController.stream;
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<List<Reminder>> get resultsStream => _resultsController.stream;

  // Getters for current state
  VoiceState get currentState => _currentState;
  String get currentTranscription => _cumulativeTranscription.isNotEmpty
      ? _cumulativeTranscription
      : _currentTranscription;

  /// Initialize the voice service
  static Future<void> initialize() async {
    debugPrint('🎤 Initializing  VoiceService...');

    try {
      // CRITICAL FIX: Check and request permissions first
      // Wrapped in try-catch to handle Activity not ready scenarios
      try {
        await _checkPermissions();
      } on PlatformException catch (e) {
        if (e.code == 'PermissionHandler.PermissionManager') {
          debugPrint(
            '⚠️ Activity not ready yet, permissions will be checked on first use',
          );
          // Continue initialization, permissions will be requested when user uses voice
        } else {
          rethrow;
        }
      }

      // Initialize speech-to-text with optimal configuration
      final isInitialized = await instance._speechToText.initialize(
        onStatus: instance._handleSpeechStatus,
        onError: instance._handleSpeechError,
        debugLogging: true,
      );

      if (!isInitialized) {
        throw Exception(
          'Failed to initialize speech recognition. Please check device compatibility.',
        );
      }

      // Get available locales
      await instance._loadAvailableLocales();

      debugPrint(
        '✅  VoiceService initialized with ${instance._availableLocales.length} locales',
      );
    } catch (e) {
      debugPrint('❌  VoiceService initialization failed: $e');
      rethrow;
    }
  }

  /// Load available speech recognition locales
  Future<void> _loadAvailableLocales() async {
    try {
      final locales = await _speechToText.locales();
      _availableLocales = locales.map((locale) => locale.localeId).toList();

      // Try to find best locale
      const preferredLocales = ['en_US', 'en_GB', 'en_AU', 'en_CA'];
      for (final preferred in preferredLocales) {
        if (_availableLocales.contains(preferred)) {
          _currentLocale = preferred;
          break;
        }
      }

      if (_availableLocales.isNotEmpty &&
          !_availableLocales.contains(_currentLocale)) {
        _currentLocale = _availableLocales.first;
      }

      debugPrint('📝 Using locale: $_currentLocale');
    } catch (e) {
      debugPrint('⚠️ Could not load locales: $e');
      _currentLocale = 'en_US';
    }
  }

  /// Check and request necessary permissions
  static Future<void> _checkPermissions() async {
    debugPrint('🔐 Checking voice permissions...');

    // CRITICAL: Wait for Activity to be ready before requesting permissions
    // This prevents "Unable to detect current Android Activity" error
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // First check current status (doesn't need Activity)
      final currentMicStatus = await Permission.microphone.status;

      if (currentMicStatus.isGranted) {
        debugPrint('✅ Microphone permission already granted');
      } else {
        // Only request if Activity is available
        final microphoneStatus = await Permission.microphone.request();
        if (!microphoneStatus.isGranted) {
          throw Exception(
            'Microphone permission denied. Please grant microphone access in Settings.',
          );
        }
      }

      // Speech permission is optional on Android
      try {
        final currentSpeechStatus = await Permission.speech.status;
        if (!currentSpeechStatus.isGranted) {
          final speechStatus = await Permission.speech.request();
          if (!speechStatus.isGranted) {
            debugPrint(
              '⚠️ Speech permission not granted, but microphone is available',
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Speech permission check skipped: $e');
      }

      debugPrint('✅ Voice permissions checked');
    } on PlatformException catch (e) {
      if (e.code == 'PermissionHandler.PermissionManager') {
        debugPrint(
          '⚠️ Activity not ready for permission request, will retry later',
        );
        // Don't throw, let it be retried when user actually uses voice features
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  /// Start recording with  continuous support
  Future<void> startRecording() async {
    if (_currentState != VoiceState.idle) {
      debugPrint('⚠️ Cannot start recording: state is ${_currentState.name}');
      return;
    }

    debugPrint('🎤 Starting  Continuous Voice Recording...');
    // Ensure permissions are granted before starting
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        await _checkPermissions();
      }
    } catch (e) {
      debugPrint('❌ Permission check failed: $e');
      _updateState(VoiceState.error);
      return;
    }

    // Reset all state for new recording session
    _resetRecordingState();
    _updateState(VoiceState.recording);

    try {
      // Get current AI provider to determine approach
      final currentProvider =
          await StorageService.getSelectedAIProvider() ?? 'none';

      if (currentProvider == 'gemini') {
        // Gemini: Use audio recording approach
        await _startAudioRecording();
      } else {
        // Groq: Use continuous speech-to-text approach
        await _startContinuousSpeechToText();
      }
    } catch (e) {
      debugPrint('❌ Failed to start recording: $e');
      _updateState(VoiceState.error);
      rethrow;
    }
  }

  /// Reset state for new recording session
  void _resetRecordingState() {
    _currentTranscription = '';
    _cumulativeTranscription = '';
    _hasValidSpeech = false;
    _lastSpeechUpdate = null;
    _isUserStillSpeaking = false;
    _userRequestedStop = false;
    _sessionCount = 0;

    _sessionRestartTimer?.cancel();
    _silenceMonitorTimer?.cancel();
  }

  /// Start continuous speech-to-text with intelligent session management
  Future<void> _startContinuousSpeechToText() async {
    if (!_speechToText.isAvailable) {
      throw Exception('Speech recognition not available on this device');
    }

    debugPrint('📝 Starting Continuous Speech-to-Text...');
    await _startIntelligentSpeechSession();
  }

  // Start an intelligent speech session with auto-restart capability
  Future<void> _startIntelligentSpeechSession() async {
    if (_userRequestedStop || _sessionCount >= _maxSessions) {
      debugPrint('🛑 Session limit reached or user stopped');
      return;
    }

    _sessionCount++;
    debugPrint('🔄 Starting speech session #$_sessionCount');

    try {
      await _speechToText.listen(
        onResult: (result) {
          final newText = result.recognizedWords.trim();
          if (newText.isNotEmpty) {
            _currentTranscription = newText;

            // Update cumulative transcription intelligently
            _updateCumulativeTranscription(newText);

            _transcriptionController.add(_cumulativeTranscription);
            _hasValidSpeech = true;
            _isUserStillSpeaking = true;
            _lastSpeechUpdate = DateTime.now();

            debugPrint('📝 Session #$_sessionCount transcription: "$newText"');
            debugPrint('📝 Cumulative: "$_cumulativeTranscription"');

            // Reset silence monitor since we got new speech
            _startSilenceMonitor();
          }
        },
        localeId: _currentLocale,
        // SETTINGS FOR CONTINUOUS SPEECH:
        listenFor: const Duration(seconds: 30), // Longer initial duration
        pauseFor: const Duration(seconds: 5), // More tolerance for pauses
        partialResults: true, // Show real-time results
        onSoundLevelChange: (level) {
          if (level > 0.1) {
            _isUserStillSpeaking = true;
            _lastSpeechUpdate = DateTime.now();
          }
        },
        cancelOnError: false,
        listenMode: ListenMode.dictation, // Better for longer speech
      );

      // Schedule session restart before Android times out
      _scheduleSessionRestart();
    } catch (e) {
      debugPrint('❌ Error in speech session #$_sessionCount: $e');

      if (!_userRequestedStop && _sessionCount < _maxSessions) {
        debugPrint('🔄 Attempting to restart after error...');
        await Future.delayed(const Duration(milliseconds: 300));
        await _startIntelligentSpeechSession();
      }
    }
  }

  /// Intelligently update cumulative transcription
  void _updateCumulativeTranscription(String newText) {
    if (_cumulativeTranscription.isEmpty) {
      _cumulativeTranscription = newText;
    } else {
      // Smart concatenation - avoid duplicate words
      final existingWords = _cumulativeTranscription.toLowerCase().split(' ');
      final newWords = newText.toLowerCase().split(' ');

      // Find overlap to avoid duplication
      int overlapStart = -1;
      for (int i = 0; i < newWords.length; i++) {
        if (existingWords.isNotEmpty &&
            existingWords.last == newWords[i] &&
            i + 1 < newWords.length) {
          overlapStart = i + 1;
          break;
        }
      }

      if (overlapStart != -1) {
        // Found overlap, append only the new part
        final newPart = newWords.sublist(overlapStart).join(' ');
        if (newPart.isNotEmpty) {
          _cumulativeTranscription += ' $newPart';
        }
      } else {
        // No overlap found, check if it's a completely new sentence
        if (!newText.toLowerCase().startsWith(
              _cumulativeTranscription.toLowerCase(),
            )) {
          _cumulativeTranscription += ' $newText';
        } else {
          // New text contains the old text, replace it
          _cumulativeTranscription = newText;
        }
      }
    }
  }

  /// Schedule session restart before Android timeout
  void _scheduleSessionRestart() {
    _sessionRestartTimer?.cancel();

    // Restart session every 20 seconds to avoid Android timeout
    _sessionRestartTimer = Timer(const Duration(seconds: 20), () async {
      if (_currentState == VoiceState.recording && !_userRequestedStop) {
        debugPrint('Scheduled restart to avoid Android timeout...');

        try {
          await _speechToText.stop();
          await Future.delayed(const Duration(milliseconds: 200));

          if (_currentState == VoiceState.recording && !_userRequestedStop) {
            await _startIntelligentSpeechSession();
          }
        } catch (e) {
          debugPrint('⚠️ Error during scheduled restart: $e');
        }
      }
    });
  }

  /// Monitor silence to detect when user stops speaking
  void _startSilenceMonitor() {
    _silenceMonitorTimer?.cancel();

    _silenceMonitorTimer = Timer(const Duration(seconds: 8), () {
      if (_isUserStillSpeaking && _lastSpeechUpdate != null) {
        final timeSinceLastSpeech = DateTime.now().difference(
          _lastSpeechUpdate!,
        );

        if (timeSinceLastSpeech.inSeconds >= 8) {
          debugPrint(
            '🤫 Extended silence detected, but keeping session active...',
          );
          _isUserStillSpeaking = false;

          // Continue monitoring but with longer intervals
          Timer(const Duration(seconds: 10), () {
            if (!_isUserStillSpeaking && !_userRequestedStop) {
              debugPrint(
                '🤫 Very long silence - user may have finished speaking',
              );
              // Don't auto-stop, let user control when to stop
            }
          });
        }
      }
    });
  }

  /// Stop recording and process the input
  Future<void> stopRecording() async {
    if (_currentState != VoiceState.recording) {
      debugPrint('⚠️ Cannot stop recording: state is ${_currentState.name}');
      return;
    }

    debugPrint('🛑 User requested stop - Continuous Recording...');

    _userRequestedStop = true; // Signal all timers to stop
    _sessionRestartTimer?.cancel();
    _silenceMonitorTimer?.cancel();

    _updateState(VoiceState.processing);

    try {
      final currentProvider =
          await StorageService.getSelectedAIProvider() ?? 'none';

      if (currentProvider == 'gemini') {
        await _stopAudioRecording();
        await _processWithGeminiNative();
      } else {
        await _stopSpeechToText();
        await _processWithGroqEnhanced();
      }
    } catch (e) {
      debugPrint('❌ Failed to stop recording: $e');
      _updateState(VoiceState.error);
      rethrow;
    }
  }

  /// Stop speech-to-text cleanly
  Future<void> _stopSpeechToText() async {
    try {
      await _speechToText.stop();
      debugPrint('🛑 speech-to-text stopped cleanly');
    } catch (e) {
      debugPrint('⚠️ Error stopping speech-to-text: $e');
    }
  }

  /// Process with Groq approach
  Future<void> _processWithGroqEnhanced() async {
    final finalText = _cumulativeTranscription.isNotEmpty
        ? _cumulativeTranscription.trim()
        : _currentTranscription.trim();

    if (finalText.isEmpty) {
      throw Exception(
        'No speech was captured. Please speak clearly and try again.',
      );
    }

    debugPrint('🧠 Processing Groq with final text: "$finalText"');

    try {
      // preprocessing for better AI understanding
      String enhancedText = _enhanceTextForAI(finalText);
      debugPrint('🔧 text for AI: "$enhancedText"');

      final response = await AIReminderService.parseRemindersFromText(
        enhancedText,
      );

      _resultsController.add(response.reminders);
      _updateState(VoiceState.completed);

      debugPrint(
        '✅ Groq processing complete: ${response.reminders.length} reminders',
      );
    } catch (e) {
      debugPrint('❌ Groq processing error: $e');

      // fallback processing
      try {
        debugPrint('🔄 Trying fallback processing...');
        final fallbackText = _createEnhancedFallbackText(finalText);

        final response = await AIReminderService.parseRemindersFromText(
          fallbackText,
        );

        _resultsController.add(response.reminders);
        _updateState(VoiceState.completed);

        debugPrint(
          '✅ fallback processing succeeded: ${response.reminders.length} reminders',
        );
      } catch (fallbackError) {
        debugPrint('❌ fallback also failed: $fallbackError');
        throw Exception(
          'Could not understand: "$finalText". Please try rephrasing.',
        );
      }
    }
  }

  /// text preprocessing for better AI understanding
  String _enhanceTextForAI(String text) {
    String enhanced = text.toLowerCase().trim();

    // Remove duplicate phrases that might have been picked up
    final words = enhanced.split(' ');
    final uniqueWords = <String>[];
    String lastWord = '';

    for (final word in words) {
      if (word != lastWord || !word.isEmpty) {
        uniqueWords.add(word);
        lastWord = word;
      }
    }

    enhanced = uniqueWords.join(' ');

    // Add context if missing
    if (!enhanced.contains('remind') && !enhanced.contains('reminder')) {
      enhanced = 'create a reminder: $enhanced';
    }

    // Handle incomplete sentences better
    if (enhanced.endsWith('on') ||
        enhanced.endsWith('at') ||
        enhanced.endsWith('for')) {
      enhanced +=
          ' [user may have more to say - create best possible reminder]';
    }

    return enhanced;
  }

  /// Create fallback text with more context
  String _createEnhancedFallbackText(String originalText) {
    final now = DateTime.now();

    return '''
Voice input from user: "$originalText"

Instructions for AI:
- The user was speaking naturally and may have been interrupted or spoke incomplete thoughts
- Create the most logical reminder(s) possible from this voice input
- If timing is unclear, default to tomorrow morning at 9 AM
- If the task is vague, create a reasonable reminder that captures the user's intent
- Be forgiving of speech recognition errors and incomplete sentences

Current context: ${now.toString()}

Please extract at least one meaningful reminder from this voice input.
''';
  }

  /// Start audio recording for Gemini native
  Future<void> _startAudioRecording() async {
    final tempDir = await getTemporaryDirectory();
    _audioFilePath =
        '${tempDir.path}/voice_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    if (!await _audioRecorder.hasPermission()) {
      throw Exception('Audio recording permission not granted');
    }

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 16000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _audioFilePath!,
    );

    debugPrint('🎵 audio recording started: $_audioFilePath');
  }

  /// Stop audio recording
  Future<void> _stopAudioRecording() async {
    final path = await _audioRecorder.stop();
    debugPrint('🎵 audio recording stopped: $path');
  }

  /// Process with Gemini native
  Future<void> _processWithGeminiNative() async {
    if (_audioFilePath == null || !File(_audioFilePath!).existsSync()) {
      throw Exception('No audio file available for processing');
    }

    final audioFile = File(_audioFilePath!);
    final audioSize = await audioFile.length();

    if (audioSize < 1000) {
      throw Exception(
        'Audio file too small. Please speak longer and more clearly.',
      );
    }

    debugPrint(
      '🧠 Processing Gemini native: $_audioFilePath (${audioSize} bytes)',
    );

    try {
      final audioBytes = await audioFile.readAsBytes();
      final prompt = _createEnhancedGeminiPrompt();

      final response = await AIReminderService.parseRemindersFromAudio(
        audioBytes: audioBytes,
        prompt: prompt,
      );

      _resultsController.add(response.reminders);
      _updateState(VoiceState.completed);

      debugPrint(
        '✅ Gemini processing complete: ${response.reminders.length} reminders',
      );

      await audioFile.delete();
    } catch (e) {
      _updateState(VoiceState.error);
      debugPrint('❌ Gemini processing error: $e');
      throw Exception('Failed to process audio: ${e.toString()}');
    }
  }

  /// Create Gemini prompt
  String _createEnhancedGeminiPrompt() {
    final now = DateTime.now();

    return '''
You are VoiceRemind's advanced voice assistant. This audio may contain:
- Long, natural speech with pauses
- Incomplete sentences or thoughts
- Multiple related requests
- Background noise or unclear speech

CRITICAL: Be extremely helpful and forgiving. Extract ALL possible reminders.

Guidelines:
1. **Handle incomplete speech gracefully** - if someone says "remind me about my meeting tomorrow" and trails off, create a reminder for "Meeting tomorrow"
2. **Extract multiple tasks** - if multiple things are mentioned, create separate reminders
3. **Smart time interpretation** - use context clues for timing
4. **Default to helpful assumptions** - better to create a useful reminder than none at all

Time context:
- Current time: ${now.toString()}
- If no time specified, use tomorrow 9:00 AM
- "Morning" = 9 AM, "afternoon" = 2 PM, "evening" = 6 PM

ALWAYS create at least one reminder, even if the speech is unclear. Return valid JSON.
''';
  }

  /// error handling
  void _handleSpeechError(dynamic error) {
    debugPrint('❌ speech error: $error');

    final errorString = error.toString().toLowerCase();

    // Handle common Android errors more intelligently
    if (errorString.contains('error_speech_timeout') ||
        errorString.contains('error_no_match')) {
      debugPrint('Timeout/no match error detected');

      // If we have valid speech, don't treat as fatal error
      if (_hasValidSpeech && _cumulativeTranscription.trim().isNotEmpty) {
        debugPrint('✅ Have valid cumulative transcription, continuing...');

        // Try to restart session if user hasn't stopped
        if (!_userRequestedStop && _sessionCount < _maxSessions) {
          Timer(const Duration(milliseconds: 500), () async {
            if (_currentState == VoiceState.recording && !_userRequestedStop) {
              await _startIntelligentSpeechSession();
            }
          });
        }
        return;
      }
    }

    if (errorString.contains('error_busy')) {
      debugPrint('📞 Speech service busy, will retry...');
      if (!_userRequestedStop && _sessionCount < _maxSessions) {
        Timer(const Duration(milliseconds: 800), () async {
          if (_currentState == VoiceState.recording && !_userRequestedStop) {
            await _startIntelligentSpeechSession();
          }
        });
      }
      return;
    }

    // Only set error state for truly fatal errors
    if (!_hasValidSpeech || _cumulativeTranscription.trim().isEmpty) {
      _updateState(VoiceState.error);
    }
  }

  /// status handling
  void _handleSpeechStatus(String status) {
    debugPrint('📝 speech status: $status');

    if (status == 'done') {
      debugPrint('✅ Session #$_sessionCount completed');

      // If user hasn't stopped and we're still recording, restart session
      if (!_userRequestedStop &&
          _currentState == VoiceState.recording &&
          _sessionCount < _maxSessions) {
        Timer(const Duration(milliseconds: 300), () async {
          if (_currentState == VoiceState.recording && !_userRequestedStop) {
            debugPrint(
              '🔄 Auto-restarting session for continuous listening...',
            );
            await _startIntelligentSpeechSession();
          }
        });
      }
    }

    if (status == 'listening') {
      debugPrint('👂 Session #$_sessionCount now actively listening');
    }
  }

  // Helper methods
  void _updateState(VoiceState newState) {
    _currentState = newState;
    _stateController.add(_currentState);
    debugPrint('🔄 voice state: ${newState.name}');
  }

  /// Reset to idle state
  void resetState() {
    _sessionRestartTimer?.cancel();
    _silenceMonitorTimer?.cancel();

    _userRequestedStop = true; // Stop all ongoing operations
    _speechToText.stop(); // Ensure speech recognition is stopped

    _currentState = VoiceState.idle;
    _currentTranscription = '';
    _cumulativeTranscription = '';
    _audioFilePath = null;
    _hasValidSpeech = false;
    _lastSpeechUpdate = null;
    _isUserStillSpeaking = false;
    _sessionCount = 0;

    _stateController.add(_currentState);
    debugPrint('🔄 voice state reset to idle');
  }

  /// Check if voice service is available
  static Future<bool> isAvailable() async {
    try {
      final microphoneStatus = await Permission.microphone.status;
      return microphoneStatus.isGranted;
    } catch (e) {
      debugPrint('❌ Voice availability check failed: $e');
      return false;
    }
  }

  /// Get diagnostic information
  static Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      diagnostics['microphone_permission'] =
          (await Permission.microphone.status).name;
      diagnostics['speech_permission'] = (await Permission.speech.status).name;
      diagnostics['platform'] = Platform.operatingSystem;
      diagnostics['platform_version'] = Platform.operatingSystemVersion;

      final speechToText = SpeechToText();
      diagnostics['speech_available'] = await speechToText.initialize();

      if (diagnostics['speech_available']) {
        final locales = await speechToText.locales();
        diagnostics['available_locales'] =
            locales.map((l) => l.localeId).toList();
      }

      final recorder = AudioRecorder();
      diagnostics['audio_recorder_permission'] = await recorder.hasPermission();

      diagnostics['enhanced_features'] = {
        'continuous_speech': true,
        'session_management': true,
        'intelligent_restart': true,
        'cumulative_transcription': true,
      };

      debugPrint('🔍 voice diagnostics: $diagnostics');
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    return diagnostics;
  }

  /// Dispose resources
  void dispose() {
    _sessionRestartTimer?.cancel();
    _silenceMonitorTimer?.cancel();
    _userRequestedStop = true;

    _speechToText.cancel();
    _audioRecorder.dispose();
    _stateController.close();
    _transcriptionController.close();
    _resultsController.close();

    debugPrint('🧹 VoiceService disposed');
  }
}
