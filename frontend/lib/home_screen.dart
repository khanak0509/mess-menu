import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'meal_card.dart';
import 'qr_pass_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _apiBaseUrl = 'https://mess-menu-v458.onrender.com';
  final List<String> days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late String _selectedDay;
  Map<String, dynamic>? _fullMenu;
  bool _isLoading = true;
  String _errorMessage = '';
  String _dietPreference = 'veg';
  String _specialDinnerDate = '';
  String _specialDinnerVegText = '';
  String _specialDinnerNonVegText = '';
  Map<String, String> _mealTimings = {
    'weekday_breakfast': '07:30-10:00',
    'weekend_breakfast': '08:00-10:30',
    'lunch': '12:15-14:45',
    'snacks': '17:30-18:30',
    'dinner': '19:30-22:30',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _getCurrentDay();
    _bootstrap();
  }

  String _getCurrentDay() {
    return days[DateTime.now().weekday - 1];
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final pref = prefs.getString('diet_preference');
    if (pref == null) {
      final selectedPref = await _askPreferenceOnFirstLaunch();
      _dietPreference = selectedPref;
      await prefs.setString('diet_preference', selectedPref);
    } else {
      _dietPreference = pref;
    }
    await _loadMenu();
  }

  Future<String> _askPreferenceOnFirstLaunch() async {
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;

        return AlertDialog(
          title: Text(
            'Select your menu preference',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: cs.onSurface,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You can change this anytime from the top-right toggle.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop('veg'),
                      child: const Text('Veg'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('nonveg'),
                      child: const Text('Non-Veg'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return selected ?? 'veg';
  }

  Future<void> _loadMenu() async {
    await _fetchMenuFromApi();
  }

  void _applyMenuPayload(Map<String, dynamic> payload) {
    final rawMenu = payload['menu'];
    final menu = (rawMenu is Map<String, dynamic>) ? rawMenu : payload;
    final config = payload['config'];

    if (config is Map<String, dynamic>) {
      final timingsRaw = config['timings'];
      final specialRaw = config['special_dinner'];
      if (timingsRaw is Map<String, dynamic>) {
        setState(() {
          _mealTimings = {
            ..._mealTimings,
            ...timingsRaw.map((k, v) => MapEntry(k, v.toString())),
          };
        });
      }
      if (specialRaw is Map<String, dynamic>) {
        setState(() {
          _specialDinnerDate = (specialRaw['date'] ?? '').toString().trim();
          _specialDinnerVegText = (specialRaw['veg_text'] ?? '')
              .toString()
              .trim();
          _specialDinnerNonVegText = (specialRaw['nonveg_text'] ?? '')
              .toString()
              .trim();
        });
      } else if (config['special_dinner_text'] != null) {
        // Backward compatibility for old config structure.
        setState(() {
          _specialDinnerDate = '';
          _specialDinnerVegText = (config['special_dinner_text'] ?? '')
              .toString()
              .trim();
          _specialDinnerNonVegText = '';
        });
      }
    }

    setState(() {
      _fullMenu = menu;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String pref) async {
    if (_dietPreference == pref) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('diet_preference', pref);
    setState(() {
      _dietPreference = pref;
    });
    await _fetchMenuFromApi();
  }

  Future<void> _fetchMenuFromApi() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$_apiBaseUrl/menu?preference=$_dietPreference');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final payload = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_menu_$_dietPreference', response.body);
        if (payload is Map<String, dynamic>) {
          setState(() {
            _errorMessage = '';
          });
          _applyMenuPayload(payload);
        } else {
          await _loadFromCacheOrFail('Unexpected API response format.');
        }
      } else {
        await _loadFromCacheOrFail('Failed to load latest menu from server.');
      }
    } catch (e) {
      await _loadFromCacheOrFail('Unable to connect. Showing last saved menu.');
    }
  }

  Future<void> _loadFromCacheOrFail(String fallbackMessage) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedMenu = prefs.getString('cached_menu_$_dietPreference');
    if (cachedMenu != null) {
      final decoded = json.decode(cachedMenu);
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _errorMessage = fallbackMessage;
        });
        _applyMenuPayload(decoded);
        return;
      }
    }

    setState(() {
      _errorMessage = 'No cached data available for $_dietPreference menu.';
      _isLoading = false;
    });
  }

  /*
  String _getUpNextMealName(Map<String, dynamic> dayMenu) {
    final now = DateTime.now();
    final currentHour = now.hour + now.minute / 60.0;

    if (currentHour < 10.0) return "Breakfast";
    if (currentHour < 14.5) return "Lunch";
    if (currentHour < 18.0) return "Snacks";
    if (currentHour < 22.5) return "Dinner";
    return "Breakfast (Tomorrow)";
  }

  Widget _buildHeroSection() {
    return const SizedBox.shrink();
  }
  */

  bool _isMealActive(String meal, String selectedDay) {
    if (selectedDay != _getCurrentDay()) return false;
    final now = DateTime.now();
    final currentHour = now.hour + now.minute / 60.0;
    final isWeekend = selectedDay == 'Saturday' || selectedDay == 'Sunday';
    final range = _getRangeForMeal(meal, isWeekend);
    if (range == null) return false;
    final start = _timeToDecimal(range.$1);
    final end = _timeToDecimal(range.$2);
    if (start == null || end == null) return false;
    return currentHour >= start && currentHour < end;
  }

  (String, String)? _getRangeForMeal(String meal, bool isWeekend) {
    final key = (meal == 'breakfast' && isWeekend)
        ? 'weekend_breakfast'
        : (meal == 'breakfast' ? 'weekday_breakfast' : meal);
    final raw = _mealTimings[key];
    if (raw == null || !raw.contains('-')) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    return (parts[0].trim(), parts[1].trim());
  }

  double? _timeToDecimal(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour + minute / 60.0;
  }

  String _formatTimeTo12h(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return value;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = (h % 12 == 0) ? 12 : h % 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h12:$mm $suffix';
  }

  String _getDisplayTimeRange(String meal) {
    final isWeekend = _selectedDay == 'Saturday' || _selectedDay == 'Sunday';
    final range = _getRangeForMeal(meal, isWeekend);
    if (range == null) return '';
    return '${_formatTimeTo12h(range.$1)} - ${_formatTimeTo12h(range.$2)}';
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  String _getSpecialDinnerForSelectedDay() {
    if (_selectedDay != _getCurrentDay()) return '';
    if (_specialDinnerDate.isEmpty) return '';
    if (_specialDinnerDate != _todayIsoDate()) return '';

    final text = _dietPreference == 'nonveg'
        ? _specialDinnerNonVegText
        : _specialDinnerVegText;
    return text.trim();
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final isSelected = days[index] == _selectedDay;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = days[index]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                days[index].substring(0, 3).toUpperCase(),
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withAlpha(20),
                highlightColor: Theme.of(context).colorScheme.surface,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withAlpha(20),
                  highlightColor: Theme.of(context).colorScheme.surface,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMenuForSelectedDay =
        _fullMenu != null && _fullMenu![_selectedDay] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IITJ Menu'),
        centerTitle: false,
        actions: [
          _buildPreferenceToggle(),
          const QRPassButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : hasMenuForSelectedDay
          ? RefreshIndicator(
              onRefresh: _fetchMenuFromApi,
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  _buildDaySelector(),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(28),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withAlpha(90),
                          ),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.orange.shade200
                                : Colors.orange.shade900,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildMealsList(key: ValueKey(_selectedDay)),
                  ),
                ],
              ),
            )
          : Center(
              child: Text(
                _errorMessage.isEmpty
                    ? 'No menu found for this day.'
                    : _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
    );
  }

  Widget _buildMealsList({required Key key}) {
    if (_fullMenu == null || _fullMenu![_selectedDay] == null) {
      return Padding(
        key: key,
        padding: const EdgeInsets.all(32.0),
        child: const Center(child: Text('No menu found for this day.')),
      );
    }

    final dayMenu = _fullMenu![_selectedDay];
    final Map<String, dynamic> cMenu = {};
    dayMenu.forEach((k, v) => cMenu[k.toLowerCase()] = v);

    final mealOrder = ['breakfast', 'lunch', 'snacks', 'dinner'];
    final displayNames = {
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'snacks': 'Snacks',
      'dinner': 'Dinner',
    };

    final colors = {
      'breakfast': Colors.amber, // Morning vibes
      'lunch': Colors.teal, // Fresh daytime
      'snacks': Colors.deepOrangeAccent, // Evening burst
      'dinner': Colors.indigoAccent, // Night time
    };

    final meals = mealOrder.where((meal) => cMenu.containsKey(meal)).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 16.0),
      child: Column(
        key: key,
        children: meals.asMap().entries.map((entry) {
          final int idx = entry.key;
          final String meal = entry.value;
          return MealCard(
            mealName: displayNames[meal]!,
            mealDetails: cMenu[meal],
            isLast: idx == meals.length - 1,
            timelineColor: colors[meal] ?? Colors.grey,
            timeRange: _getDisplayTimeRange(meal),
            isActive: _isMealActive(meal, _selectedDay),
            preference: _dietPreference,
            specialNote: meal == 'dinner'
                ? _getSpecialDinnerForSelectedDay()
                : '',
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreferenceToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Stronger than shade600, still clearly veg / non-veg
    const vegBold = Color(0xFF1B5E20);
    const nonVegBold = Color(0xFFB71C1C);

    Widget circle({
      required String value,
      required Color color,
      required IconData icon,
    }) {
      final selected = _dietPreference == value;
      final fill = selected
          ? color
          : color.withAlpha(isDark ? 130 : 105);
      final borderColor = selected ? color : color.withAlpha(220);
      return GestureDetector(
        onTap: () => _savePreference(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 34,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: selected ? 2.5 : 1.8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withAlpha(isDark ? 120 : 85),
                      blurRadius: 7,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle(value: 'veg', color: vegBold, icon: Icons.eco_rounded),
        circle(value: 'nonveg', color: nonVegBold, icon: Icons.set_meal_rounded),
      ],
    );
  }
}
