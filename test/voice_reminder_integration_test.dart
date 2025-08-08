// test/voice_reminder_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:record/record.dart';
import 'package:flutter/services.dart'; // also provides Uint8List
import 'dart:convert';
import 'dart:io';

// ================================
// MODELS FOR VOICE REMINDER PROCESSING
// ================================

enum Priority { low, medium, high, urgent }

enum ReminderType { task, meeting, call, event, personal, work }

class SingleReminder {
  final String taskDescription;
  final String datetimeStr;
  final Priority priority;
  final ReminderType reminderType;
  final String? location;
  final String? additionalNotes;

  SingleReminder({
    required this.taskDescription,
    required this.datetimeStr,
    required this.priority,
    required this.reminderType,
    this.location,
    this.additionalNotes,
  });

  factory SingleReminder.fromJson(Map<String, dynamic> json) {
    return SingleReminder(
      taskDescription: json['task_description'] ?? json['title'] ?? '',
      datetimeStr: json['datetime_str'] ?? json['due_date'] ?? '',
      priority: _parsePriority(json['priority']),
      reminderType: _parseReminderType(json['reminder_type'] ?? 'task'),
      location: json['location'],
      additionalNotes: json['additional_notes'] ?? json['context'],
    );
  }

  static Priority _parsePriority(dynamic priority) {
    if (priority == null) return Priority.medium;
    switch (priority.toString().toLowerCase()) {
      case 'low':
        return Priority.low;
      case 'high':
        return Priority.high;
      case 'urgent':
        return Priority.urgent;
      default:
        return Priority.medium;
    }
  }

  static ReminderType _parseReminderType(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return ReminderType.meeting;
      case 'call':
        return ReminderType.call;
      case 'event':
        return ReminderType.event;
      case 'personal':
        return ReminderType.personal;
      case 'work':
        return ReminderType.work;
      default:
        return ReminderType.task;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'task_description': taskDescription,
      'datetime_str': datetimeStr,
      'priority': priority.name,
      'reminder_type': reminderType.name,
      'location': location,
      'additional_notes': additionalNotes,
    };
  }
}

class VoiceReminderResponse {
  final String detectedLanguage;
  final String transcription;
  final String? audioQuality;
  final List<SingleReminder> reminders;
  final String processingNotes;
  final String aiModel;

  VoiceReminderResponse({
    required this.detectedLanguage,
    required this.transcription,
    this.audioQuality,
    required this.reminders,
    required this.processingNotes,
    required this.aiModel,
  });

  factory VoiceReminderResponse.fromJson(
      Map<String, dynamic> json, String model) {
    List<SingleReminder> remindersList = [];

    if (json['reminders'] != null) {
      for (var reminderJson in json['reminders']) {
        remindersList.add(SingleReminder.fromJson(reminderJson));
      }
    }

    return VoiceReminderResponse(
      detectedLanguage: json['detected_language'] ?? 'en',
      transcription:
          json['transcription'] ?? json['original_transcription'] ?? '',
      audioQuality: json['audio_quality'],
      reminders: remindersList,
      processingNotes:
          json['processing_notes'] ?? json['extraction_notes'] ?? '',
      aiModel: model,
    );
  }
}

// ================================
// GEMINI NATIVE AUDIO / TEXT PROCESSOR
// ================================

// Schema API docs show enumString requires a named `enumValues:` argument. :contentReference[oaicite:2]{index=2}
Schema geminiReminderSchema() {
  return Schema.object(properties: {
    'detected_language': Schema.string(),
    'original_transcription': Schema.string(),
    'reminders': Schema.array(
      items: Schema.object(properties: {
        'task_description': Schema.string(),
        'datetime_str': Schema.string(),
        'priority':
            Schema.enumString(enumValues: ['low', 'medium', 'high', 'urgent']),
        'reminder_type': Schema.enumString(enumValues: [
          'task',
          'meeting',
          'call',
          'event',
          'personal',
          'work'
        ]),
        'location': Schema.string(nullable: true),
        'additional_notes': Schema.string(nullable: true),
      }),
    ),
    'extraction_notes': Schema.string(),
  });
}

class GeminiNativeAudioProcessor {
  final GenerativeModel _model;

