import 'package:flutter/material.dart';

class UserSettings {
  int dailyGoal; // in mL
  TimeOfDay wakingTime;
  TimeOfDay sleepingTime;
  int hydrationDebt; // carried over from previous days
  DateTime lastResetDate;
  bool isDarkMode;

  // Profile Fields
  int age;
  double height; // in cm
  double weight; // in kg
  String profession;
  String sex; // Male, Female

  // Exercise Fields
  int exerciseFrequency; // times per week
  String exerciseIntensity; // Low, Moderate, High
  List<String> sports;
  String activityLevel; // Derived
  bool activeWeekends;

  // New: Life Cycle
  bool isTrackingCycle;
  List<DateTime> pastPeriods;
  int cycleLength;

  // New: Health & Conditions
  List<String> chronicConditions;
  List<String> temporaryIllnesses;

  // New: Environment & Diet
  double temperature; // Celsius
  double humidity; // %
  String caffeineLevel; // None, Low, Moderate, High
  String alcoholLevel; // None, Low, Moderate, High
  String saltIntake; // Low, Moderate, High
  bool autoWeather;
  List<Map<String, dynamic>>
      weatherTrend; // [{"day": "Mon", "temp": 25, "humidity": 50}]
  List<Map<String, dynamic>>
      weatherHistory; // Same as trend but for past 7 days

  // New: AI Strategy Results
  int? aiDailyGoal;
  String? aiRationale;
  List<Map<String, dynamic>>
      aiSchedule; // [{"time": "08:00", "amount": 500, "note": "..."}]
  List<Map<String, dynamic>>
      weeklyForecast; // [{"day": "Mon", "predictedGoal": 3000, "note": "..."}]

  bool isWeightMetric;
  bool isHeightMetric;
  String customNotes;
  // AI Configuration
  String aiEngine; // NVIDIA, Gemini
  bool enableAlarmSound;
  bool insistentAlarm;

  // Detailed Schedule
  TimeOfDay workStartTime;
  TimeOfDay workEndTime;
  bool isCatchingUp;
  DateTime? lastAiUpdate;
  int selectedStatPeriod; // 0: Day, 1: Month, 2: Year
  int maxSafeDailyLimit;
  List<Map<String, dynamic>> weeklyPlan;
  bool isOnboarded;

