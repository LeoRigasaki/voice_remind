// test/ai_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() {
  group('AI Integration Tests', () {
    setUpAll(() async {
      // Load environment variables before running tests
      await dotenv.load(fileName: ".env");
    });

    test('Environment Variables Test', () {
      final geminiKey = dotenv.env['GEMINI_API_KEY'];
      final groqKey = dotenv.env['GROQ_API_KEY'];

      expect(geminiKey, isNotNull,
          reason: 'GEMINI_API_KEY not found in .env file');
      expect(groqKey, isNotNull, reason: 'GROQ_API_KEY not found in .env file');
      expect(geminiKey!.isNotEmpty, isTrue, reason: 'GEMINI_API_KEY is empty');
      expect(groqKey!.isNotEmpty, isTrue, reason: 'GROQ_API_KEY is empty');

      print('✅ Environment variables loaded successfully');
      print('📍 Gemini key: ${geminiKey.substring(0, 10)}...');
      print('📍 Groq key: ${groqKey.substring(0, 10)}...');
    });

    test('Enhanced Gemini Structured Output Test', () async {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        fail('GEMINI_API_KEY not found in environment variables');
      }

      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: geminiApiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1, // Lower for more consistent parsing
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
                      'context': Schema(SchemaType.string),
                      'priority': Schema(SchemaType.string),
                      'due_date': Schema(SchemaType.string),
                      'repeat_type': Schema(SchemaType.string),
                      'tags': Schema(SchemaType.array,
                          items: Schema(SchemaType.string)),
                      'space_name': Schema(SchemaType.string),
                      'estimated_duration': Schema(SchemaType.string),
                      'location': Schema(SchemaType.string),
                    },
                    requiredProperties: [
                      'title',
                      'context',
                      'priority',
                      'due_date',
                      'tags'
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

        // Build comprehensive prompt
        final systemPrompt = buildEnhancedSystemPrompt();
        final userInput =
            'Create reminders: call dentist tomorrow morning, review budget report by Friday, buy groceries for Saturday dinner party';
        final fullPrompt = '$systemPrompt\n\nUser Input: "$userInput"';

        print('🟡 GEMINI REQUEST:');
        print('=' * 80);
        print('MODEL: gemini-2.5-flash');
        print('TEMPERATURE: 0.1');
        print('MAX_TOKENS: 2048');
        print('\nFULL PROMPT:');
        print(fullPrompt);
        print('=' * 80);

        final response =
            await model.generateContent([Content.text(fullPrompt)]);

        print('\n🟡 GEMINI RESPONSE:');
        print('=' * 80);
        print(response.text ?? 'No response text');
        print('=' * 80);

        // Parse JSON to verify structure
        final jsonResponse = jsonDecode(response.text!);
        expect(jsonResponse['reminders'], isA<List>());
        expect(jsonResponse['reminders'].length, greaterThan(0));

        // Validate each reminder has required fields
        for (final reminder in jsonResponse['reminders']) {
          expect(reminder['title'], isA<String>());
          expect(reminder['context'], isA<String>());
          expect(reminder['priority'], isA<String>());
          expect(reminder['due_date'], isA<String>());
          expect(reminder['tags'], isA<List>());

          // Validate priority values
          expect(['HIGH', 'MEDIUM', 'LOW'], contains(reminder['priority']));

          // Try to parse date
          expect(() => DateTime.parse(reminder['due_date']), returnsNormally);
        }

        print(
            '\n✅ Gemini test passed with ${jsonResponse['reminders'].length} reminders!');
        print(
            '📊 Parsing confidence: ${jsonResponse['parsing_confidence'] ?? 'N/A'}');
        print('⚠️  Ambiguities: ${jsonResponse['ambiguities'] ?? []}');
      } catch (e) {
        print('❌ Gemini test failed: $e');
        rethrow;
      }
    });

    test('Enhanced Groq Structured Output Test', () async {
      final groqApiKey = dotenv.env['GROQ_API_KEY'];
      if (groqApiKey == null || groqApiKey.isEmpty) {
        fail('GROQ_API_KEY not found in environment variables');
      }

      try {
        const url = 'https://api.groq.com/openai/v1/chat/completions';

        final systemPrompt = buildEnhancedSystemPrompt();
        final userInput =
            'Create reminders: call dentist tomorrow morning, review budget report by Friday, buy groceries for Saturday dinner party';

        final requestBody = {
          'model': 'deepseek-r1-distill-llama-70b',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userInput}
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
          'max_tokens': 2048,
        };

        print('🔵 GROQ REQUEST:');
        print('=' * 80);
        print('MODEL: deepseek-r1-distill-llama-70b');
        print('TEMPERATURE: 0.1');
        print('MAX_TOKENS: 2048');
        print('\nSYSTEM PROMPT:');
        print(systemPrompt);
        print('\nUSER INPUT:');
        print(userInput);
        print('=' * 80);

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $groqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode != 200) {
          print('HTTP Error: ${response.statusCode}');
          print('Response: ${response.body}');
          fail('Groq API request failed');
        }

        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        print('\n🔵 GROQ RESPONSE:');
        print('=' * 80);
        print(content);
        print('=' * 80);

        // Parse JSON to verify structure
        final jsonResponse = jsonDecode(content);
        expect(jsonResponse['reminders'], isA<List>());
        expect(jsonResponse['reminders'].length, greaterThan(0));

        // Validate each reminder has required fields
        for (final reminder in jsonResponse['reminders']) {
          expect(reminder['title'], isA<String>());
          expect(reminder['context'], isA<String>());
          expect(reminder['priority'], isA<String>());
          expect(reminder['due_date'], isA<String>());
          expect(reminder['tags'], isA<List>());

          // Validate priority values
          expect(['HIGH', 'MEDIUM', 'LOW'], contains(reminder['priority']));

          // Try to parse date
          expect(() => DateTime.parse(reminder['due_date']), returnsNormally);
        }

        print(
            '\n✅ Groq test passed with ${jsonResponse['reminders'].length} reminders!');
        print(
            '📊 Parsing confidence: ${jsonResponse['parsing_confidence'] ?? 'N/A'}');
        print('⚠️  Ambiguities: ${jsonResponse['ambiguities'] ?? []}');
      } catch (e) {
        print('❌ Groq test failed: $e');
        rethrow;
      }
    });

    test('API Speed Comparison with Enhanced Prompts', () async {
      print('🚀 Running enhanced speed comparison...');

      final geminiApiKey = dotenv.env['GEMINI_API_KEY']!;
      final groqApiKey = dotenv.env['GROQ_API_KEY']!;

      final systemPrompt = buildEnhancedSystemPrompt();
      const userInput = 'Remind me to buy milk tomorrow at 10am';
      final fullPrompt = '$systemPrompt\n\nUser Input: "$userInput"';

      // Test Gemini speed
      final geminiStart = DateTime.now();
      final geminiModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
      );
      await geminiModel.generateContent([Content.text(fullPrompt)]);
      final geminiDuration = DateTime.now().difference(geminiStart);

      // Test Groq speed
      final groqStart = DateTime.now();
      await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek-r1-distill-llama-70b',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userInput}
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
        }),
      );
      final groqDuration = DateTime.now().difference(groqStart);

      print('⏱️  Gemini: ${geminiDuration.inMilliseconds}ms');
      print('⏱️  Groq: ${groqDuration.inMilliseconds}ms');
      print('🏆 Winner: ${groqDuration < geminiDuration ? "Groq" : "Gemini"}');

      // Performance analysis
      final speedDifference =
          (geminiDuration.inMilliseconds - groqDuration.inMilliseconds).abs();
      final fasterService = groqDuration < geminiDuration ? "Groq" : "Gemini";
      final slowerService = groqDuration < geminiDuration ? "Gemini" : "Groq";

      print(
          '📈 $fasterService is ${speedDifference}ms faster than $slowerService');
      print(
          '📊 Speed improvement: ${((speedDifference / (groqDuration < geminiDuration ? geminiDuration.inMilliseconds : groqDuration.inMilliseconds)) * 100).toStringAsFixed(1)}%');
    });

    test('Error Handling Test', () async {
      // Test with invalid API key
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: 'invalid_key',
        );

        await model.generateContent([Content.text('test')]);
        fail('Should have thrown an error with invalid API key');
      } catch (e) {
        print('✅ Error handling works: $e');
        expect(e, isA<Exception>());
      }
    });

    test('Real-world Usage Test', () async {
      final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        fail('GEMINI_API_KEY not found in environment variables');
      }

      // Test various real-world inputs
      final testInputs = [
        'Call mom this evening',
        'Weekly team meeting every Monday at 10am starting next week',
        'Buy birthday gift for Sarah before her party on Saturday',
        'Submit project report by end of month',
        'Take medication daily at 8am and 8pm',
        'Grocery shopping tomorrow: milk, bread, eggs, and vegetables',
      ];

      for (final input in testInputs) {
        print('\n🧪 Testing input: "$input"');

        try {
          final model = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: geminiApiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.1,
            ),
          );

          final systemPrompt = buildEnhancedSystemPrompt();
          final fullPrompt = '$systemPrompt\n\nUser Input: "$input"';

          final response =
              await model.generateContent([Content.text(fullPrompt)]);
          final jsonResponse = jsonDecode(response.text!);

          print('   ✅ Parsed ${jsonResponse['reminders'].length} reminder(s)');
          for (int i = 0; i < jsonResponse['reminders'].length; i++) {
            final reminder = jsonResponse['reminders'][i];
            print(
                '   📝 ${i + 1}. ${reminder['title']} - ${reminder['due_date']} (${reminder['priority']})');
          }
        } catch (e) {
          print('   ❌ Failed: $e');
        }
      }
    });
  });
}