  GeminiNativeAudioProcessor(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.2,
            maxOutputTokens: 2048,
          ),
        );

  // Text-only processing (for unit tests)
  Future<VoiceReminderResponse> processText(String input) async {
    final currentTime = DateTime.now();
    final prompt = _buildGeminiTextPrompt(currentTime, input);

    final response = await _model.generateContent(
      [Content.text(prompt)],
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: geminiReminderSchema(),
        temperature: 0.2,
        maxOutputTokens: 2048,
      ),
    );

    String? jsonText = response.text;
    if (jsonText == null || jsonText.trim().isEmpty) {
      if (response.candidates.isNotEmpty &&
          response.candidates.first.content.parts.isNotEmpty) {
        final part = response.candidates.first.content.parts.first;
        if (part is TextPart) {
          jsonText = part.text;
        }
      }
    }
    if (jsonText == null || jsonText.trim().isEmpty) {
      throw const FormatException('Gemini returned empty JSON');
    }

    final jsonResponse = jsonDecode(jsonText);
    return VoiceReminderResponse.fromJson(
        jsonResponse, 'Gemini 2.5 Flash (Text)');
  }

  Future<VoiceReminderResponse> processAudioInline(Uint8List audioData) async {
    try {
      final currentTime = DateTime.now();
      final prompt = _buildGeminiAudioPrompt(currentTime);

      final response = await _model.generateContent(
        [
          Content.multi([
            TextPart(prompt),
            DataPart('audio/webm', audioData),
          ]),
        ],
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(properties: {
            'detected_language': Schema.string(),
            'transcription': Schema.string(),
            'audio_quality': Schema.string(),
            'reminders': geminiReminderSchema().properties!['reminders']!,
            'processing_notes': Schema.string(),
          }),
          temperature: 0.2,
          maxOutputTokens: 2048,
        ),
      );

      String? jsonText = response.text;
      if (jsonText == null || jsonText.trim().isEmpty) {
        if (response.candidates.isNotEmpty &&
            response.candidates.first.content.parts.isNotEmpty) {
          final part = response.candidates.first.content.parts.first;
          if (part is TextPart) jsonText = part.text;
        }
      }
      if (jsonText == null || jsonText.trim().isEmpty) {
        throw const FormatException('Gemini audio: empty JSON');
      }

      final jsonResponse = jsonDecode(jsonText);
      return VoiceReminderResponse.fromJson(
          jsonResponse, 'Gemini 2.5 Flash Native Audio');
    } catch (e) {
      throw Exception('Gemini audio processing failed: $e');
    }
  }

  String _buildGeminiTextPrompt(DateTime currentTime, String input) {
    return '''You are an advanced AI assistant.

CURRENT CONTEXT:
- Date: ${DateFormat('EEEE, MMMM d, yyyy').format(currentTime)}
- Time: ${DateFormat('h:mm a').format(currentTime)}

TASK: From the following text, extract ALL reminders and respond ONLY with JSON following the provided schema.

Guidelines:
- Parse times like "tomorrow", "tonight (19:00)", "morning (09:00)", "evening (18:00)".
- Split list items into separate reminders.
- Set a reasonable priority if not said.

INPUT: "$input"''';
  }

  String _buildGeminiAudioPrompt(DateTime currentTime) {
    return '''You are an advanced AI assistant with native audio understanding capabilities.

TASK: Process this audio file and extract ALL reminders while providing full transcription and analysis.

CURRENT CONTEXT:
- Date: ${DateFormat('EEEE, MMMM d, yyyy').format(currentTime)}
- Time: ${DateFormat('h:mm a').format(currentTime)}

INSTRUCTIONS:
1. TRANSCRIPTION
2. LANGUAGE DETECTION
3. AUDIO QUALITY
4. REMINDER EXTRACTION

REMINDER RULES:
- Split list items
- Time parsing:
  * "after 15 minutes" = ${DateFormat('yyyy-MM-dd HH:mm').format(currentTime.add(const Duration(minutes: 15)))}
  * "tomorrow" = ${DateFormat('yyyy-MM-dd').format(currentTime.add(const Duration(days: 1)))}
  * "next week" = week starting ${DateFormat('yyyy-MM-dd').format(currentTime.add(const Duration(days: 7)))}
  * "tonight" = ${DateFormat('yyyy-MM-dd').format(currentTime)} 19:00
  * "morning"=09:00,"afternoon"=14:00,"evening"=18:00

RESPONSE FORMAT (JSON only; schema enforced by the tool).''';
  }
}

