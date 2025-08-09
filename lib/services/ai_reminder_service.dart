// [lib/services]/ai_reminder_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/reminder.dart';
import 'storage_service.dart';

class AIReminderService {
  static GenerativeModel? _model;
  static String? _currentApiKey;
  static String _currentProvider = 'none'; // 'gemini', 'groq', or 'none'

  static Future<void> initialize(
      {String? customApiKey, String? provider}) async {
    try {
      // Priority order for API key selection:
      // 1. Custom API key provided
      // 2. User-stored API keys
      // 3. Environment variables (fallback)

      String? apiKey = customApiKey;
      String selectedProvider = provider ?? 'none';

      // If no custom key provided, try to load from user storage
      if (apiKey == null || apiKey.isEmpty) {
        final storedProvider = await StorageService.getSelectedAIProvider();
        if (storedProvider != null && storedProvider != 'none') {
          if (storedProvider == 'gemini') {
            apiKey = await StorageService.getGeminiApiKey();
            selectedProvider = 'gemini';
          } else if (storedProvider == 'groq') {
            apiKey = await StorageService.getGroqApiKey();
            selectedProvider = 'groq';
          }
        }
      }

      // Fallback to environment variables if no user keys found
      if (apiKey == null || apiKey.isEmpty) {
        apiKey = dotenv.env['GEMINI_API_KEY'];
        selectedProvider = 'gemini';

        if (apiKey == null || apiKey.isEmpty) {
          apiKey = dotenv.env['GROQ_API_KEY'];
          selectedProvider = 'groq';
        }
      }

      // If still no API key, set to 'none' state
      if (apiKey == null || apiKey.isEmpty) {
        _currentApiKey = null;
        _currentProvider = 'none';
        _model = null;
        debugPrint('⚠️ No AI API keys found - AI features disabled');
        return;
      }

      _currentApiKey = apiKey;
      _currentProvider = selectedProvider;

      if (selectedProvider == 'gemini') {
        _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
            maxOutputTokens: 2048,
            responseSchema: Schema(
              SchemaType.object,
              properties: {
                'reminders': Schema(
                  SchemaType.array,
                  items: Schema(
                    SchemaType.object,
                    properties: {
                      'title': Schema(SchemaType.string),
                      'description': Schema(SchemaType.string),
                      'due_date': Schema(SchemaType.string),
                      'repeat_type': Schema(SchemaType.string),
                    },
                    requiredProperties: [
                      'title',
                      'description',
                      'due_date',
                      'repeat_type'
                    ],
                  ),
                ),
                'parsing_confidence': Schema(SchemaType.number),
                'ambiguities':
                    Schema(SchemaType.array, items: Schema(SchemaType.string)),
              },
              requiredProperties: ['reminders'],
            ),
          ),
        );
      }

