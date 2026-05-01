import 'dart:convert';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _timezoneConfigured = false;

  Future<void> _configureLocalTimezone() async {
    if (_timezoneConfigured) return;
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _timezoneConfigured = true;
  }

  Future<void> init() async {
    await _configureLocalTimezone();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    );
  }

  Future<void> requestPermissions() async {
    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> scheduleDailyMealReminders() async {
    await _configureLocalTimezone();
    await flutterLocalNotificationsPlugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final pref = prefs.getString('diet_preference') ?? 'veg';
    final cachedString = prefs.getString('cached_menu_$pref');
    if (cachedString == null) return;

    final Map<String, dynamic> payload = json.decode(cachedString);
    final menuNode = payload['menu'];
    final configNode = payload['config'];
    final Map<String, dynamic> fullMenu = menuNode is Map<String, dynamic>
        ? menuNode
        : payload;
    final Map<String, dynamic> timings =
        (configNode is Map<String, dynamic> &&
            configNode['timings'] is Map<String, dynamic>)
        ? configNode['timings']
        : <String, dynamic>{
            'weekday_breakfast': '07:30-10:00',
            'weekend_breakfast': '08:00-10:30',
            'lunch': '12:15-14:45',
            'snacks': '17:30-18:30',
            'dinner': '19:30-22:30',
          };

    for (int i = 0; i < 7; i++) {
      final targetDate = DateTime.now().add(Duration(days: i));
      final dayName = _getDayName(targetDate.weekday);
      final isWeekend =
          targetDate.weekday == DateTime.saturday ||
          targetDate.weekday == DateTime.sunday;

      final dayMenu = fullMenu[dayName] ?? fullMenu[dayName.toLowerCase()];
      if (dayMenu == null) continue;

      final Map<String, dynamic> cMenu = {};
      dayMenu.forEach((k, v) => cMenu[k.toString().toLowerCase()] = v);

      if (cMenu.containsKey('breakfast')) {
        final main = cMenu['breakfast']['Main'] ?? "Check the app for details!";
        final time = _getReminderTime(
          (timings[isWeekend ? 'weekend_breakfast' : 'weekday_breakfast'] ?? '')
              .toString(),
        );
        if (time != null) {
          _scheduleNotification(
            targetDate,
            time.$1,
            time.$2,
            'Breakfast Time! 🥞',
            'Main item: $main',
          );
        }
      }
      if (cMenu.containsKey('lunch')) {
        final main = cMenu['lunch']['Main'] ?? "Check the app for details!";
        final time = _getReminderTime((timings['lunch'] ?? '').toString());
        if (time != null) {
          _scheduleNotification(
            targetDate,
            time.$1,
            time.$2,
            'Lunch Time! 🍛',
            'Main item: $main',
          );
        }
      }
      if (cMenu.containsKey('snacks')) {
        final main = cMenu['snacks']['Main'] ?? "Check the app for details!";
        final time = _getReminderTime((timings['snacks'] ?? '').toString());
        if (time != null) {
          _scheduleNotification(
            targetDate,
            time.$1,
            time.$2,
            'Snack Time! ☕',
            'Main item: $main',
          );
        }
      }
      if (cMenu.containsKey('dinner')) {
        final main = cMenu['dinner']['Main'] ?? "Check the app for details!";
        final time = _getReminderTime((timings['dinner'] ?? '').toString());
        if (time != null) {
          _scheduleNotification(
            targetDate,
            time.$1,
            time.$2,
            'Dinner Time! 🍽️',
            'Main item: $main',
          );
        }
      }
    }
  }

  (int, int)? _getReminderTime(String rawRange) {
    if (rawRange.isEmpty || !rawRange.contains('-')) return null;
    final start = rawRange.split('-').first.trim();
    final parts = start.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    final startMinutes = hour * 60 + minute;
    final reminderMinutes = startMinutes - 15;
    if (reminderMinutes < 0) return null;
    return (reminderMinutes ~/ 60, reminderMinutes % 60);
  }

  Future<void> _scheduleNotification(
    DateTime day,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    final tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    final id = scheduledTime.millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminders_channel',
          'Meal Reminders',
          channelDescription: 'Notifications for upcoming meals',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: DefaultStyleInformation(true, true),
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
