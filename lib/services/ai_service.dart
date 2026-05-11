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

    // --- PHASE 1: PRIMARY ENGINE ATTEMPTS ---
    // We try the primary engine multiple times, especially for 503s.
    int primaryAttempts = 0;
    const int maxPrimaryAttempts = 4;

    while (primaryAttempts < maxPrimaryAttempts) {
      primaryAttempts++;
      
      if (settings.aiEngine == 'Gemini') {
        result = await _generateWithGemini(settings);
      } else {
        result = await _generateWithNvidia(settings);
      }

      if (_isValidPlan(result)) {
        return _finalizePlan(result, startTime);
      }

      // If we got here, it failed (either null/503 or bad format)
      if (primaryAttempts < maxPrimaryAttempts) {
        // Progressive backoff: 5s, 10s, 30s
        int delaySecs = (primaryAttempts == 1) ? 5 : (primaryAttempts == 2) ? 10 : 30;
        print('[AI-RETRY] Primary engine failed/busy. Waiting ${delaySecs}s before attempt ${primaryAttempts + 1}/$maxPrimaryAttempts...');
        await Future.delayed(Duration(seconds: delaySecs));
      }
    }

    // --- PHASE 2: FALLBACK TO KIMI ---
    print('[AI-FALLBACK] Primary engines exhausted. Engaging Kimi safety net (moonshotai/kimi-k2-instruct-0905)...');
    result = await _generateWithKimiFallback(settings);

    if (_isValidPlan(result)) {
      print('[AI-FALLBACK] Success via Kimi Safety Net!');
      return _finalizePlan(result, startTime);
    }

    // --- PHASE 3: FATAL FAILURE ---
    final duration = DateTime.now().difference(startTime);
    print('[AI TELEMETRY] Critical Failure after ${duration.inMilliseconds}ms');
    print('=============================================\n');
    return null;
  }

  bool _isValidPlan(Map<String, dynamic>? result) {
    if (result == null) return false;
    try {
      if (!result.containsKey('weeklyPlan')) return false;
      final plan = result['weeklyPlan'];
      if (plan is! List || plan.isEmpty) return false;
      
      final firstDay = plan.first;
      if (firstDay is! Map || !firstDay.containsKey('dailyGoal') || !firstDay.containsKey('schedule')) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic>? _finalizePlan(Map<String, dynamic>? result, DateTime startTime) {
    final duration = DateTime.now().difference(startTime);
    final weeklyPlan = result!['weeklyPlan'] as List;
    final firstDay = weeklyPlan.first;
    
    print('[AI TELEMETRY] Success! Latency: ${duration.inMilliseconds}ms');
    print('[AI TELEMETRY] Target Goal: ${firstDay["dailyGoal"]} mL');
    print('[AI PLAN OVERVIEW]');
    for (var day in weeklyPlan) {
      final schedule = day['schedule'] as List;
      print('  • ${day['date']}: ${day['dailyGoal']}mL (${schedule.length} reminders)');
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
      ).timeout(const Duration(seconds: 45));

      lastRawResponse = response.body;
      await _storage.saveLastAiResponse(lastRawResponse!);

      return _parseResponse(response);
    } catch (e) {
      print('[NVIDIA] Service Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _generateWithKimiFallback(
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
          'model': 'moonshotai/kimi-k2-instruct-0905',
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.3,
          'max_tokens': 4096,
        }),
      ).timeout(const Duration(seconds: 45));

      lastRawResponse = response.body;
      await _storage.saveLastAiResponse(lastRawResponse!);

      return _parseResponse(response);
    } catch (e) {
      print('[KIMI FALLBACK] Critical Error: $e');
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
        try {
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
          ).timeout(const Duration(seconds: 45));

          lastResponse = response;

          if (response.statusCode == 200) {
            lastRawResponse = response.body;
            await _storage.saveLastAiResponse(lastRawResponse!);
            return _parseGeminiResponse(response);
          } else if (response.statusCode == 429) {
            print('[AI SERVICE] Gemini Key ${i + 1} exhausted. Trying next key...');
            continue;
          } else if (response.statusCode == 503) {
            print('[AI SERVICE] Gemini 503 error (Service Unavailable).');
            return null; // Return null to trigger retry in generateHydrationPlan
          } else {
            print('[AI SERVICE] Gemini API Error (${response.statusCode}): ${response.body}');
            continue; 
          }
        } catch (e) {
          print('[AI SERVICE] Gemini Request Exception: $e');
          continue;
        }
      }

      if (lastResponse != null) {
        lastRawResponse = lastResponse.body;
        await _storage.saveLastAiResponse(lastRawResponse!);
      }
      return null;
    } catch (e) {
      print('Gemini Service Fatal Exception: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseGeminiResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
        print('Gemini API Error: No candidates returned');
        return null;
      }

      final candidate = data['candidates'][0];
      if (candidate['content'] == null ||
          candidate['content']['parts'] == null) {
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
    } catch (e) {
      print('[AI PARSE] Gemini Response Error (Likely truncated): $e');
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
    try {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['choices'] == null || (data['choices'] as List).isEmpty) {
          print('NVIDIA/Kimi API Error: No choices returned');
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
    } catch (e) {
      print('[AI PARSE] Response Error (Likely truncated): $e');
      return null;
    }
  }
}