  UserSettings({
    this.dailyGoal = 2500,
    this.wakingTime = const TimeOfDay(hour: 7, minute: 0),
    this.sleepingTime = const TimeOfDay(hour: 22, minute: 0),
    this.hydrationDebt = 0,
    required this.lastResetDate,
    this.isDarkMode = true,
    this.age = 30,
    this.height = 65,
    this.weight = 70,
    this.profession = 'Student',
    this.sex = 'Male',
    this.exerciseFrequency = 0,
    this.exerciseIntensity = 'Low',
    this.sports = const [],
    this.activityLevel = 'Sedentary',
    this.activeWeekends = true,
    this.isTrackingCycle = false,
    this.pastPeriods = const [],
    this.cycleLength = 28,
    this.chronicConditions = const [],
    this.temporaryIllnesses = const [],
    this.temperature = 25,
    this.humidity = 50,
    this.caffeineLevel = 'None',
    this.alcoholLevel = 'None',
    this.saltIntake = 'Moderate',
    this.autoWeather = false,
    this.weatherTrend = const [],
    this.weatherHistory = const [],
    this.aiDailyGoal,
    this.aiRationale,
    this.aiSchedule = const [],
    this.weeklyForecast = const [],
    this.aiEngine = 'NVIDIA',
    this.enableAlarmSound = true,
    this.insistentAlarm = false,
    this.isWeightMetric = true,
    this.isHeightMetric = false,
    this.customNotes = '',
    this.workStartTime = const TimeOfDay(hour: 9, minute: 0),
    this.workEndTime = const TimeOfDay(hour: 17, minute: 0),
    this.isCatchingUp = false,
    this.lastAiUpdate,
    this.selectedStatPeriod = 0,
    this.maxSafeDailyLimit = 4000,
    this.weeklyPlan = const [],
    this.isOnboarded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'dailyGoal': dailyGoal,
      'wakingHour': wakingTime.hour,
      'wakingMinute': wakingTime.minute,
      'sleepingHour': sleepingTime.hour,
      'sleepingMinute': sleepingTime.minute,
      'hydrationDebt': hydrationDebt,
      'lastResetDate': lastResetDate.toIso8601String(),
      'isDarkMode': isDarkMode,
      'age': age,
      'height': height,
      'weight': weight,
      'profession': profession,
      'sex': sex,
      'exerciseFrequency': exerciseFrequency,
      'exerciseIntensity': exerciseIntensity,
      'sports': sports,
      'activityLevel': activityLevel,
      'activeWeekends': activeWeekends,
      'isTrackingCycle': isTrackingCycle,
      'pastPeriods': pastPeriods.map((e) => e.toIso8601String()).toList(),
      'cycleLength': cycleLength,
      'chronicConditions': chronicConditions,
      'temporaryIllnesses': temporaryIllnesses,
      'temperature': temperature,
      'humidity': humidity,
      'caffeineLevel': caffeineLevel,
      'alcoholLevel': alcoholLevel,
      'saltIntake': saltIntake,
      'autoWeather': autoWeather,
      'weatherTrend': weatherTrend,
      'weatherHistory': weatherHistory,
      'aiDailyGoal': aiDailyGoal,
      'aiRationale': aiRationale,
      'aiSchedule': aiSchedule,
      'weeklyForecast': weeklyForecast,
      'aiEngine': aiEngine,
      'enableAlarmSound': enableAlarmSound,
      'insistentAlarm': insistentAlarm,
      'isWeightMetric': isWeightMetric,
      'isHeightMetric': isHeightMetric,
      'customNotes': customNotes,
      'workStartHour': workStartTime.hour,
      'workStartMinute': workStartTime.minute,
      'workEndHour': workEndTime.hour,
      'workEndMinute': workEndTime.minute,
      'isCatchingUp': isCatchingUp,
      'lastAiUpdate': lastAiUpdate?.toIso8601String(),
      'selectedStatPeriod': selectedStatPeriod,
      'maxSafeDailyLimit': maxSafeDailyLimit,
      'weeklyPlan': weeklyPlan,
      'isOnboarded': isOnboarded,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      dailyGoal: (map['dailyGoal'] as num?)?.toInt() ?? 2500,
      wakingTime: TimeOfDay(
        hour: (map['wakingHour'] as num?)?.toInt() ?? 7,
        minute: (map['wakingMinute'] as num?)?.toInt() ?? 0,
      ),
      sleepingTime: TimeOfDay(
        hour: (map['sleepingHour'] as num?)?.toInt() ?? 22,
        minute: (map['sleepingMinute'] as num?)?.toInt() ?? 0,
      ),
      hydrationDebt: (map['hydrationDebt'] as num?)?.toInt() ?? 0,
      lastResetDate: map['lastResetDate'] != null
          ? DateTime.parse(map['lastResetDate'])
          : DateTime.now(),
      isDarkMode: map['isDarkMode'] as bool? ?? true,
      age: (map['age'] as num?)?.toInt() ?? 25,
      height: (map['height'] as num?)?.toDouble() ?? 170.0,
      weight: (map['weight'] as num?)?.toDouble() ?? 70.0,
      profession: map['profession'] as String? ?? 'Office Worker',
      sex: map['sex'] as String? ?? 'Male',
      exerciseFrequency: (map['exerciseFrequency'] as num?)?.toInt() ?? 3,
      exerciseIntensity: map['exerciseIntensity'] as String? ?? 'Moderate',
      sports: map['sports'] != null ? List<String>.from(map['sports']) : [],
      activityLevel: map['activityLevel'] as String? ?? 'Moderate',
      activeWeekends: map['activeWeekends'] as bool? ?? true,
      isTrackingCycle: map['isTrackingCycle'] as bool? ?? false,
      pastPeriods: map['pastPeriods'] != null
          ? (map['pastPeriods'] as List)
              .map((e) => DateTime.parse(e.toString()))
              .toList()
          : [],
      cycleLength: (map['cycleLength'] as num?)?.toInt() ?? 28,
      chronicConditions: map['chronicConditions'] != null
          ? List<String>.from(map['chronicConditions'])
          : [],
      temporaryIllnesses: map['temporaryIllnesses'] != null
          ? List<String>.from(map['temporaryIllnesses'])
          : [],
      temperature: (map['temperature'] as num?)?.toDouble() ?? 25.0,
      humidity: (map['humidity'] as num?)?.toDouble() ?? 50.0,
      caffeineLevel: map['caffeineLevel'] as String? ?? 'None',
      alcoholLevel: map['alcoholLevel'] as String? ?? 'None',
      saltIntake: map['saltIntake'] as String? ?? 'Moderate',
      autoWeather: map['autoWeather'] as bool? ?? false,
      weatherTrend: map['weatherTrend'] != null
          ? (map['weatherTrend'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      weatherHistory: map['weatherHistory'] != null
          ? (map['weatherHistory'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      aiDailyGoal: (map['aiDailyGoal'] as num?)?.toInt(),
      aiRationale: map['aiRationale'] as String?,
      aiSchedule: map['aiSchedule'] != null
          ? (map['aiSchedule'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      weeklyForecast: map['weeklyForecast'] != null
          ? (map['weeklyForecast'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      aiEngine: map['aiEngine'] as String? ?? 'NVIDIA',
      enableAlarmSound: map['enableAlarmSound'] as bool? ?? true,
      insistentAlarm: map['insistentAlarm'] as bool? ?? false,
      isWeightMetric: map['isWeightMetric'] as bool? ?? true,
      isHeightMetric: map['isHeightMetric'] as bool? ?? false,
      customNotes: map['customNotes'] as String? ?? '',
      workStartTime: TimeOfDay(
        hour: (map['workStartHour'] as num?)?.toInt() ?? 9,
        minute: (map['workStartMinute'] as num?)?.toInt() ?? 0,
      ),
      workEndTime: TimeOfDay(
        hour: (map['workEndHour'] as num?)?.toInt() ?? 17,
        minute: (map['workEndMinute'] as num?)?.toInt() ?? 0,
      ),
      isCatchingUp: map['isCatchingUp'] as bool? ?? false,
      lastAiUpdate: map['lastAiUpdate'] != null
          ? DateTime.parse(map['lastAiUpdate'])
          : null,
      selectedStatPeriod: (map['selectedStatPeriod'] as num?)?.toInt() ?? 0,
      maxSafeDailyLimit: (map['maxSafeDailyLimit'] as num?)?.toInt() ?? 4000,
      weeklyPlan: map['weeklyPlan'] != null
          ? (map['weeklyPlan'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      isOnboarded: map['isOnboarded'] as bool? ?? false,
    );
  }
}
