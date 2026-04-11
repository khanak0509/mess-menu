import 'package:flutter/material.dart';

class MealCard extends StatelessWidget {
  final String mealName;
  final Map<String, dynamic> mealDetails;
  final bool isLast;
  final Color timelineColor;
  final String timeRange;
  final bool isActive;
  final List<String> favorites;

  const MealCard({
    super.key,
    required this.mealName,
    required this.mealDetails,
    this.isLast = false,
    required this.timelineColor,
    required this.timeRange,
    this.isActive = false,
    this.favorites = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Keep line breaks and original formatting from CSV. Let text flow naturally.
    final mainText = mealDetails['Main']?.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim() ?? '';
    final compulsory = mealDetails['Compulsory']?.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim() ?? '';
    final complimentary = mealDetails['Complimentary']?.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim() ?? '';
    final jain = mealDetails['Jain']?.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim() ?? '';

    bool isValid(String text) {
      if (text.isEmpty) return false;
      final t = text.toLowerCase();
      // Filter out pandas NaN, nulls, and dashed empty placeholders from CSV
      if (t == 'nan' || t == 'null' || text == '—' || text == '-' || text == '--') return false;
      return true;
    }

    final List<String> parts = [];
    if (isValid(mainText)) parts.add(mainText);
    if (isValid(complimentary)) parts.add(complimentary);
    if (isValid(compulsory)) parts.add(compulsory);

    final partsText = parts.join('\n').toLowerCase();
    
    // Split the meals into individual identifiable dishes:
    final List<String> availableItems = partsText
        .split(RegExp(r'[,\n\/&]| and '))
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    bool hasFavorite = false;
    if (favorites.isNotEmpty) {
      for (final fav in favorites) {
        final f = fav.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (f.isEmpty) continue;
        
        // Exact element match, or string starts with "f " (e.g. "aloo paratha (butter)"), 
        // to prevent "aloo" from matching "aloo paratha" while allowing "aloo paratha" to match "aloo paratha (butter)"
        if (availableItems.any((item) => 
            item == f || 
            item.startsWith('$f ') || 
            item.endsWith(' $f') || 
            item == '${f}s')) {
          hasFavorite = true;
          break;
        }
      }
    }

    final paragraphText = parts.join('\n').replaceAll(', ,', ',');

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Very subtle, minimal colors for modern aesthetic apps (like Instagram/YT aesthetics)
    final neutralLineColor = isDark ? Colors.white12 : Colors.black12;
    
    // Highlight dynamically if meal is active now
    final neutralCardColor = isActive 
        ? Color.alphaBlend(timelineColor.withAlpha(isDark ? 45 : 30), isDark ? const Color(0xFF1E1E1E) : Colors.white)
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
        
    final borderColor = isActive
        ? timelineColor.withAlpha(isDark ? 200 : 150)
        : (isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20));
        
    final shadowColor = isActive
        ? timelineColor.withAlpha(isDark ? 60 : 30)
        : (isDark ? Colors.black.withAlpha(100) : Colors.black.withAlpha(15));
        
    final textColor = isDark ? Colors.white.withAlpha(230) : Colors.black.withAlpha(220);
    final subTextColor = isActive 
        ? (isDark ? timelineColor.withAlpha(200) : timelineColor.withAlpha(255))
        : (isDark ? Colors.white54 : Colors.black54);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 48,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 40,
                    bottom: -32,
                    child: Container(
                      width: 2,
                      color: neutralLineColor,
                    ),
                  ),
                Positioned(
                  top: isActive ? 34 : 36,
                  child: Container(
                    height: isActive ? 16 : 12,
                    width: isActive ? 16 : 12,
                    decoration: BoxDecoration(
                      color: timelineColor, // elegant subtle accent
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF111318) : const Color(0xFFFAFAFA),
                        width: isActive ? 3 : 2,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: timelineColor.withAlpha(isDark ? 200 : 150),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ] : [
                        BoxShadow(
                          color: timelineColor.withAlpha(100),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 16.0, top: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: neutralCardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? timelineColor.withAlpha(isDark ? 30 : 25) : null,
                      border: isActive ? Border(
                        left: BorderSide(
                          color: timelineColor,
                          width: 8.0,
                        ),
                      ) : (hasFavorite ? Border(
                        left: BorderSide(
                          color: Colors.amber.shade400,
                          width: 6.0,
                        ),
                      ) : Border(
                        left: BorderSide(
                          color: timelineColor.withAlpha(150),
                          width: 4.0,
                        ),
                      )),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mealName,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          fontSize: 20,
                                          color: textColor,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: timelineColor, // Solid vibrant background
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: timelineColor.withAlpha(isDark ? 80 : 120),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.black87 : Colors.white, 
                                            shape: BoxShape.circle
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'NOW',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                            color: isDark ? Colors.black87 : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (hasFavorite) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber.shade400,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              timeRange,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: subTextColor,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Content - Full Menu, no truncating, no maxlines!
                      Text(
                        paragraphText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: textColor.withAlpha(200),
                            ),
                      ),
                      // Jain Option
                      if (isValid(jain))
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.eco,
                                size: 16,
                                color: isDark ? Colors.green.shade400 : Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Jain: $jain',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
}
}
