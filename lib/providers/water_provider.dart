import 'package:flutter/material.dart';
import 'package:hydrosync/services/weather_service.dart';
import 'dart:io';
import '../models/water_intake.dart';
import '../models/user_settings.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart';
import '../services/sync_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class WaterProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();
  final AiService _ai = AiService();
  final WeatherService _weather = WeatherService();
  final SyncService _sync = SyncService();

  List<WaterIntake> _intakes = [];
  UserSettings? _settings;

  List<WaterIntake> get intakes => _intakes;
  UserSettings? get settings => _settings;
  NotificationService get notificationService => _notifications;
  StorageService get storage => _storage;

  Future<void> applyAiStrategy() async {
    if (_settings == null) return;

    // Auto Weather Sync before AI call if enabled
    if (_settings!.autoWeather) {
      print('[AI ARCHITECT] Auto-syncing weather before generation...');
      final weatherData = await _weather.fetchWeather();
      if (weatherData != null) {
        _settings!.temperature = weatherData['temperature'];
        _settings!.humidity = weatherData['humidity'];
        _settings!.weatherTrend = List<Map<String, dynamic>>.from(weatherData['trend'] ?? []);
        _settings!.weatherHistory = List<Map<String, dynamic>>.from(weatherData['history'] ?? []);
        await _storage.saveSettings(_settings!);
        print('[AI ARCHITECT] Weather synced: ${_settings!.temperature.toStringAsFixed(1)}°C, ${_settings!.humidity.toStringAsFixed(1)}% humidity');
        print('[AI ARCHITECT] 14-day context captured (7 history + 7 forecast).');
      } else {
        print('[AI ARCHITECT] Weather sync failed, using last known values.');
      }
    }
    
    final plan = await _ai.generateHydrationPlan(_settings!);
    if (plan != null) {
      final weeklyPlanRaw = (plan['weeklyPlan'] as List);
      _settings!.weeklyPlan =
          weeklyPlanRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      // Extract today's data (first item) for immediate UI state
      if (_settings!.weeklyPlan.isNotEmpty) {
        final today = _settings!.weeklyPlan.first;
        _settings!.dailyGoal = (today['dailyGoal'] as num).toInt();
        _settings!.maxSafeDailyLimit =
            (today['maxSafeDailyLimit'] as num).toInt();
        _settings!.aiDailyGoal = _settings!.dailyGoal;
        _settings!.aiRationale = today['rationale'];
        _settings!.aiSchedule = (today['schedule'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      _settings!.lastAiUpdate = DateTime.now();
      await _storage.saveSettings(_settings!);
      _autoBackupSettings();

      // Schedule the WHOLE WEEK
      await _notifications.scheduleWeeklyPlan(_settings!.weeklyPlan, _settings!);

      _updateWidget();
      notifyListeners();
      print('[AI REFRESH] 7-day strategy updated successfully.');
    } else {
      print(
          '[AI REFRESH] Strategy refresh failed. Will retry on next app start.');
    }
  }

  int get dailyTotal {
    final now = DateTime.now();
    return _intakes
        .where((i) =>
            i.timestamp.year == now.year &&
            i.timestamp.month == now.month &&
            i.timestamp.day == now.day)
        .fold(0, (sum, i) => sum + i.amount);
  }

  int get adjustedGoal {
    if (_settings == null) return 2500;
    int baseGoal = _settings!.dailyGoal;
    
    if (_settings!.isCatchingUp && _settings!.hydrationDebt > 0) {
      int maxLimit = _settings!.maxSafeDailyLimit;
      int allowedExtra = maxLimit - baseGoal;
      if (allowedExtra < 0) allowedExtra = 0;
      
      int debtToApply = _settings!.hydrationDebt > allowedExtra 
          ? allowedExtra 
          : _settings!.hydrationDebt;
          
      return baseGoal + debtToApply;
    }
    
    return baseGoal;
  }

  int get remainingAwakeHours {
    if (_settings == null) return 16;
    final now = DateTime.now();
    final sleep = DateTime(now.year, now.month, now.day,
        _settings!.sleepingTime.hour, _settings!.sleepingTime.minute);

    if (now.isAfter(sleep)) return 1;

    final diff = sleep.difference(now).inHours;
    return diff > 0 ? diff : 1;
  }

  double get progressPercentage {
    if (adjustedGoal == 0) return 0;
    return (dailyTotal / adjustedGoal).clamp(0.0, 1.0);
  }

  Future<void> init() async {
    _settings = await _storage.getSettings() ?? UserSettings(lastResetDate: DateTime.now());
    _intakes = await _storage.getIntakes();

    // Restore from cloud if signed in and local data is empty (new device)
    if (_sync.isSignedIn) {
      if (_settings == null || _intakes.isEmpty) {
        print('[SYNC] Local data empty — restoring from cloud...');
        final cloud = await _sync.restoreAll();
        if (cloud != null) {
          bool dataRestored = false;
          if (cloud.settings != null && (_settings == null || _settings!.weeklyPlan.isEmpty)) {
            _settings = cloud.settings;
            await _storage.saveSettings(_settings!);
            dataRestored = true;
          }
          if (cloud.intakes != null && _intakes.isEmpty) {
            _intakes = cloud.intakes!;
            await _storage.saveIntakes(_intakes);
          }

          // CRITICAL: If we restored a plan, we MUST schedule it on the new device immediately
          if (dataRestored && _settings!.weeklyPlan.isNotEmpty) {
            print('[SYNC] Restored plan found. Arming local alarms...');
            await _notifications.scheduleWeeklyPlan(_settings!.weeklyPlan, _settings!);
          }
        }
      }
    }

    _settings ??= UserSettings(lastResetDate: DateTime.now());

    // Initialize notifications
    await _notifications.init();

    _checkAndResetDaily();
    _autoRefreshAiIfNeeded(); // Check if strategy needs refresh (5-day window)
    _updateWidget();
    notifyListeners();
  }

  Future<void> _autoRefreshAiIfNeeded() async {
    if (_settings == null) return;
    
    final lastUpdate = _settings!.lastAiUpdate;
    final now = DateTime.now();
    
    // Refresh if never updated, or if it's been 5+ days
    if (lastUpdate == null || now.difference(lastUpdate).inDays >= 5) {
      print('[AI AUTO-REFRESH] Strategy is ${lastUpdate == null ? "missing" : "${now.difference(lastUpdate).inDays} days old"}. Refreshing...');
      await applyAiStrategy();
    } else {
      print('[AI AUTO-REFRESH] Strategy is up to date (Last updated: ${lastUpdate.toIso8601String().substring(0, 10)})');
    }
  }

  void _checkAndResetDaily() {
    final now = DateTime.now();
    final lastReset = _settings!.lastResetDate;

    if (now.year != lastReset.year || now.month != lastReset.month || now.day != lastReset.day) {
      // Find yesterday's base goal from the plan
      final lastResetDateStr = lastReset.toIso8601String().substring(0, 10);
      int yesterdayBaseGoal = _settings!.dailyGoal;
      
      try {
        final yesterdayPlan = _settings!.weeklyPlan.firstWhere(
          (p) => p['date'] == lastResetDateStr,
          orElse: () => {},
        );
        if (yesterdayPlan.containsKey('dailyGoal')) {
          yesterdayBaseGoal = (yesterdayPlan['dailyGoal'] as num).toInt();
        }
      } catch (_) {}

      final yesterdayTotal = _intakes
          .where((i) =>
              i.timestamp.year == lastReset.year &&
              i.timestamp.month == lastReset.month &&
              i.timestamp.day == lastReset.day)
          .fold(0, (sum, i) => sum + i.amount);

      // New Debt = (Yesterday's Base Goal + Current Debt) - Yesterday's Total
      int debt = (yesterdayBaseGoal + _settings!.hydrationDebt) - yesterdayTotal;
      if (debt < 0) debt = 0;

      _settings!.hydrationDebt = debt;
      _settings!.isCatchingUp = false; // Reset catchup status for new day per user request
      _settings!.lastResetDate = now;

      // --- NEW: Daily Plan Sync ---
      // Update today's goals and rationale from the existing 7-day plan
      final todayDateStr = now.toIso8601String().substring(0, 10);
      try {
        final todayPlan = _settings!.weeklyPlan.firstWhere(
          (p) => p['date'] == todayDateStr,
          orElse: () => {},
        );
        if (todayPlan.isNotEmpty) {
          _settings!.dailyGoal = (todayPlan['dailyGoal'] as num).toInt();
          _settings!.maxSafeDailyLimit = (todayPlan['maxSafeDailyLimit'] as num).toInt();
          _settings!.aiDailyGoal = _settings!.dailyGoal;
          _settings!.aiRationale = todayPlan['rationale'];
          _settings!.aiSchedule = (todayPlan['schedule'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          print('[DAILY RESET] Synced today\'s plan: ${_settings!.aiRationale}');
        }
      } catch (e) {
        print('[DAILY RESET] Failed to sync today\'s specific plan: $e');
      }

      _storage.saveSettings(_settings!);
    }
  }

  Future<void> addIntake(int amount) async {
    final intake = WaterIntake(timestamp: DateTime.now(), amount: amount);
    _intakes.add(intake);
    await _storage.saveIntakes(_intakes);

    // Smart Notification Logic: Deduct intake from the next scheduled reminder
    if (_settings != null) {
      await notificationService.deductFromNextNotification(
          amount, 
          maxWindow: const Duration(hours: 2), 
          settings: _settings!);
    }

    _updateWidget();
    _backupIntakes(); // Instant cloud backup
    notifyListeners();
  }

  Future<void> undoLast() async {
    if (_intakes.isNotEmpty) {
      _intakes.removeLast();
      await _storage.saveIntakes(_intakes);
      _updateWidget();
      _backupIntakes(); // Instant cloud backup
      notifyListeners();
    }
  }

  /// Backs up intakes to cloud instantly.
  Future<void> _backupIntakes() async {
    if (!_sync.isSignedIn) return;
    await _sync.backupIntakes(_intakes);
  }

  /// Auto-backup settings whenever they change, silently.
  Future<void> _autoBackupSettings() async {
    if (_sync.isSignedIn && _settings != null) {
      _sync.backupSettings(_settings!); // fire-and-forget
    }
  }

  Future<void> _updateWidget() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await HomeWidget.saveWidgetData<String>('progress', '$dailyTotal / $adjustedGoal mL');
        await HomeWidget.updateWidget(
          name: 'HydroSyncWidgetProvider',
          androidName: 'HydroSyncWidgetProvider',
        );
      }
    } catch (e) {
      print('[HOME_WIDGET] Feature not available on this platform: $e');
    }
  }

  Future<void> updateSettings(UserSettings newSettings,
      {bool refreshAi = true, bool syncToCloud = true}) async {
    _settings = newSettings;
    await _storage.saveSettings(_settings!);
    if (syncToCloud) _autoBackupSettings();
    notifyListeners();
    
    if (refreshAi) {
      // Automatically re-calibrate AI strategy whenever settings change
      print('[AI AUTO-TRIGGER] Settings changed, refreshing strategy...');
      applyAiStrategy();
    }
  }

  Future<void> toggleTheme() async {
    if (_settings != null) {
      _settings!.isDarkMode = !_settings!.isDarkMode;
      await _storage.saveSettings(_settings!);
      _autoBackupSettings();
      notifyListeners();
    }
  }

  Future<void> catchUp() async {



    if (_settings != null && _settings!.hydrationDebt > 0) {
      _settings!.isCatchingUp = true;
      await _storage.saveSettings(_settings!);
      notifyListeners();
    }
  }

  Future<void> calibrateGoal() async {
    if (_settings == null) return;
    
    // Base Calculation: 35mL per kg for Males, 31mL per kg for Females (approx guidelines)
    double multiplier = _settings!.sex == 'Male' ? 35 : 31;
    double calculatedGoal = _settings!.weight * multiplier;
    
    // Age Adjustment (Metabolic variance)
    if (_settings!.age < 18) {
      calculatedGoal += 200; // Growing bodies
    } else if (_settings!.age > 65) {
      calculatedGoal -= 200; // Slower metabolism
    }
    
    // Activity Adjustment (Automated based on Exercise)
    double activityBonus = 0;
    double perSessionBonus = 300; // Moderate default
    if (_settings!.exerciseIntensity == 'Low') perSessionBonus = 150;
    if (_settings!.exerciseIntensity == 'High') perSessionBonus = 600;
    
    // Calculate average daily bonus
    activityBonus = (_settings!.exerciseFrequency * perSessionBonus) / 7;
    calculatedGoal += activityBonus;

    // Derive display Activity Level for metadata
    if (_settings!.exerciseFrequency == 0) _settings!.activityLevel = 'Sedentary';
    else if (_settings!.exerciseFrequency <= 2) _settings!.activityLevel = 'Light';
    else if (_settings!.exerciseFrequency <= 4) _settings!.activityLevel = 'Moderate';
    else if (_settings!.exerciseFrequency <= 6) _settings!.activityLevel = 'Heavy';
    else _settings!.activityLevel = 'Athlete';
    
    // Specific Conditions Adjustment
    double conditionBonus = 0;
    // Check both chronic and temporary conditions
    final allConditions = [..._settings!.chronicConditions, ..._settings!.temporaryIllnesses];
    
    for (var condition in allConditions) {
      if (condition == 'Pregnancy') conditionBonus += 350;
      if (condition == 'Breastfeeding') conditionBonus += 800;
      if (condition == 'Hot Climate') conditionBonus += 600;
      if (condition == 'Illness' || condition == 'Fever') conditionBonus += 500;
      if (condition == 'UTI') conditionBonus += 400;
      if (condition == 'Dehydration') conditionBonus += 1000;
      if (condition == 'Diabetes') conditionBonus += 500;
    }
    calculatedGoal += conditionBonus;
    
    // Round to nearest 50mL for user-friendly numbers
    int finalGoal = (calculatedGoal / 50).round() * 50;
    
    // Ensure a healthy minimum (1500mL)
    if (finalGoal < 1500) finalGoal = 1500;

    _settings!.dailyGoal = finalGoal;
    await _storage.saveSettings(_settings!);
    _autoBackupSettings();
    notifyListeners();
  }

  Future<void> resetToday() async {
    final now = DateTime.now();
    _intakes.removeWhere((i) =>
        i.timestamp.year == now.year &&
        i.timestamp.month == now.month &&
        i.timestamp.day == now.day);
    await _storage.saveIntakes(_intakes);
    _updateWidget();
    notifyListeners();
  }

  Future<void> resetAllHistory() async {
    _intakes.clear();
    await _storage.saveIntakes(_intakes);
    _updateWidget();
    notifyListeners();
  }

  Future<void> resetFullApp() async {
    await _storage.clearAll();
    _intakes.clear();
    _settings = UserSettings(lastResetDate: DateTime.now());
    await _storage.saveSettings(_settings!);
    _updateWidget();
    notifyListeners();
  }
}

