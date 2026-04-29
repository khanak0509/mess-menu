import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';
import 'notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const String apiBaseUrl = 'https://mess-menu-v458.onrender.com';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pref = prefs.getString('diet_preference') ?? 'veg';
      final url = Uri.parse('$apiBaseUrl/menu?preference=$pref');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        await prefs.setString('cached_menu_$pref', response.body);

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

  Workmanager().initialize(callbackDispatcher);

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
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E), // Neutral premium slate
          primary: const Color(0xFF1A1A1A),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF1E1E1E),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAFAFA),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure OLED black
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          primary: Colors.white,
          onPrimary: Colors.black,
          surface: const Color(0xFF121212),
          onSurface: const Color(0xFFEEEEEE),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
