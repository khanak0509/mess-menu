import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
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
    final androidImpl = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
    
    final IOSFlutterLocalNotificationsPlugin? iosImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleDailyMealReminders() async {
    // Clear old schedules
    await flutterLocalNotificationsPlugin.cancelAll();
    
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString('cached_menu');
    if (cachedString == null) return;

    final Map<String, dynamic> fullMenu = json.decode(cachedString);
    
    // Schedule for the next 7 days based on current cache
    for (int i = 0; i < 7; i++) {
        final targetDate = DateTime.now().add(Duration(days: i));
        final dayName = _getDayName(targetDate.weekday);
        
        final dayMenu = fullMenu[dayName] ?? fullMenu[dayName.toLowerCase()];
        if (dayMenu == null) continue;

        // Ensure keys handle uppercase/lowercase backend responses gracefully
        final Map<String, dynamic> cMenu = {};
        dayMenu.forEach((k, v) => cMenu[k.toString().toLowerCase()] = v);

        // Breakfast (7:30 AM) -> 15 min earlier (7:15 AM)
        if (cMenu.containsKey('breakfast')) {
           final main = cMenu['breakfast']['Main'] ?? "Check the app for details!";
           _scheduleNotification(targetDate, 7, 15, 'Breakfast Time! 🥞', 'Main item: $main');
        }
        // Lunch (12:30 PM) -> 15 min earlier (12:15 PM)
        if (cMenu.containsKey('lunch')) {
           final main = cMenu['lunch']['Main'] ?? "Check the app for details!";
           _scheduleNotification(targetDate, 12, 15, 'Lunch Time! 🍛', 'Main item: $main');
        }
        // Snacks (5:00 PM) -> 15 min earlier (4:45 PM)
        if (cMenu.containsKey('snacks')) {
           final main = cMenu['snacks']['Main'] ?? "Check the app for details!";
           _scheduleNotification(targetDate, 16, 45, 'Snack Time! ☕', 'Main item: $main');
        }
        // Dinner (10:30 PM) -> 15 min earlier (10:15 PM)
        if (cMenu.containsKey('dinner')) {
           final main = cMenu['dinner']['Main'] ?? "Check the app for details!";
           _scheduleNotification(targetDate, 22, 15, 'Dinner Time! 🍽️', 'Main item: $main');
        }
    }
  }

  Future<void> _scheduleNotification(DateTime day, int hour, int minute, String title, String body) async {
    final tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local, day.year, day.month, day.day, hour, minute,
    );

    // Don't schedule in the past
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    // Use a unique ID based on timestamp 
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
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
}