      debugPrint('✅ AI Service initialized with $_currentProvider');
    } catch (e) {
      debugPrint('❌ AI Service initialization failed: $e');
      _currentApiKey = null;
      _currentProvider = 'none';
      _model = null;
      rethrow;
    }
  }

  /// Reinitialize with stored user API keys
  static Future<void> reinitializeWithStoredKeys() async {
    try {
      await initialize();
    } catch (e) {
      debugPrint('❌ Failed to reinitialize with stored keys: $e');
      rethrow;
    }
  }

  /// Initialize with specific provider and API key
  static Future<void> initializeWithCustomKey(
      String provider, String apiKey) async {
    try {
      await initialize(customApiKey: apiKey, provider: provider);

      // Save the configuration if initialization succeeds
      await StorageService.setSelectedAIProvider(provider);
      if (provider == 'gemini') {
        await StorageService.setGeminiApiKey(apiKey);
      } else if (provider == 'groq') {
        await StorageService.setGroqApiKey(apiKey);
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize with custom key: $e');
      rethrow;
    }
  }

  /// Get current AI provider status
  static Future<Map<String, dynamic>> getProviderStatus() async {
    final configStatus = await StorageService.getAIConfigurationStatus();

    return {
      ...configStatus,
      'currentProvider': _currentProvider,
      'isInitialized': isInitialized,
      'hasApiKey': hasApiKey,
      'canGenerateReminders': canGenerateReminders,
    };
  }

  /// Switch to a different provider
  static Future<bool> switchProvider(String newProvider) async {
    try {
      if (newProvider == 'none') {
        _currentProvider = 'none';
        _currentApiKey = null;
        _model = null;
        await StorageService.setSelectedAIProvider('none');
        return true;
      }

      // Check if the provider has an API key
      String? apiKey;
      if (newProvider == 'gemini') {
        apiKey = await StorageService.getGeminiApiKey();
      } else if (newProvider == 'groq') {
        apiKey = await StorageService.getGroqApiKey();
      }

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('No API key found for $newProvider');
      }

      // Reinitialize with the new provider
      await initialize(customApiKey: apiKey, provider: newProvider);
      await StorageService.setSelectedAIProvider(newProvider);

      return true;
    } catch (e) {
      debugPrint('❌ Failed to switch to $newProvider: $e');
      return false;
    }
  }

  static bool get isInitialized =>
      _currentApiKey != null && _currentProvider != 'none';
  static String get currentProvider => _currentProvider;
  static bool get hasApiKey =>
      _currentApiKey != null && _currentApiKey!.isNotEmpty;
  static bool get canGenerateReminders => isInitialized && hasApiKey;

  static Future<AIReminderResponse> parseRemindersFromText(
      String userInput) async {
    if (!isInitialized) {
      throw Exception(
          'AI Service not initialized. Please configure an API key in Settings.');
    }

    if (!canGenerateReminders) {
      throw Exception(
          'AI Service not ready. Please check your API key configuration.');
    }

    // Build comprehensive prompt with current time context
    final systemPrompt = _buildSystemPrompt();
    final fullPrompt = '$systemPrompt\n\nUser Input: "$userInput"';

    try {
      if (_currentProvider == 'gemini') {
        return await _parseWithGemini(fullPrompt);
      } else if (_currentProvider == 'groq') {
        return await _parseWithGroq(fullPrompt, userInput);
      } else {
        throw Exception('Unknown provider: $_currentProvider');
      }
    } catch (e) {
      if (e.toString().contains('API_KEY_INVALID') ||
          e.toString().contains('unauthorized') ||
          e.toString().contains('Invalid API key')) {
        throw Exception(
            'Invalid API key. Please check your $_currentProvider API key in Settings.');
      }
      throw Exception('Failed to parse reminders: $e');
    }
  }

  static Future<AIReminderResponse> _parseWithGemini(String fullPrompt) async {
    if (_model == null) {
      throw Exception('Gemini model not initialized');
    }

    try {
      final response =
          await _model!.generateContent([Content.text(fullPrompt)]);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini AI');
      }

      return _parseResponse(response.text!);
    } catch (e) {
      if (e.toString().contains('API_KEY_INVALID')) {
        throw Exception(
            'Invalid Gemini API key. Please check your API key in Settings.');
      }
      rethrow;
    }
  }

  static Future<AIReminderResponse> parseRemindersFromAudio({
    required Uint8List audioBytes,
    required String prompt,
  }) async {
    if (!canGenerateReminders || _currentProvider != 'gemini') {
      throw Exception('Gemini provider required for audio processing');
    }

    if (_model == null) {
      throw Exception('Gemini model not initialized');
    }

    try {
      // Create content with audio data
      final content = [
        Content.text(prompt),
        Content.data('audio/wav', audioBytes),
      ];

      final response = await _model!.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini AI');
      }

      return _parseResponse(response.text!);
    } catch (e) {
      if (e.toString().contains('API_KEY_INVALID')) {
        throw Exception(
            'Invalid Gemini API key. Please check your API key in Settings.');
      }
      rethrow;
    }
  }

  static Future<AIReminderResponse> _parseWithGroq(
      String systemPrompt, String userInput) async {
    if (_currentApiKey == null) {
      throw Exception('Groq API key not available');
    }

    final requestBody = {
      'model': 'deepseek-r1-distill-llama-70b',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userInput}
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.1,
    };

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_currentApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 401) {
        throw Exception(
            'Invalid Groq API key. Please check your API key in Settings.');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Groq API error: ${response.statusCode} - ${response.body}');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      return _parseResponse(content);
    } catch (e) {
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        throw Exception(
            'Invalid Groq API key. Please check your API key in Settings.');
      }
      rethrow;
    }
  }

  static AIReminderResponse _parseResponse(String responseText) {
    try {
      // Parse JSON response
      final jsonData = jsonDecode(responseText);
      final reminderData = jsonData['reminders'] as List;

      if (reminderData.isEmpty) {
        throw Exception(
            'No reminders could be generated from your input. Please try rephrasing.');
      }

      // Convert to Reminder objects
      final reminders = <Reminder>[];
      for (final data in reminderData) {
        try {
          final reminder = Reminder(
            title: data['title']?.toString() ?? 'Untitled Reminder',
            description: data['description']?.toString(),
            scheduledTime: DateTime.parse(data['due_date']),
            repeatType: _parseRepeatType(data['repeat_type']),
            isNotificationEnabled: true,
          );
          reminders.add(reminder);
        } catch (e) {
          // Skip invalid reminders but continue processing others
          debugPrint('Skipping invalid reminder: $e');
        }
      }

      if (reminders.isEmpty) {
        throw Exception(
            'No valid reminders could be parsed from the AI response.');
      }

      return AIReminderResponse(
        reminders: reminders,
        confidence: (jsonData['parsing_confidence'] as num?)?.toDouble() ?? 0.8,
        ambiguities: (jsonData['ambiguities'] as List?)?.cast<String>() ?? [],
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
            'Invalid response format from AI service. Please try again.');
      }
      rethrow;
    }
  }

  /// Test the current AI configuration
  static Future<bool> testConnection() async {
    if (!canGenerateReminders) {
      return false;
    }

    try {
      final response =
          await parseRemindersFromText('Test reminder for tomorrow at 9am');
      return response.reminders.isNotEmpty;
    } catch (e) {
      debugPrint('❌ AI connection test failed: $e');
      return false;
    }
  }

  /// Get available AI providers based on stored API keys
  static Future<List<String>> getAvailableProviders() async {
    final providers = <String>['none'];

    final geminiKey = await StorageService.getGeminiApiKey();
    if (geminiKey?.isNotEmpty == true) {
      providers.add('gemini');
    }

    final groqKey = await StorageService.getGroqApiKey();
    if (groqKey?.isNotEmpty == true) {
      providers.add('groq');
    }

    return providers;
  }

  /// Get provider display information
  static Map<String, dynamic> getProviderInfo(String provider) {
    switch (provider) {
      case 'gemini':
        return {
          'name': 'Google Gemini',
          'description': 'Fast and accurate AI from Google',
          'icon': 'auto_awesome',
          'color': 'green',
          'freeLimit': '15 requests/minute',
          'signupUrl': 'https://aistudio.google.com/apikey/',
        };
      case 'groq':
        return {
          'name': 'Groq',
          'description': 'Ultra-fast AI inference',
          'icon': 'flash_on',
          'color': 'blue',
          'freeLimit': '14,400 requests/day',
          'signupUrl': 'https://console.groq.com/keys/',
        };
      case 'none':
      default:
        return {
          'name': 'No AI Provider',
          'description': 'AI features disabled',
          'icon': 'cancel_outlined',
          'color': 'grey',
          'freeLimit': 'N/A',
          'signupUrl': null,
        };
    }
  }

  /// Clear all AI configuration
  static Future<void> clearConfiguration() async {
    _currentApiKey = null;
    _currentProvider = 'none';
    _model = null;
    await StorageService.clearAIConfiguration();
  }

  /// Validate API key format
  static bool validateApiKeyFormat(String apiKey, String provider) {
    return StorageService.isValidApiKeyFormat(apiKey, provider);
  }

  static String _buildSystemPrompt() {
    final timeContext = _getCurrentTimeContext();

    return '''
# VOICEREMIND AI ASSISTANT

You are an intelligent reminder parsing system for VoiceRemind app. Your ONLY job is to convert natural language into structured reminder data.

## TEMPORAL CONTEXT
$timeContext

## CORE RESPONSIBILITIES
1. Parse natural language into structured reminders
2. Intelligently determine dates/times from relative expressions
3. Extract detailed descriptions and context
4. Determine appropriate repeat patterns

## PARSING RULES
### Date/Time Interpretation:
- "tomorrow" = ${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)))}
- "next week" = Week of ${DateFormat('MMM d').format(DateTime.now().add(const Duration(days: 7)))}
- "in 2 hours" = ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now().add(const Duration(hours: 2)))}
- Default time for date-only: 09:00 (morning) unless context suggests otherwise
- Business hours: 9 AM - 5 PM for work-related tasks
- Evening tasks: Default to 7 PM
- Always output in "YYYY-MM-DD HH:MM" format

### Title Guidelines:
- Keep titles concise and actionable (max 50 characters)
- Use action verbs when possible (Call, Buy, Review, Submit, etc.)
- Avoid redundant words

### Description Guidelines:
- Include WHO (person/contact), WHAT (specific action), WHERE (location), WHY (purpose)
- Provide helpful context that wasn't in the title
- Include specific details mentioned by user

### Repeat Type Rules:
- "daily" for tasks that should repeat every day
- "weekly" for tasks that repeat weekly (meetings, appointments)
- "monthly" for tasks that repeat monthly (bills, reports)
- "none" for one-time tasks (default)

## OUTPUT FORMAT
Always respond with valid JSON matching this exact schema:
{
  "reminders": [
    {
      "title": "Clear, actionable title",
      "description": "Detailed description with context",
      "due_date": "YYYY-MM-DD HH:MM",
      "repeat_type": "none|daily|weekly|monthly"
    }
  ],
  "parsing_confidence": 0.95,
  "ambiguities": ["any unclear aspects requiring clarification"]
}

## EXAMPLES
Input: "Call dentist tomorrow morning and buy groceries for Saturday dinner"
Output: {
  "reminders": [
    {
      "title": "Call dentist",
      "description": "Schedule or follow up on dental appointment",
      "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)))} 09:00",
      "repeat_type": "none"
    },
    {
      "title": "Buy groceries for dinner",
      "description": "Purchase groceries and ingredients for Saturday dinner",
      "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: DateTime.saturday - DateTime.now().weekday)))} 10:00",
      "repeat_type": "none"
    }
  ],
  "parsing_confidence": 0.92,
  "ambiguities": []
}

CRITICAL: Always return valid JSON. Never include explanations outside the JSON structure.''';
  }

  static String _getCurrentTimeContext() {
    final now = DateTime.now();
    final timeZone = now.timeZoneName;
    final dayOfWeek = DateFormat('EEEE').format(now);
    final date = DateFormat('MMMM d, yyyy').format(now);
    final time = DateFormat('h:mm a').format(now);
    final weekOfYear = _getWeekOfYear(now);

    return '''
CURRENT TEMPORAL CONTEXT:
- Current Date & Time: $dayOfWeek, $date at $time ($timeZone)
- Unix Timestamp: ${now.millisecondsSinceEpoch}
- ISO 8601: ${now.toIso8601String()}
- Week of Year: $weekOfYear
- Is Weekend: ${now.weekday >= 6}
- Season: ${_getCurrentSeason(now)}

RELATIVE TIME CALCULATIONS:
- Today: $date
- Tomorrow: ${DateFormat('MMMM d, yyyy').format(now.add(const Duration(days: 1)))}
- Next Week: Week starting ${DateFormat('MMMM d').format(now.add(Duration(days: 7 - now.weekday + 1)))}
- Next Month: ${DateFormat('MMMM yyyy').format(DateTime(now.year, now.month + 1))}''';
  }

  static RepeatType _parseRepeatType(String? type) {
    if (type == null) return RepeatType.none;

    switch (type.toLowerCase()) {
      case 'daily':
        return RepeatType.daily;
      case 'weekly':
        return RepeatType.weekly;
      case 'monthly':
        return RepeatType.monthly;
      default:
        return RepeatType.none;
    }
  }

  static int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    return ((dayOfYear - 1) / 7).floor() + 1;
  }

  static String _getCurrentSeason(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return 'Spring';
    if (month >= 6 && month <= 8) return 'Summer';
    if (month >= 9 && month <= 11) return 'Fall';
    return 'Winter';
  }
}

class AIReminderResponse {
  final List<Reminder> reminders;
  final double confidence;
  final List<String> ambiguities;

  const AIReminderResponse({
    required this.reminders,
    required this.confidence,
    required this.ambiguities,
  });

  bool get hasAmbiguities => ambiguities.isNotEmpty;
  bool get isHighConfidence => confidence >= 0.8;
}
