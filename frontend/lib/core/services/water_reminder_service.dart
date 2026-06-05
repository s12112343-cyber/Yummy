import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class WaterReminderService {
  WaterReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _baseNotificationId = 7200;
  static const int _maxScheduledReminders = 12;
  static const int _waterStepMl = 250;
  static const int _dayEndHour = 22;
  static const String _channelId = 'water_reminders';
  static const String _channelName = 'Water reminders';
  static const String _channelDescription =
      'Reminders that divide your remaining water goal across the day.';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@drawable/logo_notification',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(settings: settings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> scheduleForToday({
    required DateTime selectedDate,
    required int consumedWaterMl,
    required int dailyWaterGoalMl,
  }) async {
    if (kIsWeb) return;

    await initialize();
    await cancelToday();

    final now = DateTime.now();
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    if (selectedDay != today || dailyWaterGoalMl <= 0) return;

    final remainingWaterMl = dailyWaterGoalMl - consumedWaterMl;
    if (remainingWaterMl <= 0) return;

    final dayEnd = DateTime(now.year, now.month, now.day, _dayEndHour);
    if (!now.isBefore(dayEnd)) return;

    final desiredReminderCount = (remainingWaterMl / _waterStepMl).ceil();
    final reminderCount = math.min(
      desiredReminderCount,
      _maxScheduledReminders,
    );

    if (reminderCount <= 0) return;

    final remainingMinutes = dayEnd.difference(now).inMinutes;
    final intervalMinutes = remainingMinutes ~/ (reminderCount + 1);
    if (intervalMinutes <= 0) return;

    for (var i = 0; i < reminderCount; i++) {
      final reminderTime = now.add(
        Duration(minutes: intervalMinutes * (i + 1)),
      );
      final plannedTotalMl = math.min(
        dailyWaterGoalMl,
        consumedWaterMl + _waterStepMl * (i + 1),
      );
      final reminderAmountMl = math.min(
        _waterStepMl,
        dailyWaterGoalMl - (consumedWaterMl + _waterStepMl * i),
      );

      await _notifications.zonedSchedule(
        id: _baseNotificationId + i,
        title: 'Water time',
        body:
            'Drink about ${_formatAmount(reminderAmountMl)} now to stay on track. Goal by ${_formatTime(reminderTime)}: ${_formatAmount(plannedTotalMl)}.',
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'water-reminder',
      );
    }
  }

  static Future<void> cancelToday() async {
    if (kIsWeb) return;

    for (var i = 0; i < _maxScheduledReminders; i++) {
      await _notifications.cancel(id: _baseNotificationId + i);
    }
  }

  static NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'logo_notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
  }

  static String _formatAmount(int amountMl) {
    if (amountMl >= 1000 && amountMl % 1000 == 0) {
      return '${amountMl ~/ 1000}L';
    }

    if (amountMl >= 1000) {
      return '${(amountMl / 1000).toStringAsFixed(1)}L';
    }

    return '${amountMl}ml';
  }

  static String _formatTime(DateTime time) {
    final t = TimeOfDayLike.fromDateTime(time);
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.isAm ? 'AM' : 'PM'}';
  }
}

class TimeOfDayLike {
  const TimeOfDayLike({required this.hour, required this.minute});

  final int hour;
  final int minute;

  int get hourOfPeriod => hour % 12;
  bool get isAm => hour < 12;

  static TimeOfDayLike fromDateTime(DateTime dateTime) {
    return TimeOfDayLike(hour: dateTime.hour, minute: dateTime.minute);
  }
}
