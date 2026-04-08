import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'meal_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> days = const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  late String _selectedDay;
  Map<String, dynamic>? _fullMenu;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = _getCurrentDay();
    _loadMenu();
  }

  String _getCurrentDay() {
    return days[DateTime.now().weekday - 1];
  }

  Future<void> _loadMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedMenu = prefs.getString('cached_menu');

      if (cachedMenu != null) {
        setState(() {
          _fullMenu = json.decode(cachedMenu);
          _isLoading = false;
        });
      } else {
        await _fetchMenuFromApi();
      }
    } catch (e) {
      // Fallback
      await _fetchMenuFromApi();
    }
  }

  Future<void> _fetchMenuFromApi() async {
    setState(() => _isLoading = true);
    try {
      // Using Android localhost IP: 'http://10.0.2.2:8000/menu'
      // Using iOS Simulator IP: 'http://127.0.0.1:8000/menu'
      final url = Uri.parse('http://127.0.0.1:8000/menu'); 
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_menu', response.body);
        setState(() {
          _fullMenu = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load menu';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No cached data & failed to connect to API.';
        _isLoading = false;
      });
    }
  }

  String _getUpNextMealName(Map<String, dynamic> dayMenu) {
    final now = DateTime.now();
    final currentHour = now.hour + now.minute / 60.0;

    if (currentHour < 10.0) return "Breakfast";
    if (currentHour < 14.5) return "Lunch";
    if (currentHour < 18.0) return "Snacks";
    if (currentHour < 21.5) return "Dinner";
    return "Breakfast (Tomorrow)";
  }

  Widget _buildHeroSection() {
    if (_fullMenu == null || _fullMenu![_getCurrentDay()] == null) {
      return const SizedBox.shrink();
    }
    
    final todayMenu = _fullMenu![_getCurrentDay()];
    
    // Case-insensitive mapping 
    final Map<String, dynamic> cMenu = {};
    todayMenu.forEach((k, v) => cMenu[k.toLowerCase()] = v);

    final nextMealKey = _getUpNextMealName(todayMenu);
    
    // Safety check if "Breakfast (Tomorrow)" or etc.
    String mainItemString = "Not available";
    if (cMenu.containsKey(nextMealKey.toLowerCase())) {
        mainItemString = cMenu[nextMealKey.toLowerCase()]['Main'] ?? "Check below";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(50),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                'UP NEXT',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            nextMealKey,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            mainItemString,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(200),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
                baseColor: Theme.of(context).colorScheme.outlineVariant.withAlpha(20),
                highlightColor: Theme.of(context).colorScheme.surface,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.outlineVariant.withAlpha(20),
                  highlightColor: Theme.of(context).colorScheme.surface,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Menu', style: TextStyle(fontWeight: FontWeight.w800)),
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchMenuFromApi,
                  child: ListView(
                    children: [
                      _buildHeroSection(),
                      _buildDaySelector(),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildMealsList(key: ValueKey(_selectedDay)),
                      ),
                    ],
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
      'dinner': 'Dinner'
    };
    
    final colors = {
      'breakfast': Colors.orangeAccent,
      'lunch': Colors.purpleAccent,
      'dinner': Colors.pinkAccent,
      'snacks': Colors.tealAccent,
    };
    
    final times = {
      'breakfast': '7:30 - 9:30 AM',
      'lunch': '12:00 - 2:00 PM',
      'snacks': '5:00 - 6:00 PM',
      'dinner': '7:30 - 9:30 PM',
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
            timeRange: times[meal] ?? '',
          );
        }).toList(),
      ),
    );
  }
}

