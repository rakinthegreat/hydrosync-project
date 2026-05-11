import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/water_intake.dart';
import '../models/user_settings.dart';

class StorageService {
  static const String _intakesKey = 'water_intakes';
  static const String _settingsKey = 'user_settings';
  static const String _lastAiResponseKey = 'last_ai_response';
  static const String _lastIntakeBackupKey = 'last_intake_backup_date';

  Future<void> saveIntakes(List<WaterIntake> intakes) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(intakes.map((i) => i.toMap()).toList());
    await prefs.setString(_intakesKey, encoded);
  }

  Future<List<WaterIntake>> getIntakes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_intakesKey);
    if (encoded == null) return [];
    final List<dynamic> decoded = json.decode(encoded);
    return decoded.map((i) => WaterIntake.fromMap(i)).toList();
  }

  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toMap()));
  }

  Future<void> saveLastAiResponse(String response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAiResponseKey, response);
  }

  Future<String?> getLastAiResponse() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastAiResponseKey);
  }

  Future<UserSettings?> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_settingsKey);
    if (encoded == null) return null;
    return UserSettings.fromMap(json.decode(encoded));
  }

  Future<String?> getLastIntakeBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastIntakeBackupKey);
  }

  Future<void> setLastIntakeBackupDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastIntakeBackupKey, date);
  }

  static const String _lastNotificationTimeKey = 'last_notification_time';

  Future<void> saveLastNotificationTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastNotificationTimeKey, time.toIso8601String());
  }

  Future<DateTime?> getLastNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_lastNotificationTimeKey);
    if (encoded == null) return null;
    return DateTime.parse(encoded);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
