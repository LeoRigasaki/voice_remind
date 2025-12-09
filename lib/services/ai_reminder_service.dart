// [lib/services]/ai_reminder_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/reminder.dart';
import '../models/custom_repeat_config.dart';
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
                      'is_multi_time': Schema(SchemaType.boolean),
                      'time_slots': Schema(
                        SchemaType.array,
                        items: Schema(
                          SchemaType.object,
                          properties: {
                            'time': Schema(SchemaType.string),
                            'description': Schema(SchemaType.string),
                          },
                        ),
                      ),
                      'custom_repeat_config': Schema(
                        SchemaType.object,
                        properties: {
                          'interval': Schema(SchemaType.integer),
                          'frequency': Schema(SchemaType.string),
                          'days_of_week': Schema(
                            SchemaType.array,
                            items: Schema(SchemaType.integer),
                          ),
                          'end_date': Schema(SchemaType.string),
                        },
                      ),
                    },
                    requiredProperties: [
                      'title',
                      'description',
                      'due_date',
                      'repeat_type',
                      'is_multi_time'
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

  /// Parse reminders from image(s) with optional custom prompt
  /// Supports multiple images in a single context
  static Future<AIReminderResponse> parseRemindersFromImage({
    required List<Uint8List> imageBytesList,
    String? customPrompt,
  }) async {
    if (!canGenerateReminders) {
      throw Exception(
          'AI Service not ready. Please configure an API key in Settings.');
    }

    if (imageBytesList.isEmpty) {
      throw Exception('At least one image is required');
    }

    // Use custom prompt if provided, otherwise use default
    final prompt = customPrompt?.trim().isEmpty ?? true
        ? _buildImageAnalysisPrompt()
        : _buildImageAnalysisPromptWithCustomText(customPrompt!);

    try {
      if (_currentProvider == 'gemini') {
        return await _parseImageWithGemini(imageBytesList, prompt);
      } else if (_currentProvider == 'groq') {
        return await _parseImageWithGroq(imageBytesList, prompt);
      } else {
        throw Exception('Unknown provider: $_currentProvider');
      }
    } catch (e) {
      if (e.toString().contains('API_KEY_INVALID')) {
        throw Exception(
            'Invalid $_currentProvider API key. Please check your API key in Settings.');
      }
      rethrow;
    }
  }

  static Future<AIReminderResponse> _parseImageWithGemini(
      List<Uint8List> imageBytesList, String prompt) async {
    if (_model == null) {
      throw Exception('Gemini model not initialized');
    }

    try {
      // Create text part
      final textPart = TextPart(prompt);

      // Create image parts for all images
      final imageParts = imageBytesList
          .map((imageBytes) => DataPart('image/jpeg', imageBytes))
          .toList();

      // Combine text and all images in a single content
      final parts = [textPart, ...imageParts];

      final response = await _model!.generateContent(
        [
          Content.multi(parts)
        ],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'reminders': Schema.array(
                items: Schema.object(
                  properties: {
                    'title': Schema.string(
                      description: 'Brief task description',
                    ),
                    'context': Schema.string(
                      description: 'Full context from image',
                    ),
                    'priority': Schema.enumString(
                      enumValues: ['HIGH', 'MEDIUM', 'LOW'],
                      description: 'Task priority level',
                    ),
                    'due_date': Schema.string(
                      description: 'ISO 8601 datetime string',
                    ),
                    'tags': Schema.array(
                      items: Schema.string(),
                      description: 'Categories or labels',
                    ),
                    'repeat_type': Schema.enumString(
                      enumValues: [
                        'NONE',
                        'DAILY',
                        'WEEKLY',
                        'MONTHLY',
                        'CUSTOM'
                      ],
                      description: 'Recurrence pattern',
                    ),
                    'is_multi_time': Schema.boolean(
                      description:
                          'True if reminder has multiple time slots per day',
                    ),
                    'time_slots': Schema.array(
                      items: Schema.object(
                        properties: {
                          'time': Schema.string(
                            description: 'Time in HH:MM format (24-hour)',
                          ),
                          'description': Schema.string(
                            description:
                                'Optional description for this time slot',
                          ),
                        },
                        requiredProperties: ['time'],
                      ),
                      description:
                          'Multiple time slots for multi-time reminders',
                    ),
                    'custom_repeat_config': Schema.object(
                      properties: {
                        'interval': Schema.integer(
                          description:
                              'Repeat interval (e.g., 2 for every 2 days/weeks)',
                        ),
                        'frequency': Schema.enumString(
                          enumValues: ['DAYS', 'WEEKS', 'MONTHS'],
                          description: 'Frequency unit',
                        ),
                        'days_of_week': Schema.array(
                          items: Schema.integer(),
                          description:
                              'Days of week (1=Mon, 7=Sun) for weekly repeats',
                        ),
                        'end_date': Schema.string(
                          description: 'Optional end date for custom repeat',
                        ),
                      },
                    ),
                  },
                  requiredProperties: [
                    'title',
                    'context',
                    'priority',
                    'due_date',
                    'tags',
                    'repeat_type',
                    'is_multi_time'
                  ],
                ),
              ),
              'parsing_confidence': Schema.number(
                description: 'Confidence score between 0 and 1',
              ),
              'ambiguities': Schema.array(
                items: Schema.string(),
                description: 'List of unclear items',
              ),
            },
            requiredProperties: [
              'reminders',
              'parsing_confidence',
              'ambiguities'
            ],
          ),
          temperature: 0.1,
        ),
      );

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

  static Future<AIReminderResponse> _parseImageWithGroq(
      List<Uint8List> imageBytesList, String prompt) async {
    if (_currentApiKey == null) {
      throw Exception('Groq API key not available');
    }

    // Check image limit (max 5 images for GroqCloud)
    if (imageBytesList.length > 5) {
      throw Exception('GroqCloud supports a maximum of 5 images per request');
    }

    // Build content array with text and all images
    final contentList = <Map<String, dynamic>>[];

    // Add text prompt first
    contentList.add({'type': 'text', 'text': prompt});

    // Add all images
    for (final imageBytes in imageBytesList) {
      final base64Image = base64Encode(imageBytes);
      contentList.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:image/jpeg;base64,$base64Image',
        }
      });
    }

    final requestBody = {
      'model':
          'meta-llama/llama-4-scout-17b-16e-instruct', // Vision-capable model
      'messages': [
        {
          'role': 'user',
          'content': contentList,
        }
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'reminder_extraction',
          'schema': {
            'type': 'object',
            'properties': {
              'reminders': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {
                      'type': 'string',
                      'description': 'Brief task description'
                    },
                    'context': {
                      'type': 'string',
                      'description': 'Full context from image'
                    },
                    'priority': {
                      'type': 'string',
                      'enum': ['HIGH', 'MEDIUM', 'LOW'],
                      'description': 'Task priority level'
                    },
                    'due_date': {
                      'type': 'string',
                      'description': 'ISO 8601 datetime string'
                    },
                    'tags': {
                      'type': 'array',
                      'items': {'type': 'string'},
                      'description': 'Categories or labels'
                    },
                    'repeat_type': {
                      'type': 'string',
                      'enum': ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM'],
                      'description': 'Recurrence pattern'
                    },
                    'is_multi_time': {
                      'type': 'boolean',
                      'description':
                          'True if reminder has multiple time slots per day'
                    },
                    'time_slots': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'properties': {
                          'time': {
                            'type': 'string',
                            'description': 'Time in HH:MM format (24-hour)'
                          },
                          'description': {
                            'type': 'string',
                            'description':
                                'Optional description for this time slot'
                          }
                        },
                        'required': ['time'],
                        'additionalProperties': false
                      },
                      'description':
                          'Multiple time slots for multi-time reminders'
                    },
                    'custom_repeat_config': {
                      'type': 'object',
                      'properties': {
                        'interval': {
                          'type': 'integer',
                          'description':
                              'Repeat interval (e.g., 2 for every 2 days/weeks)'
                        },
                        'frequency': {
                          'type': 'string',
                          'enum': ['DAYS', 'WEEKS', 'MONTHS'],
                          'description': 'Frequency unit'
                        },
                        'days_of_week': {
                          'type': 'array',
                          'items': {'type': 'integer'},
                          'description':
                              'Days of week (1=Mon, 7=Sun) for weekly repeats'
                        },
                        'end_date': {
                          'type': 'string',
                          'description': 'Optional end date for custom repeat'
                        }
                      },
                      'additionalProperties': false
                    }
                  },
                  'required': [
                    'title',
                    'context',
                    'priority',
                    'due_date',
                    'tags',
                    'repeat_type',
                    'is_multi_time'
                  ],
                  'additionalProperties': false
                }
              },
              'parsing_confidence': {
                'type': 'number',
                'minimum': 0,
                'maximum': 1,
                'description': 'Confidence score between 0 and 1'
              },
              'ambiguities': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'List of unclear items'
              }
            },
            'required': ['reminders', 'parsing_confidence', 'ambiguities'],
            'additionalProperties': false
          }
        }
      },
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

  static String _buildImageAnalysisPrompt() {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d, yyyy \'at\' h:mm a');
    final currentTimeStr = formatter.format(now);

    return '''
You are a smart reminder extraction AI. Analyze this screenshot/image and extract ALL possible reminders, tasks, events, or time-sensitive information.

CURRENT TIME: $currentTimeStr
Today is ${DateFormat('EEEE').format(now)}.

EXTRACTION RULES:
1. Extract ALL text visible in the image
2. Identify dates, times, deadlines, appointments
3. Look for: calendar events, messages, notifications, notes, to-do lists
4. Understand context: "tomorrow" means ${DateFormat('yyyy-MM-dd').format(now.add(Duration(days: 1)))}
5. If no time specified, default to 9:00 AM
6. Extract recurring patterns and detect custom repeats (e.g., "every Mon & Thu")
7. Detect multi-time reminders (e.g., "medication 3x daily at 8am, 2pm, 8pm")
8. Identify priority from urgency words (urgent, ASAP, important)

MULTI-TIME DETECTION:
- Look for phrases like "X times per day", "twice daily", "every 2 hours"
- Extract all specific times mentioned
- Set is_multi_time: true and populate time_slots array

CUSTOM REPEAT PATTERNS:
- "Every Monday and Thursday" → {interval: 1, frequency: "WEEKS", days_of_week: [1, 4]}
- "Every 2 weeks" → {interval: 2, frequency: "WEEKS"}
- Days: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun

OUTPUT FORMAT (strict JSON):
{
  "reminders": [
    {
      "title": "Brief task description",
      "context": "Full context from image",
      "priority": "HIGH|MEDIUM|LOW",
      "due_date": "YYYY-MM-DDTHH:MM:SS",
      "tags": ["category1", "category2"],
      "repeat_type": "NONE|DAILY|WEEKLY|MONTHLY|CUSTOM",
      "is_multi_time": false,
      "time_slots": [],
      "custom_repeat_config": null
    }
  ],
  "parsing_confidence": 0.0-1.0,
  "ambiguities": ["list any unclear items"]
}

Analyze the image now and extract reminders:''';
  }

  static String _buildImageAnalysisPromptWithCustomText(String customText) {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d, yyyy \'at\' h:mm a');
    final currentTimeStr = formatter.format(now);

    return '''
You are a smart reminder extraction AI. 

CURRENT TIME: $currentTimeStr
Today is ${DateFormat('EEEE').format(now)}.

USER REQUEST: "$customText"

Analyze the provided image and follow the user's specific request above. Extract reminders based on what they asked for.

OUTPUT FORMAT (strict JSON):
{
  "reminders": [
    {
      "title": "Brief task description",
      "context": "Full context",
      "priority": "HIGH|MEDIUM|LOW",
      "due_date": "YYYY-MM-DDTHH:MM:SS",
      "tags": ["category1", "category2"],
      "repeat_type": "NONE|DAILY|WEEKLY|MONTHLY"
    }
  ],
  "parsing_confidence": 0.0-1.0,
  "ambiguities": ["list any unclear items"]
}

Analyze the image according to the user's request:''';
  }

  static Future<AIReminderResponse> _parseWithGemini(String fullPrompt) async {
    if (_model == null) {
      throw Exception('Gemini model not initialized');
    }

    try {
      final response = await _model!.generateContent(
        [Content.text(fullPrompt)],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'reminders': Schema.array(
                items: Schema.object(
                  properties: {
                    'title': Schema.string(
                      description: 'Brief task description',
                    ),
                    'context': Schema.string(
                      description: 'Full context from user input',
                    ),
                    'priority': Schema.enumString(
                      enumValues: ['HIGH', 'MEDIUM', 'LOW'],
                      description: 'Task priority level',
                    ),
                    'due_date': Schema.string(
                      description: 'ISO 8601 datetime string',
                    ),
                    'tags': Schema.array(
                      items: Schema.string(),
                      description: 'Categories or labels',
                    ),
                    'repeat_type': Schema.enumString(
                      enumValues: [
                        'NONE',
                        'DAILY',
                        'WEEKLY',
                        'MONTHLY',
                        'CUSTOM'
                      ],
                      description: 'Recurrence pattern',
                    ),
                    'is_multi_time': Schema.boolean(
                      description:
                          'True if reminder has multiple time slots per day',
                    ),
                    'time_slots': Schema.array(
                      items: Schema.object(
                        properties: {
                          'time': Schema.string(
                            description: 'Time in HH:MM format (24-hour)',
                          ),
                          'description': Schema.string(
                            description:
                                'Optional description for this time slot',
                          ),
                        },
                        requiredProperties: ['time'],
                      ),
                      description:
                          'Multiple time slots for multi-time reminders',
                    ),
                    'custom_repeat_config': Schema.object(
                      properties: {
                        'interval': Schema.integer(
                          description:
                              'Repeat interval (e.g., 2 for every 2 days/weeks)',
                        ),
                        'frequency': Schema.enumString(
                          enumValues: ['DAYS', 'WEEKS', 'MONTHS'],
                          description: 'Frequency unit',
                        ),
                        'days_of_week': Schema.array(
                          items: Schema.integer(),
                          description:
                              'Days of week (1=Mon, 7=Sun) for weekly repeats',
                        ),
                        'end_date': Schema.string(
                          description: 'Optional end date for custom repeat',
                        ),
                      },
                    ),
                  },
                  requiredProperties: [
                    'title',
                    'context',
                    'priority',
                    'due_date',
                    'tags',
                    'repeat_type',
                    'is_multi_time'
                  ],
                ),
              ),
              'parsing_confidence': Schema.number(
                description: 'Confidence score between 0 and 1',
              ),
              'ambiguities': Schema.array(
                items: Schema.string(),
                description: 'List of unclear items',
              ),
            },
            requiredProperties: [
              'reminders',
              'parsing_confidence',
              'ambiguities'
            ],
          ),
          temperature: 0.1,
        ),
      );

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

      final response = await _model!.generateContent(
        content,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'reminders': Schema.array(
                items: Schema.object(
                  properties: {
                    'title': Schema.string(
                      description: 'Brief task description',
                    ),
                    'context': Schema.string(
                      description: 'Full context from audio',
                    ),
                    'priority': Schema.enumString(
                      enumValues: ['HIGH', 'MEDIUM', 'LOW'],
                      description: 'Task priority level',
                    ),
                    'due_date': Schema.string(
                      description: 'ISO 8601 datetime string',
                    ),
                    'tags': Schema.array(
                      items: Schema.string(),
                      description: 'Categories or labels',
                    ),
                    'repeat_type': Schema.enumString(
                      enumValues: ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY'],
                      description: 'Recurrence pattern',
                    ),
                  },
                  requiredProperties: [
                    'title',
                    'context',
                    'priority',
                    'due_date',
                    'tags',
                    'repeat_type'
                  ],
                ),
              ),
              'parsing_confidence': Schema.number(
                description: 'Confidence score between 0 and 1',
              ),
              'ambiguities': Schema.array(
                items: Schema.string(),
                description: 'List of unclear items',
              ),
            },
            requiredProperties: [
              'reminders',
              'parsing_confidence',
              'ambiguities'
            ],
          ),
          temperature: 0.1,
        ),
      );

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
      'model':
          'moonshotai/kimi-k2-instruct-0905', // Model with structured output support
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userInput}
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'reminder_extraction',
          'schema': {
            'type': 'object',
            'properties': {
              'reminders': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {
                      'type': 'string',
                      'description': 'Brief task description'
                    },
                    'context': {
                      'type': 'string',
                      'description': 'Full context from user input'
                    },
                    'priority': {
                      'type': 'string',
                      'enum': ['HIGH', 'MEDIUM', 'LOW'],
                      'description': 'Task priority level'
                    },
                    'due_date': {
                      'type': 'string',
                      'description': 'ISO 8601 datetime string'
                    },
                    'tags': {
                      'type': 'array',
                      'items': {'type': 'string'},
                      'description': 'Categories or labels'
                    },
                    'repeat_type': {
                      'type': 'string',
                      'enum': ['NONE', 'DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM'],
                      'description': 'Recurrence pattern'
                    },
                    'is_multi_time': {
                      'type': 'boolean',
                      'description':
                          'True if reminder has multiple time slots per day'
                    },
                    'time_slots': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'properties': {
                          'time': {
                            'type': 'string',
                            'description': 'Time in HH:MM format (24-hour)'
                          },
                          'description': {
                            'type': 'string',
                            'description':
                                'Optional description for this time slot'
                          }
                        },
                        'required': ['time'],
                        'additionalProperties': false
                      },
                      'description':
                          'Multiple time slots for multi-time reminders'
                    },
                    'custom_repeat_config': {
                      'type': 'object',
                      'properties': {
                        'interval': {
                          'type': 'integer',
                          'description':
                              'Repeat interval (e.g., 2 for every 2 days/weeks)'
                        },
                        'frequency': {
                          'type': 'string',
                          'enum': ['DAYS', 'WEEKS', 'MONTHS'],
                          'description': 'Frequency unit'
                        },
                        'days_of_week': {
                          'type': 'array',
                          'items': {'type': 'integer'},
                          'description':
                              'Days of week (1=Mon, 7=Sun) for weekly repeats'
                        },
                        'end_date': {
                          'type': 'string',
                          'description': 'Optional end date for custom repeat'
                        }
                      },
                      'additionalProperties': false
                    }
                  },
                  'required': [
                    'title',
                    'context',
                    'priority',
                    'due_date',
                    'tags',
                    'repeat_type',
                    'is_multi_time'
                  ],
                  'additionalProperties': false
                }
              },
              'parsing_confidence': {
                'type': 'number',
                'minimum': 0,
                'maximum': 1,
                'description': 'Confidence score between 0 and 1'
              },
              'ambiguities': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'List of unclear items'
              }
            },
            'required': ['reminders', 'parsing_confidence', 'ambiguities'],
            'additionalProperties': false
          }
        }
      },
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
          // Parse multi-time configuration
          final isMultiTime = data['is_multi_time'] as bool? ?? false;
          final timeSlotsData = data['time_slots'] as List?;

          List<TimeSlot>? timeSlots;
          if (isMultiTime &&
              timeSlotsData != null &&
              timeSlotsData.isNotEmpty) {
            timeSlots = timeSlotsData.map((slot) {
              final timeStr = slot['time'] as String;
              final parts = timeStr.split(':');
              return TimeSlot(
                time: TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                ),
                description: slot['description']?.toString(),
              );
            }).toList();
          }

          // Parse custom repeat configuration
          CustomRepeatConfig? customRepeatConfig;
          if (data['repeat_type']?.toString().toUpperCase() == 'CUSTOM' &&
              data['custom_repeat_config'] != null) {
            final config = data['custom_repeat_config'] as Map<String, dynamic>;
            final interval = config['interval'] as int? ?? 1;
            final frequency = config['frequency']?.toString().toUpperCase();

            // Convert interval + frequency to minutes/hours/days
            int minutes = 0, hours = 0, days = 0;
            switch (frequency) {
              case 'DAYS':
                days = interval;
                break;
              case 'WEEKS':
                days = interval * 7;
                break;
              case 'MONTHS':
                days = interval * 30; // Approximation
                break;
            }

            customRepeatConfig = CustomRepeatConfig(
              minutes: minutes,
              hours: hours,
              days: days,
              specificDays:
                  (config['days_of_week'] as List?)?.cast<int>().toSet(),
              endDate: config['end_date'] != null
                  ? DateTime.tryParse(config['end_date'])
                  : null,
            );
          }

          final reminder = Reminder(
            title: data['title']?.toString() ?? 'Untitled Reminder',
            description:
                data['context']?.toString() ?? data['description']?.toString(),
            scheduledTime: DateTime.parse(data['due_date']),
            repeatType: _parseRepeatType(data['repeat_type']),
            isNotificationEnabled: true,
            isMultiTime: isMultiTime,
            timeSlots: timeSlots ?? [],
            customRepeatConfig: customRepeatConfig,
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
- "NONE" for one-time tasks (default)
- "DAILY" for tasks that repeat every day
- "WEEKLY" for tasks that repeat weekly (meetings, appointments)
- "MONTHLY" for tasks that repeat monthly (bills, reports)
- "CUSTOM" for complex patterns like "every Monday and Thursday" or "every 2 weeks"

### Multi-Time Reminder Detection:
Detect when a reminder has MULTIPLE time slots per day:
- "Take medication 3 times daily at 8am, 2pm, and 8pm" → is_multi_time: true, time_slots: ["08:00", "14:00", "20:00"]
- "Check email twice a day at 9am and 5pm" → is_multi_time: true, time_slots: ["09:00", "17:00"]
- "Drink water every 2 hours" → is_multi_time: true with appropriate time slots
- Single-time reminders → is_multi_time: false, time_slots: []

### Custom Repeat Configuration:
For CUSTOM repeat types, provide configuration:
- "Every Monday and Thursday" → {interval: 1, frequency: "WEEKS", days_of_week: [1, 4]}
- "Every 2 weeks" → {interval: 2, frequency: "WEEKS", days_of_week: null}
- "Every 3 days" → {interval: 3, frequency: "DAYS", days_of_week: null}
- Days: 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday, 7=Sunday

## OUTPUT FORMAT
Always respond with valid JSON matching this exact schema:
{
  "reminders": [
    {
      "title": "Clear, actionable title",
      "context": "Detailed description with full context",
      "due_date": "YYYY-MM-DDTHH:MM:SS",
      "repeat_type": "NONE|DAILY|WEEKLY|MONTHLY|CUSTOM",
      "is_multi_time": false,
      "time_slots": [],
      "custom_repeat_config": null
    }
  ],
  "parsing_confidence": 0.95,
  "ambiguities": ["any unclear aspects requiring clarification"]
}

## EXAMPLES

Example 1 - Simple reminders:
Input: "Call dentist tomorrow morning"
Output: {
  "reminders": [{
    "title": "Call dentist",
    "context": "Schedule or follow up on dental appointment",
    "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)))}T09:00:00",
    "repeat_type": "NONE",
    "is_multi_time": false,
    "time_slots": [],
    "custom_repeat_config": null
  }],
  "parsing_confidence": 0.95,
  "ambiguities": []
}

Example 2 - Multi-time reminder:
Input: "Take medication 3 times daily at 8am, 2pm, and 10pm"
Output: {
  "reminders": [{
    "title": "Take medication",
    "context": "Take prescribed medication three times throughout the day",
    "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now())}T08:00:00",
    "repeat_type": "DAILY",
    "is_multi_time": true,
    "time_slots": [
      {"time": "08:00", "description": "Morning dose"},
      {"time": "14:00", "description": "Afternoon dose"},
      {"time": "22:00", "description": "Evening dose"}
    ],
    "custom_repeat_config": null
  }],
  "parsing_confidence": 0.98,
  "ambiguities": []
}

Example 3 - Custom repeat:
Input: "Team meeting every Monday and Thursday at 2pm"
Output: {
  "reminders": [{
    "title": "Team meeting",
    "context": "Recurring team meeting on Mondays and Thursdays",
    "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now())}T14:00:00",
    "repeat_type": "CUSTOM",
    "is_multi_time": false,
    "time_slots": [],
    "custom_repeat_config": {
      "interval": 1,
      "frequency": "WEEKS",
      "days_of_week": [1, 4],
      "end_date": null
    }
  }],
  "parsing_confidence": 0.96,
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
      case 'custom':
        return RepeatType.custom;
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