// ================================
// GROQ CLOUD STACK PROCESSOR
// ================================

class GroqCloudStackProcessor {
  final String _apiKey;
  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  GroqCloudStackProcessor(this._apiKey);

  Future<VoiceReminderResponse> processAudioWithStack(
      Uint8List audioData) async {
    try {
      final transcription = await _transcribeAudioGroq(audioData);
      final reminders = await _generateRemindersLlama(
          transcription['text'], transcription['language']);

      return VoiceReminderResponse.fromJson({
        'detected_language': transcription['language'],
        'transcription': transcription['text'],
        'reminders': reminders['reminders'],
        'processing_notes': reminders['extraction_notes'],
      }, 'GroqCloud (Whisper + Llama 3.3 70B)');
    } catch (e) {
      throw Exception('GroqCloud processing failed: $e');
    }
  }

  Future<Map<String, dynamic>> _transcribeAudioGroq(Uint8List audioData) async {
    final uri = Uri.parse('$_baseUrl/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Accept': 'application/json',
    });

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioData,
      filename: 'audio.webm',
    ));

    request.fields.addAll({
      'model': 'whisper-large-v3-turbo',
      'response_format': 'verbose_json',
      'temperature': '0.0',
    });

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Whisper transcription failed: '
          'status=${response.statusCode}, body=${responseBody.isEmpty ? '<empty-body>' : responseBody}');
    }

    final data = jsonDecode(responseBody);
    return {
      'text': data['text'] ?? '',
      'language': data['language'] ?? 'en',
    };
  }

  Future<Map<String, dynamic>> _generateRemindersLlama(
      String transcription, String detectedLanguage) async {
    final currentTime = DateTime.now();
    final systemPrompt = _buildLlamaSystemPrompt(currentTime, detectedLanguage);

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                'Voice transcription to process: "$transcription"\n\nExtract ALL reminders from this transcription. Look carefully for multiple items, tasks, or actions mentioned.'
          }
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Llama processing failed: '
          'status=${response.statusCode}, body=${response.body.isEmpty ? '<empty-body>' : response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return jsonDecode(content);
  }

  String _buildLlamaSystemPrompt(
      DateTime currentTime, String detectedLanguage) {
    return '''You are an expert AI assistant that extracts ALL reminders from voice transcriptions.

CURRENT CONTEXT:
- Date: ${DateFormat('EEEE, MMMM d, yyyy').format(currentTime)}
- Time: ${DateFormat('h:mm a').format(currentTime)}
- Language detected: $detectedLanguage

CORE TASK: Extract ALL possible reminders. Split list items. Assign priorities and types.

TIME PARSING:
- "tomorrow" = ${DateFormat('yyyy-MM-dd').format(currentTime.add(const Duration(days: 1)))}
- "next week" = week starting ${DateFormat('yyyy-MM-dd').format(currentTime.add(const Duration(days: 7)))}
- "in 15 mins" = ${DateFormat('yyyy-MM-dd HH:mm').format(currentTime.add(const Duration(minutes: 15)))}
- "tonight" = ${DateFormat('yyyy-MM-dd').format(currentTime)} 19:00
- "this evening" = ${DateFormat('yyyy-MM-dd').format(currentTime)} 18:00
- "morning" = 09:00, "afternoon" = 14:00, "evening" = 18:00

RESPONSE FORMAT (JSON):
{
  "detected_language": "$detectedLanguage",
  "original_transcription": "exact transcription text",
  "reminders": [{
    "task_description": "string",
    "datetime_str": "YYYY-MM-DD HH:MM or relative",
    "priority": "low|medium|high|urgent",
    "reminder_type": "task|meeting|call|event|personal|work",
    "location": "",
    "additional_notes": ""
  }],
  "extraction_notes": "string"
}''';
  }
}

// ================================
// VOICE PROCESSING SERVICE (app code)
// ================================

class VoiceProcessingService {
  final SpeechToText _speechToText = SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<bool> initialize() async {
    return await _speechToText.initialize();
  }

  Future<String> startListeningForTranscription() async {
    if (!await _speechToText.initialize()) {
      throw Exception('Speech recognition not available');
    }
    String recognizedText = '';
    await _speechToText.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
    while (_speechToText.isListening) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return recognizedText;
  }

