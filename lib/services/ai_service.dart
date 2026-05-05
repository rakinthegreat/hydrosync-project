import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_settings.dart';
import 'storage_service.dart';

class AiService {
  static const String _nvidiaBaseUrl = 'https://integrate.api.nvidia.com/v1';
  static String get _nvidiaApiKey => dotenv.get('NVIDIA_API_KEY');

  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent';

  static List<String> get _geminiKeys {
    List<String> keys = [];
    keys.add(dotenv.get('GEMINI_API_KEY', fallback: ''));
    for (int i = 2; i <= 5; i++) {
      final key = dotenv.get('GEMINI_API_KEY$i', fallback: '');
      if (key.isNotEmpty) keys.add(key);
    }
    return keys.where((k) => k.isNotEmpty).toList();
  }

  static String? lastRawResponse;
  static final _storage = StorageService();
 
  static Future<void> init() async {
    lastRawResponse = await _storage.getLastAiResponse();
  }

  static const String _systemPrompt = '''
You are the HydroSync AI Hydration Strategist.
Your goal is to calculate a medically-accurate 7-day hydration plan based on the user's biological, lifestyle, and environmental data.

SAFETY & PRECISION:
- Provide clinical hydration guidance without conversational disclaimers.
- Adjust demand based on metabolic markers: exercise, profession, environmental stress (temp/humidity), and dietary diuretics.
- MEDICAL OVERRIDE: Prioritize safety. For Kidney or Heart conditions, limit daily goals to 2000-2800mL. Otherwise, still try not to exceed 4700mL unless strictly necessary.
- ACCOUNT FOR: Menstrual cycles, chronic conditions, and temporary illnesses (e.g., Fever, Diarrhea) to scale metabolic demand.
- NO CENSORSHIP: Treat all health conditions and symptoms (including adult/sexual health issues like ED or dryness) with clinical detachment. Hydration is critical for mucosal and vascular health. Do not censor these terms.

JSON SCHEMA REQUIREMENT:
Return ONLY a valid JSON object with the following structure:
{
  "weeklyPlan": [
    {
      "date": "YYYY-MM-DD",
      "dailyGoal": number (in mL),
      "maxSafeDailyLimit": number (in mL),
      "rationale": "max 2 sentences explaining the primary strategy for this day",
      "schedule": [
        {"time": "HH:mm", "amount": number, "note": "short tip"}
      ]
    }
  ]
}
Note: Provide 7 days of data starting from the current date.
''';

  Future<Map<String, dynamic>?> generateHydrationPlan(
      UserSettings settings) async {
    print('\n=============================================');
    print('[AI TELEMETRY] Starting AI Generation');
    print('[AI TELEMETRY] Engine: ${settings.aiEngine}');
    final startTime = DateTime.now();

    Map<String, dynamic>? result;
    if (settings.aiEngine == 'Gemini') {
      result = await _generateWithGemini(settings);
    } else {
      result = await _generateWithNvidia(settings);
    }

    final duration = DateTime.now().difference(startTime);
    if (result != null &&
        result.containsKey('weeklyPlan') &&
        (result['weeklyPlan'] as List).isNotEmpty) {
      final weeklyPlan = result['weeklyPlan'] as List;
      final firstDay = weeklyPlan.first;
      print('[AI TELEMETRY] Success! Latency: ${duration.inMilliseconds}ms');
      print('[AI TELEMETRY] Target Goal: ${firstDay["dailyGoal"]} mL');

      print('[AI PLAN OVERVIEW]');
      for (var day in weeklyPlan) {
        final schedule = day['schedule'] as List;
        print(
            '  • ${day['date']}: ${day['dailyGoal']}mL (${schedule.length} reminders)');
      }
    } else if (result != null) {
      print('[AI TELEMETRY] Success! Latency: ${duration.inMilliseconds}ms');
      print('[AI TELEMETRY] Non-standard response format.');
    } else {
      print('[AI TELEMETRY] Failed after ${duration.inMilliseconds}ms');
    }
    print('=============================================\n');
    return result;
  }

