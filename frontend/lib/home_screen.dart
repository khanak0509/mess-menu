import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'meal_card.dart';
import 'qr_pass_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const String _apiBaseUrl = 'https://mess-menu-v458.onrender.com';
  static const String _githubRepoUrl = 'https://github.com/khanak0509/mess-menu';
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
  final ScrollController _dayScrollController = ScrollController();
  final Map<String, GlobalKey> _dayItemKeys = {
    'Monday': GlobalKey(),
    'Tuesday': GlobalKey(),
    'Wednesday': GlobalKey(),
    'Thursday': GlobalKey(),
    'Friday': GlobalKey(),
    'Saturday': GlobalKey(),
    'Sunday': GlobalKey(),
  };
  Map<String, dynamic>? _fullMenu;
  bool _isLoading = true;
  bool _didInitialDayScrollAfterLoad = false;
  bool _sessionDismissedUpdate = false;
  String _errorMessage = '';
  String _dietPreference = 'veg';
  String _specialDinnerDate = '';
  String _specialDinnerVegText = '';
  String _specialDinnerNonVegText = '';
  String _examStartDate = '';
  String _examEndDate = '';
  String _examBreakfastTime = '';
  String _examNote = '';
  Map<String, String> _examBreakfasts = {};
  Map<String, dynamic>? _pendingAppUpdate;
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
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _getCurrentDay();
    _scrollToSelectedDay();
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = _getCurrentDay();
      // Only jump when the calendar day changed — don't yank the strip
      // while the user is browsing other days.
      if (_selectedDay != today) {
        setState(() => _selectedDay = today);
        _scrollToSelectedDay(animate: true);
      }
    }
  }

  String _getCurrentDay() {
    return days[DateTime.now().weekday - 1];
  }

  void _scrollToSelectedDay({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dayKey = _dayItemKeys[_selectedDay];
      final dayContext = dayKey?.currentContext;
      if (dayContext == null) return;

      Scrollable.ensureVisible(
        dayContext,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
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

  DateTime? _parseIsoDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String _isoFromDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Best matching exam date for a weekday name (prefers today/upcoming).
  DateTime? _examDateForDayName(String dayName) {
    if (_examBreakfasts.isEmpty) return null;
    final dayIndex = days.indexOf(dayName);
    if (dayIndex < 0) return null;

    final start = _parseIsoDate(_examStartDate);
    final end = _parseIsoDate(_examEndDate);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    DateTime? best;
    var bestScore = 1 << 30;

    for (final entry in _examBreakfasts.entries) {
      final date = _parseIsoDate(entry.key);
      if (date == null) continue;
      if (date.weekday - 1 != dayIndex) continue;
      if (start != null && date.isBefore(start)) continue;
      if (end != null && date.isAfter(end)) continue;

      final score = date.difference(todayOnly).inDays.abs();
      final adjusted = date.isBefore(todayOnly) ? score + 1000 : score;
      if (adjusted < bestScore) {
        bestScore = adjusted;
        best = date;
      }
    }
    return best;
  }

  String? _examBreakfastForDay(String dayName) {
    final date = _examDateForDayName(dayName);
    if (date == null) return null;
    return _examBreakfasts[_isoFromDate(date)];
  }

  bool _selectedDayHasExamBreakfast() {
    final item = _examBreakfastForDay(_selectedDay);
    return item != null && item.trim().isNotEmpty;
  }

  Map<String, dynamic> _mealDetailsForDisplay(
    String meal,
    Map<String, dynamic> cMenu,
  ) {
    final raw = cMenu[meal];
    final details = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (meal == 'breakfast') {
      final examItem = _examBreakfastForDay(_selectedDay);
      if (examItem != null && examItem.trim().isNotEmpty) {
        details['Main'] = examItem.trim();
      }
    }
    return details;
  }

  void _applyMenuPayload(Map<String, dynamic> payload) {
    final rawMenu = payload['menu'];
    final menu = (rawMenu is Map<String, dynamic>) ? rawMenu : payload;
    final config = payload['config'];

    if (config is Map<String, dynamic>) {
      final timingsRaw = config['timings'];
      final specialRaw = config['special_dinner'];
      final examRaw = config['exam_schedule'];
      final updateRaw = config['app_update'];

      if (timingsRaw is Map<String, dynamic>) {
        _mealTimings = {
          ..._mealTimings,
          ...timingsRaw.map((k, v) => MapEntry(k, v.toString())),
        };
      }
      if (specialRaw is Map<String, dynamic>) {
        _specialDinnerDate = (specialRaw['date'] ?? '').toString().trim();
        _specialDinnerVegText =
            (specialRaw['veg_text'] ?? '').toString().trim();
        _specialDinnerNonVegText =
            (specialRaw['nonveg_text'] ?? '').toString().trim();
      } else if (config['special_dinner_text'] != null) {
        _specialDinnerDate = '';
        _specialDinnerVegText =
            (config['special_dinner_text'] ?? '').toString().trim();
        _specialDinnerNonVegText = '';
      }

      if (examRaw is Map<String, dynamic>) {
        _examStartDate = (examRaw['start_date'] ?? '').toString().trim();
        _examEndDate = (examRaw['end_date'] ?? '').toString().trim();
        _examBreakfastTime =
            (examRaw['breakfast_time'] ?? '').toString().trim();
        _examNote = (examRaw['note'] ?? '').toString().trim();
        final breakfastsRaw = examRaw['breakfasts'];
        final parsed = <String, String>{};
        if (breakfastsRaw is Map) {
          breakfastsRaw.forEach((k, v) {
            final key = k.toString().trim();
            final value = v.toString().trim();
            if (key.isNotEmpty && value.isNotEmpty) {
              parsed[key] = value;
            }
          });
        }
        _examBreakfasts = parsed;
      } else {
        _examStartDate = '';
        _examEndDate = '';
        _examBreakfastTime = '';
        _examNote = '';
        _examBreakfasts = {};
      }

      if (updateRaw is Map<String, dynamic>) {
        _pendingAppUpdate = Map<String, dynamic>.from(updateRaw);
      } else if (updateRaw is Map) {
        _pendingAppUpdate = updateRaw.map(
          (k, v) => MapEntry(k.toString(), v),
        );
      }
    }

    setState(() {
      _fullMenu = menu;
      _isLoading = false;
    });

    // Center today's chip only on the first successful load.
    if (!_didInitialDayScrollAfterLoad) {
      _didInitialDayScrollAfterLoad = true;
      _scrollToSelectedDay(animate: false);
    }

    // Re-check on every menu load (refresh / reopen), not only once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowUpdateDialog();
    });
  }

  Future<void> _maybeShowUpdateDialog() async {
    final update = _pendingAppUpdate;
    if (update == null || !mounted) return;
    if (_sessionDismissedUpdate) return;

    final apkUrl = (update['apk_url'] ?? '').toString().trim();
    final message = (update['message'] ?? '').toString().trim();
    // Show only when both note + link are set (admin clears them to hide).
    if (apkUrl.isEmpty || message.isEmpty) return;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update available'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                _sessionDismissedUpdate = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openExternalUrl(apkUrl);
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openGitHubStar() async {
    await _openExternalUrl(_githubRepoUrl);
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
    final bool showFullLoader = _fullMenu == null;
    if (showFullLoader) {
      setState(() => _isLoading = true);
    }
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
    if (meal == 'breakfast' &&
        _selectedDayHasExamBreakfast() &&
        _examBreakfastTime.contains('-')) {
      final parts = _examBreakfastTime.split('-');
      if (parts.length == 2) {
        return (parts[0].trim(), parts[1].trim());
      }
    }
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
    return _isoFromDate(DateTime.now());
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

  Widget _buildExamBanner() {
    if (!_selectedDayHasExamBreakfast()) return const SizedBox.shrink();
    final note = _examNote.trim().isNotEmpty
        ? _examNote.trim()
        : 'Exam schedule — breakfast time/menu changed';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.indigo.withAlpha(28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.withAlpha(90)),
        ),
        child: Text(
          note,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.indigo.shade100
                : Colors.indigo.shade900,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final isSelected = days[index] == _selectedDay;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDay = days[index]);
              _scrollToSelectedDay(animate: true);
            },
            child: AnimatedContainer(
              key: _dayItemKeys[days[index]],
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
          IconButton(
            tooltip: 'Star on GitHub',
            onPressed: _openGitHubStar,
            icon: const Icon(Icons.star_border_rounded),
          ),
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
                  _buildExamBanner(),
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
      'breakfast': Colors.amber,
      'lunch': Colors.teal,
      'snacks': Colors.deepOrangeAccent,
      'dinner': Colors.indigoAccent,
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
            mealDetails: _mealDetailsForDisplay(meal, cMenu),
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
    const vegBold = Color(0xFF1B5E20);
    const nonVegBold = Color(0xFFB71C1C);

    Widget circle({
      required String value,
      required Color color,
      required IconData icon,
    }) {
      final selected = _dietPreference == value;
      final fill = selected ? color : color.withAlpha(isDark ? 130 : 105);
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
        circle(
          value: 'nonveg',
          color: nonVegBold,
          icon: Icons.set_meal_rounded,
        ),
      ],
    );
  }
}
