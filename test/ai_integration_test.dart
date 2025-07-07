// test/ai_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

    test('Gemini Structured Output Test', () async {
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
                      'tags': Schema(
                        SchemaType.array,
                        items: Schema(SchemaType.string),
                      ),
                    },
                  ),
                ),
              },
            ),
          ),
        );

        final response = await model.generateContent([
          Content.text(
              'Create 3 reminders: call dentist tomorrow, review budget report by Friday, buy groceries for Saturday dinner party')
        ]);

        print('🟡 Gemini Response:');
        print(response.text ?? '');

        // Parse JSON to verify structure
        final jsonResponse = jsonDecode(response.text!);
        expect(jsonResponse['reminders'], isA<List>());
        expect(jsonResponse['reminders'].length, equals(3));

        // Validate each reminder has required fields
        for (final reminder in jsonResponse['reminders']) {
          expect(reminder['title'], isA<String>());
          expect(reminder['context'], isA<String>());
          expect(reminder['priority'], isA<String>());
          expect(reminder['due_date'], isA<String>());
          expect(reminder['tags'], isA<List>());
        }

        print(
            '✅ Gemini test passed with ${jsonResponse['reminders'].length} reminders!');
      } catch (e) {
        print('❌ Gemini test failed: $e');
        rethrow;
      }
    });

    test('Groq Structured Output Test', () async {
      final groqApiKey = dotenv.env['GROQ_API_KEY'];
      if (groqApiKey == null || groqApiKey.isEmpty) {
        fail('GROQ_API_KEY not found in environment variables');
      }

      try {
        const url = 'https://api.groq.com/openai/v1/chat/completions';

        final requestBody = {
          'model': 'deepseek-r1-distill-llama-70b',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a JSON API. Always respond with valid JSON matching this schema: {"reminders": [{"title": "string", "context": "string", "priority": "string", "due_date": "string", "tags": ["string"]}]}'
            },
            {
              'role': 'user',
              'content':
                  'Create 3 reminders: call dentist tomorrow, review budget report by Friday, buy groceries for Saturday dinner party'
            }
          ],
          'response_format': {'type': 'json_object'}
        };

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

        print('🔵 Groq Response:');
        print(content);

        // Parse JSON to verify structure
        final jsonResponse = jsonDecode(content);
        expect(jsonResponse['reminders'], isA<List>());
        expect(jsonResponse['reminders'].length, equals(3));

        // Validate each reminder has required fields
        for (final reminder in jsonResponse['reminders']) {
          expect(reminder['title'], isA<String>());
          expect(reminder['context'], isA<String>());
          expect(reminder['priority'], isA<String>());
          expect(reminder['due_date'], isA<String>());
          expect(reminder['tags'], isA<List>());
        }

        print(
            '✅ Groq test passed with ${jsonResponse['reminders'].length} reminders!');
      } catch (e) {
        print('❌ Groq test failed: $e');
        rethrow;
      }
    });

    test('API Speed Comparison', () async {
      print('🚀 Running speed comparison...');

      final geminiApiKey = dotenv.env['GEMINI_API_KEY']!;
      final groqApiKey = dotenv.env['GROQ_API_KEY']!;

      const prompt = 'Create 1 reminder for: buy milk tomorrow';

      // Test Gemini speed
      final geminiStart = DateTime.now();
      final geminiModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: geminiApiKey,
        generationConfig:
            GenerationConfig(responseMimeType: 'application/json'),
      );
      await geminiModel.generateContent([Content.text(prompt)]);
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
            {'role': 'user', 'content': prompt}
          ],
          'response_format': {'type': 'json_object'}
        }),
      );
      final groqDuration = DateTime.now().difference(groqStart);

      print('⏱️  Gemini: ${geminiDuration.inMilliseconds}ms');
      print('⏱️  Groq: ${groqDuration.inMilliseconds}ms');
      print('🏆 Winner: ${groqDuration < geminiDuration ? "Groq" : "Gemini"}');
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
  });
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
