import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'meal_card.dart';
import 'qr_pass_button.dart';
import 'favorites_sheet.dart';

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
  List<String> _userFavorites = [];
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
      final favMap = prefs.getStringList('favorite_items') ?? [];
      
      setState(() {
         _userFavorites = favMap;
      });

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
      // Using production Render URL
      final String baseUrl = 'https://mess-backend-uydy.onrender.com/menu';
      
      final url = Uri.parse(baseUrl); 
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
    
    if (meal == 'breakfast' && currentHour >= 7.5 && currentHour < 10.0) return true;
    if (meal == 'lunch' && currentHour >= 12.25 && currentHour < 14.75) return true;
    if (meal == 'snacks' && currentHour >= 17.5 && currentHour < 18.5) return true;
    if (meal == 'dinner' && currentHour >= 19.5 && currentHour < 22.5) return true;
    
    return false;
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
        title: const Text('IITJ Menu'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline_rounded),
            onPressed: () {
              FavoritesSheet.show(context).then((_) {
                 _loadMenu();
              });
            },
          ),
          const QRPassButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _fetchMenuFromApi,
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),
                      // _buildHeroSection(), // Removed huge "UP NEXT" header card based on pure minimalistic layout requirement
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
      'breakfast': Colors.amber,          // Morning vibes
      'lunch': Colors.teal,               // Fresh daytime
      'snacks': Colors.deepOrangeAccent,  // Evening burst
      'dinner': Colors.indigoAccent,      // Night time
    };
    
    final times = {
      'breakfast': '7:30 AM - 10:00 AM',
      'lunch': '12:15 PM - 2:45 PM',
      'snacks': '5:30 PM - 6:30 PM',
      'dinner': '7:30 PM - 10:30 PM',
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
            isActive: _isMealActive(meal, _selectedDay),
          );
        }).toList(),
      ),
    );
  }
}