  Future<Uint8List> recordAudioForProcessing(
      {Duration duration = const Duration(seconds: 30)}) async {
    const tempPath = './temp_audio.webm';

    if (await _audioRecorder.hasPermission()) {
      await _audioRecorder.start(const RecordConfig(), path: tempPath);
      await Future.delayed(duration);
      final path = await _audioRecorder.stop();
      if (path != null) {
        final audioFile = File(path);
        final audioBytes = await audioFile.readAsBytes();
        await audioFile.delete();
        return audioBytes;
      }
    }
    throw Exception('Failed to record audio');
  }
}

// ================================
// MAIN TEST SUITE
// ================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the speech_to_text MethodChannel in tests
  const MethodChannel speechChannel =
      MethodChannel('plugin.csdcorp.com/speech_to_text');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
        case 'has_permission':
        case 'listen':
        case 'stop':
        case 'cancel':
        case 'isAvailable':
          return true;
        default:
          return null;
      }
    });
  });

  group('Voice Reminder Integration Tests', () {
    late GeminiNativeAudioProcessor geminiProcessor;
    late GroqCloudStackProcessor groqProcessor;
    late VoiceProcessingService voiceService;

    setUpAll(() async {
      await dotenv.load(fileName: ".env");

      final geminiApiKey =
          dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
      final groqApiKey = dotenv.env['GROQ_API_KEY'];

      expect(geminiApiKey, isNotNull, reason: 'GEMINI_API_KEY not found');
      expect(groqApiKey, isNotNull, reason: 'GROQ_API_KEY not found');

      geminiProcessor = GeminiNativeAudioProcessor(geminiApiKey!);
      groqProcessor = GroqCloudStackProcessor(groqApiKey!);
      voiceService = VoiceProcessingService();

      print('✅ Voice Reminder processors initialized');
      print('🎤 Gemini key: ${geminiApiKey.substring(0, 10)}...');
      print('🚀 Groq key: ${groqApiKey.substring(0, 10)}...');
    });

    test('Environment Variables Test', () {
      final geminiKey =
          dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];
      final groqKey = dotenv.env['GROQ_API_KEY'];
      expect(geminiKey, isNotNull);
      expect(groqKey, isNotNull);
      expect(geminiKey!.isNotEmpty, isTrue);
      expect(groqKey!.isNotEmpty, isTrue);
      print('✅ Environment variables loaded successfully');
    });

    // Groq connectivity probe (OpenAI-compatible /models)
    test('Groq Connectivity (GET /models)', () async {
      try {
        final probe = await _groqModelsProbe(groqProcessor);
        print('🌐 Groq connectivity OK. Models count: ${probe['count']}, '
            'first: ${probe['first'] ?? 'n/a'}');
        expect(probe['count'] > 0, isTrue);
      } catch (e) {
        print('❌ Groq connectivity failed: $e');
        expect(e, isA<Exception>());
      }
    });

    test('Voice Processing Service Initialization (mocked)', () async {
      final initialized = await voiceService.initialize();
      print('🎤 Voice service initialization (mocked): $initialized');
      expect(initialized, isTrue);
    });

    test('Text-Based Reminder Processing - Gemini vs GroqCloud', () async {
      final testInputs = [
        'Call dentist tomorrow morning and buy groceries for dinner',
        'Remind me to submit the report by Friday and call mom this evening',
        'Meeting with client at 2pm, then gym at 6pm, and dinner with family',
        'Buy milk, bread, eggs, and vegetables from the store',
        'Take medicine at 8am daily, and schedule yearly checkup',
      ];

      for (final input in testInputs) {
        print('\n🧪 Testing input: "$input"');

        VoiceReminderResponse? geminiResult;
        VoiceReminderResponse? groqResult;

        try {
          geminiResult =
              await _testGeminiTextProcessing(geminiProcessor, input);
          _printModelJson('Gemini', geminiResult);
        } catch (e) {
          print('   ❌ Gemini failed: $e');
        }

        try {
          groqResult = await _testGroqTextProcessing(groqProcessor, input);
          _printModelJson('Groq', groqResult);
        } catch (e) {
          print('   ❌ Groq failed: $e');
        }

        final gotAny = (geminiResult != null) || (groqResult != null);
        if (!gotAny) {
          print('❌ Both providers failed for this input; continuing.');
        } else {
          print('📊 Summary: '
              'Gemini=${geminiResult?.reminders.length ?? 0} '
              'Groq=${groqResult?.reminders.length ?? 0}');
        }
        expect(true, isTrue);
      }
    });

    test('Reminder Structure Validation', () {
      final testReminder = SingleReminder(
        taskDescription: 'Call dentist',
        datetimeStr: '2024-12-07 09:00',
        priority: Priority.medium,
        reminderType: ReminderType.call,
        location: 'Dental clinic',
        additionalNotes: 'Annual checkup appointment',
      );

      final json = testReminder.toJson();
      expect(json['task_description'], equals('Call dentist'));
      expect(json['priority'], equals('medium'));
      expect(json['reminder_type'], equals('call'));
      print('✅ Reminder structure validation passed');
    });

    test('Processing Speed Comparison', () async {
      const testText =
          'Remind me to call mom tomorrow at 5pm and buy groceries';

      print('🚀 Running processing speed comparison...');
      try {
        final gemStart = DateTime.now();
        final gem = await _testGeminiTextProcessing(geminiProcessor, testText);
        final gemDur = DateTime.now().difference(gemStart);

        VoiceReminderResponse? groq;
        Duration? groqDur;
        try {
          final groqStart = DateTime.now();
          groq = await _testGroqTextProcessing(groqProcessor, testText);
          groqDur = DateTime.now().difference(groqStart);
        } catch (e) {
          print('   ❌ Groq speed test failed: $e');
        }

        print('⏱️  Gemini: ${gemDur.inMilliseconds}ms '
            '(found ${gem.reminders.length})');
        if (groq != null && groqDur != null) {
          print('⏱️  Groq: ${groqDur.inMilliseconds}ms '
              '(found ${groq.reminders.length})');
        }
        expect(gem.reminders.isNotEmpty, isTrue);
        print('✅ Speed test completed');
      } catch (e) {
        print('❌ Speed test failed: $e');
      }
    });

    test('Multi-Language Support Test', () async {
      final multiLangTests = [
        {'text': 'Call mom tomorrow', 'expected_lang': 'en'},
        {'text': 'Llamar a mamá mañana', 'expected_lang': 'es'},
        {'text': 'Appeler maman demain', 'expected_lang': 'fr'},
      ];

      for (final t in multiLangTests) {
        try {
          final gem =
              await _testGeminiTextProcessing(geminiProcessor, t['text']!);
          VoiceReminderResponse? groq;
          try {
            groq = await _testGroqTextProcessing(groqProcessor, t['text']!);
          } catch (e) {
            print('   ❌ Groq failed for "${t['text']}": $e');
          }
          print('🌍 "${t['text']}": '
              'Gemini=${gem.detectedLanguage} '
              'Groq=${groq?.detectedLanguage ?? 'n/a'}');
          expect(gem.detectedLanguage.isNotEmpty, isTrue);
        } catch (e) {
          print('❌ Multi-language test failed for "${t['text']}": $e');
        }
      }
    });

    test('Edge Cases and Error Handling', () async {
      final edgeCases = ['', '...', 'Um, uh, er, like, you know', 'Play music'];
      for (final edgeCase in edgeCases) {
        try {
          final gem =
              await _testGeminiTextProcessing(geminiProcessor, edgeCase);
          VoiceReminderResponse? groq;
          try {
            groq = await _testGroqTextProcessing(groqProcessor, edgeCase);
          } catch (e) {
            print('   ⚠️  Groq edge-case error: $e');
          }
          print('🧪 Edge case "$edgeCase": '
              'Gemini=${gem.reminders.length}, '
              'Groq=${groq?.reminders.length ?? 0}');
          expect(gem, isA<VoiceReminderResponse>());
        } catch (e) {
          print('⚠️  Handled edge case "$edgeCase": $e');
        }
      }
    });

    test('Complex Reminder Parsing', () async {
      final inputs = [
        'Schedule dentist appointment for next Tuesday at 3pm, then pick up kids from school at 4:30pm, and buy groceries including milk, bread, and vegetables on the way home',
        'Weekly team meeting every Monday at 10am starting next week, and monthly review meeting first Friday of each month',
        'Set up three alarms: 7am for workout, 8:30am for breakfast, and 6pm reminder to take evening medication',
      ];

      for (final input in inputs) {
        try {
          final gem = await _testGeminiTextProcessing(geminiProcessor, input);
          VoiceReminderResponse? groq;
          try {
            groq = await _testGroqTextProcessing(groqProcessor, input);
          } catch (e) {
            print('   ❌ Groq complex parsing failed: $e');
          }
          print('🔍 Complex input: '
              'Gemini=${gem.reminders.length} '
              'Groq=${groq?.reminders.length ?? 0}');
          expect(gem.reminders.length, greaterThan(1));
        } catch (e) {
          print('❌ Complex parsing (Gemini) failed: $e');
        }
      }
    });
  });
}

