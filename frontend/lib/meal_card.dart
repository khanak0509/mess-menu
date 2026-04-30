import 'package:flutter/material.dart';

class MealCard extends StatelessWidget {
  final String mealName;
  final Map<String, dynamic> mealDetails;
  final bool isLast;
  final Color timelineColor;
  final String timeRange;
  final bool isActive;
  final String preference;
  final String specialNote;

  const MealCard({
    super.key,
    required this.mealName,
    required this.mealDetails,
    this.isLast = false,
    required this.timelineColor,
    required this.timeRange,
    this.isActive = false,
    this.preference = 'veg',
    this.specialNote = '',
  });

  @override
  Widget build(BuildContext context) {
    final mainText =
        mealDetails['Main']
            ?.toString()
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim() ??
        '';
    final compulsory =
        mealDetails['Compulsory']
            ?.toString()
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim() ??
        '';
    final complimentary =
        mealDetails['Complimentary']
            ?.toString()
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim() ??
        '';
    final jain =
        mealDetails['Jain']
            ?.toString()
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim() ??
        '';
    final nonVeg =
        mealDetails['NonVeg']
            ?.toString()
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim() ??
        '';

    bool isValid(String text) {
      if (text.isEmpty) return false;
      final t = text.toLowerCase();
      if (t == 'nan' ||
          t == 'null' ||
          text == '—' ||
          text == '-' ||
          text == '--') {
        return false;
      }
      return true;
    }

    final List<String> vegParts = [];
    if (isValid(mainText)) vegParts.add(mainText);
    if (isValid(complimentary)) vegParts.add(complimentary);
    if (isValid(compulsory)) vegParts.add(compulsory);

    final vegText = vegParts.join('\n').replaceAll(', ,', ',');
    final hasSpecialNote =
        specialNote.trim().isNotEmpty && mealName.toLowerCase() == 'dinner';

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final nonVegLabelColor = isDark
        ? const Color(0xFF9FA8DA)
        : const Color(0xFF3949AB);
    final nonVegBodyColor = isDark
        ? const Color(0xFFC5CAE9)
        : const Color(0xFF283593);

    final specialBg = Color.alphaBlend(
      (isDark ? const Color(0xFF7E57C2) : const Color(0xFF5E35B1)).withAlpha(
        isDark ? 36 : 22,
      ),
      isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );
    final specialBorder =
        (isDark ? const Color(0xFFB39DDB) : const Color(0xFF5E35B1)).withAlpha(
          isDark ? 100 : 85,
        );
    final specialIconColor = isDark
        ? const Color(0xFFD1C4E9)
        : const Color(0xFF4527A0);
    final specialTextColor = isDark
        ? const Color(0xFFE1BEE7)
        : const Color(0xFF4A148C);

    final neutralLineColor = isDark ? Colors.white12 : Colors.black12;

    final neutralCardColor = isActive
        ? Color.alphaBlend(
            timelineColor.withAlpha(isDark ? 45 : 30),
            isDark ? const Color(0xFF1E1E1E) : Colors.white,
          )
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    final borderColor = isActive
        ? timelineColor.withAlpha(isDark ? 200 : 150)
        : (isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20));

    final shadowColor = isActive
        ? timelineColor.withAlpha(isDark ? 60 : 30)
        : (isDark ? Colors.black.withAlpha(100) : Colors.black.withAlpha(15));

    final textColor = isDark
        ? Colors.white.withAlpha(230)
        : Colors.black.withAlpha(220);
    final subTextColor = isActive
        ? (isDark ? timelineColor.withAlpha(200) : timelineColor.withAlpha(255))
        : (isDark ? Colors.white54 : Colors.black54);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 40,
                    bottom: -32,
                    child: Container(width: 2, color: neutralLineColor),
                  ),
                Positioned(
                  top: isActive ? 34 : 36,
                  child: Container(
                    height: isActive ? 16 : 12,
                    width: isActive ? 16 : 12,
                    decoration: BoxDecoration(
                      color: timelineColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF111318)
                            : const Color(0xFFFAFAFA),
                        width: isActive ? 3 : 2,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: timelineColor.withAlpha(
                                  isDark ? 200 : 150,
                                ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
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

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 24.0,
                right: 16.0,
                top: 12.0,
              ),
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
                      color: isActive
                          ? timelineColor.withAlpha(isDark ? 30 : 25)
                          : null,
                      border: isActive
                          ? Border(
                              left: BorderSide(
                                color: timelineColor,
                                width: 8.0,
                              ),
                            )
                          : Border(
                              left: BorderSide(
                                color: timelineColor.withAlpha(150),
                                width: 4.0,
                              ),
                            ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: timelineColor,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: timelineColor.withAlpha(
                                                isDark ? 80 : 120,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.black87
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'NOW',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                                color: isDark
                                                    ? Colors.black87
                                                    : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withAlpha(10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  timeRange,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: subTextColor,
                                        letterSpacing: 0.2,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (hasSpecialNote) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: specialIconColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Special dinner',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: specialTextColor.withAlpha(230),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (!hasSpecialNote) ...[
                            if (preference == 'nonveg') ...[
                              if (vegText.trim().isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Veg Items',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade400,
                                            letterSpacing: 0.2,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      vegText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            height: 1.6,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: textColor.withAlpha(200),
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                  ],
                                ),
                              if (isValid(nonVeg))
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Non-Veg Items',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: nonVegLabelColor,
                                            letterSpacing: 0.2,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      nonVeg,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            height: 1.6,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: nonVegBodyColor,
                                          ),
                                    ),
                                  ],
                                ),
                            ] else
                              Text(
                                vegText,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      height: 1.6,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: textColor.withAlpha(200),
                                    ),
                              ),
                          ],
                          if (!hasSpecialNote && isValid(jain))
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.eco,
                                    size: 16,
                                    color: isDark
                                        ? Colors.green.shade400
                                        : Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Jain: $jain',
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.green.shade300
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (hasSpecialNote)
                            Container(
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: specialBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: specialBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.celebration_rounded,
                                    size: 16,
                                    color: specialIconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Special Dinner: ${specialNote.trim()}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        color: specialTextColor,
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
