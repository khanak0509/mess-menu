import 'package:flutter/material.dart';
import 'meal_detail_screen.dart';

class MealCard extends StatefulWidget {
  final String mealName;
  final Map<String, dynamic> mealDetails;
  final bool isLast;
  final Color timelineColor;
  final String timeRange;

  const MealCard({
    super.key,
    required this.mealName,
    required this.mealDetails,
    this.isLast = false,
    required this.timelineColor,
    required this.timeRange,
  });

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MealDetailScreen(
          mealName: widget.mealName,
          mealDetails: widget.mealDetails,
          mealColor: widget.timelineColor,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeInOutBack;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final mainText = widget.mealDetails['Main']?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    final compulsory = widget.mealDetails['Compulsory']?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    final complimentary = widget.mealDetails['Complimentary']?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    final jain = widget.mealDetails['Jain']?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

    // Build the paragraph replacing big gaps, making it look like a continuous string.
    final List<String> parts = [];
    if (mainText.isNotEmpty && mainText != 'nan') parts.add(mainText);
    if (complimentary.isNotEmpty && complimentary != 'nan') parts.add(complimentary);
    if (compulsory.isNotEmpty && compulsory != 'nan') parts.add(compulsory);

    final paragraphText = parts.join(', ').replaceAll(', ,', ',');

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final timelineLineColor = widget.timelineColor.withAlpha(isDark ? 150 : 200);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Column
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Continuous line that goes all the way down unless it's the last item
                if (!widget.isLast)
                  Positioned(
                    top: 24, // starts from middle of the circle
                    bottom: -32, // extends into the padding of the next item
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: timelineLineColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Positioned(
                  top: 20,
                  child: Container(
                    height: 14,
                    width: 14,
                    decoration: BoxDecoration(
                      color: widget.timelineColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.timelineColor.withAlpha(100),
                          blurRadius: 6,
                          spreadRadius: 2,
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
              padding: const EdgeInsets.only(bottom: 32.0, right: 16.0),
              child: GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    color: Colors.transparent, // Keeps the tap target active without a heavy card box
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.mealName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    fontSize: 22,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              widget.timeRange,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Underline as requested in the screenshot
                        Divider(
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(40),
                          thickness: 1,
                        ),
                        const SizedBox(height: 8),
                        // Content Paragraph
                        Hero(
                          tag: 'meal_title_${widget.mealName}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              paragraphText,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.6,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha(220),
                                  ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Jain Option
                        if (jain.isNotEmpty && jain != 'nan')
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer.withAlpha(100),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Theme.of(context).colorScheme.tertiary.withAlpha(100)),
                              ),
                              child: Text(
                                'Jain: $jain',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Theme.of(context).colorScheme.onTertiaryContainer : Theme.of(context).colorScheme.tertiary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
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
