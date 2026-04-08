import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';
import 'notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final url = Uri.parse('http://127.0.0.1:8000/menu');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_menu', response.body);

        // Schedule new notifications after data update
        await NotificationService().init();
        await NotificationService().scheduleDailyMealReminders();
        return Future.value(true);
      }
    } catch (e) {
      debugPrint("Background task failed: $e");
    }
    return Future.value(false);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  tz.initializeTimeZones();
  
  await NotificationService().init();
  await NotificationService().requestPermissions();
  await NotificationService().scheduleDailyMealReminders();

  Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: false,
  );
  
  Workmanager().registerPeriodicTask(
    "1",
    "fetchMenuDaily",
    frequency: const Duration(hours: 24),
  );

  runApp(const MessMenuApp());
}

class MessMenuApp extends StatelessWidget {
  const MessMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mess Menu',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111318),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

