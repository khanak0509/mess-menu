import 'package:flutter/material.dart';

class MealDetailScreen extends StatelessWidget {
  final String mealName;
  final Map<String, dynamic> mealDetails;
  final Color mealColor;

  const MealDetailScreen({
    super.key,
    required this.mealName,
    required this.mealDetails,
    required this.mealColor,
  });

  @override
  Widget build(BuildContext context) {
    final main = mealDetails['Main']?.toString() ?? '';
    final compulsory = mealDetails['Compulsory']?.toString() ?? '';
    final complimentary = mealDetails['Complimentary']?.toString() ?? '';
    final jain = mealDetails['Jain']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('$mealName Details'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'meal_title_$mealName',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  main,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (compulsory.isNotEmpty && compulsory != 'nan') ...[
              _buildSectionTitle(context, 'Compulsory Items'),
              _buildCleanList(context, compulsory),
              const SizedBox(height: 24),
            ],
            if (complimentary.isNotEmpty && complimentary != 'nan') ...[
              _buildSectionTitle(context, 'Complimentary Items'),
              _buildCleanList(context, complimentary),
              const SizedBox(height: 24),
            ],
            if (jain.isNotEmpty && jain != 'nan') ...[
              _buildSectionTitle(context, 'Jain Options', color: Colors.orange.shade400),
              _buildCleanList(context, jain),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color ?? mealColor,
            ),
      ),
    );
  }

  Widget _buildCleanList(BuildContext context, String content) {
    final items = content.split(RegExp(r',|/')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Expanded(
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