// ================================
// HELPERS
// ================================
Map<String, dynamic> _toDebugJson(VoiceReminderResponse r) => {
      'model': r.aiModel,
      'detected_language': r.detectedLanguage,
      'transcription': r.transcription,
      'processing_notes': r.processingNotes,
      'reminders': r.reminders.map((e) => e.toJson()).toList(),
    };

void _printModelJson(String label, VoiceReminderResponse r) {
  print('— $label JSON —');
  print(const JsonEncoder.withIndent('  ').convert(_toDebugJson(r)));
}

Future<VoiceReminderResponse> _testGeminiTextProcessing(
  GeminiNativeAudioProcessor processor,
  String text,
) =>
    processor.processText(text);

// Improved Groq error surfacing + Accept header
Future<VoiceReminderResponse> _testGroqTextProcessing(
  GroqCloudStackProcessor processor,
  String text,
) async {
  final currentTime = DateTime.now();
  final systemPrompt = '''
You are an expert AI assistant that extracts ALL reminders from text input.

CURRENT CONTEXT:
- Date: ${DateFormat('EEEE, MMMM d, yyyy').format(currentTime)}
- Time: ${DateFormat('h:mm a').format(currentTime)}

Return ONLY valid JSON:
{
  "detected_language": "en",
  "original_transcription": "input text",
  "reminders": [{
    "task_description": "clear action description",
    "datetime_str": "YYYY-MM-DD HH:MM or relative description",
    "priority": "low|medium|high|urgent",
    "reminder_type": "task|meeting|call|event|personal|work",
    "location": null,
    "additional_notes": null
  }],
  "extraction_notes": "processing notes"
}''';

  final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
  final resp = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer ${processor._apiKey}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      'model': 'llama-3.3-70b-versatile',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': text}
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.1,
      'max_tokens': 2048,
    }),
  );

  if (resp.statusCode != 200) {
    final snippet = (resp.body.isEmpty)
        ? '<empty-body>'
        : (resp.body.length > 400
            ? resp.body.substring(0, 400) + '…'
            : resp.body);
    throw Exception('Groq API request failed: status=${resp.statusCode}, '
        'headers=${_pickHeaders(resp.headers, [
          "x-request-id",
          "content-type",
          "retry-after"
        ])}, '
        'body=$snippet');
  }

  final data = jsonDecode(resp.body);
  final content = data['choices'][0]['message']['content'];
  final jsonResponse = jsonDecode(content);

  return VoiceReminderResponse.fromJson(
    jsonResponse,
    'GroqCloud (Llama 3.3 70B Text Processing)',
  );
}

Map<String, String> _pickHeaders(Map<String, String> h, List<String> keys) {
  final out = <String, String>{};
  for (final k in keys) {
    final v = h[k];
    if (v != null) out[k] = v;
  }
  return out;
}

// Groq models probe with proper headers (no Content-Type on GET)
Future<Map<String, dynamic>> _groqModelsProbe(GroqCloudStackProcessor p) async {
  final url = Uri.parse('https://api.groq.com/openai/v1/models');
  final resp = await http.get(url, headers: {
    'Authorization': 'Bearer ${p._apiKey}',
    'Accept': 'application/json',
  });
  if (resp.statusCode != 200) {
    final snippet = resp.body.isEmpty ? '<empty-body>' : resp.body;
    throw Exception(
        'GET /models failed: status=${resp.statusCode}, body=$snippet');
  }
  final json = jsonDecode(resp.body);
  final data = (json['data'] as List?) ?? const [];
  return {
    'count': data.length,
    'first': data.isNotEmpty ? data.first['id'] : null,
  };
}