// Helper function to get current time context
String getCurrentTimeContext() {
  final now = DateTime.now();
  final timeZone = now.timeZoneName;
  final dayOfWeek = DateFormat('EEEE').format(now);
  final date = DateFormat('MMMM d, yyyy').format(now);
  final time = DateFormat('h:mm a').format(now);
  final weekOfYear = getWeekOfYear(now);

  return '''
CURRENT TEMPORAL CONTEXT:
- Current Date & Time: $dayOfWeek, $date at $time ($timeZone)
- Unix Timestamp: ${now.millisecondsSinceEpoch}
- ISO 8601: ${now.toIso8601String()}
- Week of Year: $weekOfYear
- Is Weekend: ${now.weekday >= 6}
- Season: ${getCurrentSeason(now)}

RELATIVE TIME CALCULATIONS:
- Today: $date
- Tomorrow: ${DateFormat('MMMM d, yyyy').format(now.add(Duration(days: 1)))}
- Next Week: Week starting ${DateFormat('MMMM d').format(now.add(Duration(days: 7 - now.weekday + 1)))}
- Next Month: ${DateFormat('MMMM yyyy').format(DateTime(now.year, now.month + 1))}''';
}

// Helper function to build enhanced system prompt
String buildEnhancedSystemPrompt() {
  final timeContext = getCurrentTimeContext();
  final availableSpaces = ['Work', 'Personal', 'Health', 'Shopping', 'Finance'];

  return '''
# VOICEREMIND AI ASSISTANT

You are an intelligent reminder parsing system for VoiceRemind app. Your ONLY job is to convert natural language into structured reminder data.

## TEMPORAL CONTEXT
$timeContext

## AVAILABLE SPACES
${availableSpaces.join(', ')}

## CORE RESPONSIBILITIES
1. Parse natural language into structured reminders
2. Intelligently determine dates/times from relative expressions
3. Assign appropriate priority levels
4. Extract relevant tags and context
5. Map to existing spaces when relevant

## PARSING RULES
### Date/Time Interpretation:
- "tomorrow" = ${DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1)))}
- "next week" = Week of ${DateFormat('MMM d').format(DateTime.now().add(Duration(days: 7)))}
- "in 2 hours" = ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now().add(Duration(hours: 2)))}
- Default time for date-only: 09:00 (morning) unless context suggests otherwise
- Business hours: 9 AM - 5 PM for work-related tasks
- Evening tasks: Default to 7 PM

### Priority Assignment:
- HIGH: Urgent deadlines, important meetings, time-critical tasks
- MEDIUM: Regular tasks, scheduled activities, routine reminders
- LOW: Optional tasks, ideas, non-urgent reminders

### Context Extraction:
- Include WHO (person/contact), WHAT (specific action), WHERE (location), WHY (purpose)
- Extract actionable verbs (call, email, buy, review, submit, etc.)
- Identify categories (work, personal, health, shopping, etc.)

### Space Mapping:
- Match task categories to available spaces
- Work: meetings, reports, deadlines, professional tasks
- Personal: family, friends, personal appointments
- Health: medical appointments, medication, exercise
- Shopping: groceries, purchases, errands
- Finance: bills, payments, financial tasks
- Default to null if no clear space match

## OUTPUT FORMAT
Always respond with valid JSON matching this exact schema:
{
  "reminders": [
    {
      "title": "Clear, actionable title (max 50 chars)",
      "context": "Detailed description with context",
      "priority": "HIGH|MEDIUM|LOW",
      "due_date": "YYYY-MM-DD HH:MM",
      "repeat_type": "none|daily|weekly|monthly",
      "tags": ["array", "of", "relevant", "tags"],
      "space_name": "matching_space_name_or_null",
      "estimated_duration": "5m|15m|30m|1h|2h+",
      "location": "location_if_mentioned_or_null"
    }
  ],
  "parsing_confidence": 0.95,
  "ambiguities": ["any unclear aspects requiring clarification"]
}

## EXAMPLES
Input: "Call dentist tomorrow morning and buy groceries"
Output: {
  "reminders": [
    {
      "title": "Call dentist",
      "context": "Schedule or follow up on dental appointment",
      "priority": "MEDIUM",
      "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1)))} 09:00",
      "repeat_type": "none",
      "tags": ["health", "appointment", "phone"],
      "space_name": "Health",
      "estimated_duration": "15m",
      "location": null
    },
    {
      "title": "Buy groceries",
      "context": "Purchase groceries and household items",
      "priority": "MEDIUM",
      "due_date": "${DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 1)))} 10:00",
      "repeat_type": "none",
      "tags": ["shopping", "food", "errands"],
      "space_name": "Shopping",
      "estimated_duration": "1h",
      "location": "grocery store"
    }
  ],
  "parsing_confidence": 0.92,
  "ambiguities": []
}

CRITICAL: Always return valid JSON. Never include explanations outside the JSON structure.''';
}

// Helper function to get week of year
int getWeekOfYear(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final dayOfYear = date.difference(firstDayOfYear).inDays + 1;
  return ((dayOfYear - 1) / 7).floor() + 1;
}

// Helper function to get current season
String getCurrentSeason(DateTime date) {
  final month = date.month;
  if (month >= 3 && month <= 5) return 'Spring';
  if (month >= 6 && month <= 8) return 'Summer';
  if (month >= 9 && month <= 11) return 'Fall';
  return 'Winter';
}

// Helper function to validate reminder structure
bool isValidReminder(Map<String, dynamic> reminder) {
  const required = ['title', 'context', 'priority', 'due_date', 'tags'];

  for (final field in required) {
    if (!reminder.containsKey(field)) {
      return false;
    }
  }

  return reminder['title'] is String &&
      reminder['context'] is String &&
      reminder['priority'] is String &&
      reminder['due_date'] is String &&
      reminder['tags'] is List;
}