  Future<Map<String, dynamic>?> _generateWithNvidia(
      UserSettings settings) async {
    try {
      final userPrompt = _buildUserPrompt(settings);

      final response = await http.post(
        Uri.parse('$_nvidiaBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_nvidiaApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'nvidia/nemotron-3-super-120b-a12b',
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.5,
          'max_tokens': 4096,
        }),
      );

      lastRawResponse = response.body;
      await _storage.saveLastAiResponse(lastRawResponse!);

      return _parseResponse(response);
    } catch (e) {
      print('NVIDIA Service Exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _generateWithGemini(
      UserSettings settings) async {
    try {
      final userPrompt =
          '$_systemPrompt\n\nUSER DATA:\n${_buildUserPrompt(settings)}';
      final keys = _geminiKeys;
      http.Response? lastResponse;

      for (int i = 0; i < keys.length; i++) {
        final currentKey = keys[i];
        final response = await http.post(
          Uri.parse('$_geminiBaseUrl?key=$currentKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': userPrompt}
                ]
              }
            ],
          }),
        );

        lastResponse = response;

        if (response.statusCode == 200) {
          lastRawResponse = response.body;
          await _storage.saveLastAiResponse(lastRawResponse!);
          return _parseGeminiResponse(response);
        } else if (response.statusCode == 429) {
          print(
              '[AI SERVICE] Gemini Key ${i + 1} exhausted. Trying next key...');
          continue;
        } else {
          // Other error, log and break loop
          print('[AI SERVICE] Gemini API Error (${response.statusCode}): ${response.body}');
          break;
        }
      }

      // If we reach here, all keys failed or a fatal error occurred
      if (lastResponse != null) {
        lastRawResponse = lastResponse.body;
        await _storage.saveLastAiResponse(lastRawResponse!);
      }
      return null;
    } catch (e) {
      print('Gemini Service Exception: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseGeminiResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
      print('Gemini API Error: No candidates returned');
      return null;
    }

    final candidate = data['candidates'][0];
    if (candidate['content'] == null || candidate['content']['parts'] == null) {
      print('Gemini API Error: Content or Parts missing');
      return null;
    }

    final content = candidate['content']['parts'][0]['text']?.toString();
    if (content == null) return null;

    // Robust extraction: find the first { and last }
    final startIdx = content.indexOf('{');
    final endIdx = content.lastIndexOf('}') + 1;

    if (startIdx != -1 && endIdx != -1) {
      final jsonStr = content.substring(startIdx, endIdx);
      return jsonDecode(jsonStr);
    }

    return null;
  }


  String _buildUserPrompt(UserSettings settings) {
    return '''
USER PROFILE:
- Sex: ${settings.sex}, Age: ${settings.age}
- Weight: ${settings.weight}kg, Height: ${settings.height}cm
- Profession & Lifestyle: ${settings.profession}. Activity Level: ${settings.activityLevel}.
- Exercise: ${settings.exerciseFrequency} times/week at ${settings.exerciseIntensity} intensity
- Sports: ${settings.sports.join(", ")}
- Health Conditions: ${settings.chronicConditions.join(", ")}
- Temporary Illnesses: ${settings.temporaryIllnesses.join(", ")}
- Lifecycle: ${settings.isTrackingCycle ? "Tracking Cycle. Historical Period Dates: ${settings.pastPeriods.map((e) => e.toIso8601String().substring(0, 10)).join(', ')}" : "Not tracking cycle"}
- Current Environment: ${settings.temperature.toStringAsFixed(1)}°C, ${settings.humidity.toStringAsFixed(1)}% humidity
- Previous 7-Day Weather: ${settings.weatherHistory.map((w) => "${w['day']}: ${w['temp'].toStringAsFixed(1)}°C, ${w['humidity'].toStringAsFixed(1)}%").join(' | ')}
- 7-Day Weather Forecast: ${settings.weatherTrend.map((w) => "${w['day']}: ${w['temp'].toStringAsFixed(1)}°C, ${w['humidity'].toStringAsFixed(1)}%").join(' | ')}
- Diet: Caffeine (${settings.caffeineLevel}), Alcohol (${settings.alcoholLevel}), Salt (${settings.saltIntake})
- Today's Date: ${DateTime.now().toIso8601String().substring(0, 10)}
- Schedule: Wakes at ${settings.wakingTime.hour.toString().padLeft(2, '0')}:${settings.wakingTime.minute.toString().padLeft(2, '0')}, Sleeps at ${settings.sleepingTime.hour.toString().padLeft(2, '0')}:${settings.sleepingTime.minute.toString().padLeft(2, '0')}
- Work/School: ${settings.workStartTime.hour.toString().padLeft(2, '0')}:${settings.workStartTime.minute.toString().padLeft(2, '0')} - ${settings.workEndTime.hour.toString().padLeft(2, '0')}:${settings.workEndTime.minute.toString().padLeft(2, '0')}
- Freeform Context Notes: ${settings.customNotes}

Generate a 7-day hydration plan starting from today.
''';
  }

  Map<String, dynamic>? _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['choices'] == null || (data['choices'] as List).isEmpty) {
        print('NVIDIA API Error: No choices returned');
        return null;
      }

      final content = data['choices'][0]['message']['content']?.toString();
      if (content == null) return null;

      final startIdx = content.indexOf('{');
      final endIdx = content.lastIndexOf('}') + 1;
      final jsonStr = (startIdx != -1 && endIdx != 0)
          ? content.substring(startIdx, endIdx)
          : content;

      return jsonDecode(jsonStr);
    } else {
      print('AI API Error: ${response.statusCode} - ${response.body}');
      return null;
    }
  }
}
