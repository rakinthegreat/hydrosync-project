import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/user_settings.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../screens/hydration_alarm_screen.dart';
import '../main.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
       appName: 'HydroSync',
      appUserModelId: 'rakinthegreat.hydrosync',
      guid: 'ea8c7757-0130-4965-832c-7f6a911e3c23',
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      windows: initializationSettingsWindows,
      linux: null,
      macOS: null,
      iOS: null,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationAction(details);
      },
    );

    // Handle App Launch from Notification (Cold Start)
    final NotificationAppLaunchDetails? launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      if (launchDetails?.notificationResponse != null) {
        // Delay slightly to ensure Navigator is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationAction(launchDetails!.notificationResponse!);
        });
      }
    }
  }

  void _handleNotificationAction(NotificationResponse details) {
    if (details.payload != null) {
      try {
        final data = jsonDecode(details.payload!);
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => HydrationAlarmScreen(
              id: details.id,
              amount: data['amount'],
              note: data['note'] ?? "Time to hydrate!",
              scheduledAt: data['scheduledAt'] != null 
                ? DateTime.parse(data['scheduledAt']) 
                : DateTime.now(),
            ),
          ),
        );
      } catch (e) {
        print('Error handling notification payload: $e');
      }
    }
  }

  Future<void> scheduleWeeklyPlan(
      List<Map<String, dynamic>> weeklyPlan, UserSettings settings) async {
    await cancelAll(); // Clear old schedule

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ai_hydration_alarm_channel',
      'Hydration Alarms',
      channelDescription: 'High-priority full-screen hydration reminders',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      showWhen: true,
      playSound: settings.enableAlarmSound,
      // In version 21.0.0+, 'insistent' is set via additionalFlags
      // FLAG_INSISTENT = 4
      additionalFlags: settings.insistentAlarm 
          ? Int32List.fromList([4]) 
          : null,
    );

    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
    );

    int id = 1;
    final now = DateTime.now();

    for (var dayPlan in weeklyPlan) {
      try {
        final dateStr = dayPlan['date'] as String; // YYYY-MM-DD
        final dayDate = DateTime.parse(dateStr);
        final schedule = dayPlan['schedule'] as List;

        for (var item in schedule) {
          final timeParts = (item['time'] as String).split(':');
          if (timeParts.length == 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);

            final targetDateTime = DateTime(
                dayDate.year, dayDate.month, dayDate.day, hour, minute);

            // Skip if the time has already passed
            if (targetDateTime.isBefore(now)) continue;

            final payload = jsonEncode({
              'amount': item['amount'],
              'note': item['note'] ?? "Your body needs fuel. Hydrate now.",
              'scheduledAt': targetDateTime.toIso8601String(),
            });

            await _notificationsPlugin.zonedSchedule(
              id: id++,
              title: 'HydroSync Critical Alert',
              body: "Drink ${item['amount']}mL now to maintain equilibrium.",
              scheduledDate: tz.TZDateTime.from(targetDateTime, tz.local),
              notificationDetails: platformDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: payload,
            );
          }
        }
      } catch (e) {
        print('Error scheduling weekly notification: $e');
      }
    }
    print('[NOTIFICATIONS] Completed scheduling for the week. Total: ${id - 1}');
  }

  Future<void> testNotification(UserSettings settings) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ai_hydration_alarm_channel',
      'Hydration Alarms',
      channelDescription: 'High-priority full-screen hydration reminders',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      showWhen: true,
      playSound: settings.enableAlarmSound,
      additionalFlags: settings.insistentAlarm ? Int32List.fromList([4]) : null,
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
    final payload = jsonEncode({
      'amount': 250,
      'note': "TEST: This is an immersive full-screen reminder test.",
      'scheduledAt': scheduledTime.toIso8601String(),
    });

    await _notificationsPlugin.zonedSchedule(
      id: 999,
      title: 'HydroSync TEST Alert',
      body: "Testing full-screen immersive notification...",
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    print('[NOTIFICATIONS] Test notification scheduled for 10s from now.');
  }

  Future<void> snooze(int amount, String note, UserSettings settings) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ai_hydration_alarm_channel',
      'Hydration Alarms',
      channelDescription: 'High-priority full-screen hydration reminders',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      showWhen: true,
      playSound: settings.enableAlarmSound,
      additionalFlags: settings.insistentAlarm ? Int32List.fromList([4]) : null,
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));

    final payload = jsonEncode({
      'amount': amount,
      'note': note,
      'scheduledAt': scheduledTime.toIso8601String(),
    });

    await _notificationsPlugin.zonedSchedule(
      id: 888, // Dedicated snooze ID
      title: 'HydroSync Follow-up',
      body: "Gentle reminder: You asked to be reminded to drink ${amount}mL.",
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    print('[NOTIFICATIONS] Snoozed for 10 minutes.');
  }

  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
    Map<String, dynamic> payloadData,
    UserSettings settings,
  ) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ai_hydration_alarm_channel',
      'Hydration Alarms',
      channelDescription: 'High-priority full-screen hydration reminders',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      showWhen: true,
      playSound: settings.enableAlarmSound,
      additionalFlags: settings.insistentAlarm ? Int32List.fromList([4]) : null,
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({
        ...payloadData,
        'scheduledAt': scheduledTime.toIso8601String(),
      }),
    );
    print('[NOTIFICATIONS] Custom notification scheduled for $scheduledTime');
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
    print('[NOTIFICATIONS] Cancelled notification with ID: $id');
  }

  Future<void> deductFromNextNotification(int loggedAmount, {Duration? maxWindow, required UserSettings settings}) async {
    final List<PendingNotificationRequest> pending =
        await _notificationsPlugin.pendingNotificationRequests();
    if (pending.isEmpty) return;

    PendingNotificationRequest? earliest;
    DateTime? earliestTime;
    Map<String, dynamic>? earliestData;

    for (var request in pending) {
      if (request.payload != null) {
        try {
          final data = jsonDecode(request.payload!);
          if (data['scheduledAt'] != null) {
            final time = DateTime.parse(data['scheduledAt']);
            if (earliestTime == null || time.isBefore(earliestTime)) {
              earliestTime = time;
              earliest = request;
              earliestData = data;
            }
          }
        } catch (_) {}
      }
    }

    if (earliest != null && earliestTime != null && earliestData != null) {
      // Only process if it's within the allowed window
      if (maxWindow != null && earliestTime.isAfter(DateTime.now().add(maxWindow))) {
        return;
      }

      final int originalAmount = earliestData['amount'] ?? 0;
      final int remainingAmount = originalAmount - loggedAmount;

      if (remainingAmount <= 50) {
        // Amount is trivial or fully satisfied, cancel it
        await _notificationsPlugin.cancel(id: earliest.id);
        print('[NOTIFICATIONS] Activity satisfied: Cancelled reminder (ID: ${earliest.id}) for ${originalAmount}mL');
      } else {
        // Significant amount remains, reschedule with the new amount
        await _notificationsPlugin.cancel(id: earliest.id);
        
        final updatedPayload = {
          ...earliestData,
          'amount': remainingAmount,
          'note': "Remaining balance: ${remainingAmount}mL from your earlier target.",
        };

        await scheduleNotification(
          earliest.id,
          'HydroSync Adjusted Alert',
          "Still need ${remainingAmount}mL to stay on track.",
          earliestTime,
          updatedPayload,
          settings,
        );
        print('[NOTIFICATIONS] Partial intake: Adjusted next reminder (ID: ${earliest.id}) from ${originalAmount}mL to ${remainingAmount}mL');
      }
    }
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
