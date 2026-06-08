import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../core/providers/home_provider.dart';
import '../../core/theme/app_colors.dart';
import 'barcode_scan_panel.dart';
import 'food_search_panel.dart';
import 'my_food_screen.dart';
import 'quick_add_screen.dart';
import 'photo_analyze_panel.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/meal_restrictions_service.dart';

class AddMealManualScreen extends StatefulWidget {
  final String? mealType;
  final String? mealTitle;
  final int? targetCalories;
  final int? consumedCalories;
  final String? mealImageAsset;
  final DateTime? selectedDate;
  final int? dailyCalorieTarget;
  final int? dailyProteinTarget;
  final int? dailyFatTarget;
  final int? dailyCarbsTarget;

  const AddMealManualScreen({
    super.key,
    this.mealType,
    this.mealTitle,
    this.targetCalories,
    this.consumedCalories,
    this.mealImageAsset,
    this.selectedDate,
    this.dailyCalorieTarget,
    this.dailyProteinTarget,
    this.dailyFatTarget,
    this.dailyCarbsTarget,
  });

  @override
  State<AddMealManualScreen> createState() => _AddMealManualScreenState();
}

class _AddMealManualScreenState extends State<AddMealManualScreen> {
  static const double _sheetMinSize = 0.24;
  static const double _sheetMaxSize = 1.0;
  static const Duration _dishRemoveAnimationDuration = Duration(
    milliseconds: 220,
  );
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _sheetExtent = _sheetMaxSize;

  int _selectedActionIndex = 0;
  int _addedFoodCount = 0;
  double _addedFoodCalories = 0;
  double _addedFoodProtein = 0;
  double _addedFoodFat = 0;
  double _addedFoodCarbs = 0;
  int _dishIdCounter = 0;
  final Set<int> _removingDishIds = <int>{};
  final List<_AddedDishEntry> _addedDishes = [];

  MealRestrictionProfile _restrictionProfile() {
    return MealRestrictionProfile.fromUser(context.read<UserProvider>().user);
  }

  Future<bool> _confirmMealAllowed({
    required String mealName,
    List<String> ingredients = const [],
    List<String> possibleAllergens = const [],
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final profile = _restrictionProfile();
    if (profile.isEmpty) return true;

    final assessment = MealRestrictionsService.assess(
      profile: profile,
      mealName: mealName,
      ingredients: ingredients,
      possibleAllergens: possibleAllergens,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    if (!assessment.hasIssues) return true;

    final blockedIssues = assessment.issues
        .where((issue) => issue.severity == MealRestrictionSeverity.blocked)
        .toList(growable: false);

    if (blockedIssues.isNotEmpty) {
      if (!mounted) return false;

      final allergyIssues = blockedIssues
          .where((issue) => issue.category == 'allergy')
          .toList(growable: false);
      final conditionIssues = blockedIssues
          .where((issue) => issue.category == 'condition')
          .toList(growable: false);

      final allergyLines = allergyIssues
          .expand(
            (issue) => issue.matchedTerms.isNotEmpty
                ? issue.matchedTerms
                : <String>[issue.label],
          )
          .toSet()
          .toList(growable: false);

      final conditionLines = conditionIssues
          .map((issue) => '${issue.label}: ${issue.reason}')
          .toSet()
          .toList(growable: false);

      final hasAllergyIssues = allergyLines.isNotEmpty;
      final hasConditionIssues = conditionLines.isNotEmpty;

      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
                border: Border.all(color: const Color(0xFFF0D3D3), width: 1),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        height: 140,
                        child: Lottie.asset(
                          'assets/lottie/Warning - tekkis.json',
                          fit: BoxFit.contain,
                          repeat: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasAllergyIssues ? 'Allergy alert' : 'Condition alert',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasAllergyIssues
                          ? 'This dish contains an ingredient that may trigger your allergy.'
                          : 'This dish may not be suitable for one of your medical conditions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.navy.withOpacity(0.78),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (hasAllergyIssues) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7F6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF4C9C5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Matched ingredient',
                              style: TextStyle(
                                color: Color(0xFFB9382E),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...allergyLines.map(
                              (ingredient) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '• $ingredient',
                                  style: const TextStyle(
                                    color: Color(0xFF7D2620),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (hasAllergyIssues && hasConditionIssues)
                      const SizedBox(height: 14),
                    if (hasConditionIssues) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF3D39A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Condition note',
                              style: TextStyle(
                                color: Color(0xFF9A5F00),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...conditionLines.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '• $line',
                                  style: const TextStyle(
                                    color: Color(0xFF7A4A00),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (hasAllergyIssues) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB9382E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.deepBlue,
                                  side: const BorderSide(
                                    color: Color(0xFFD8DDE6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F8A3C),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Add anyway',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (hasAllergyIssues) {
        return false;
      }

      return proceed == true;
    }

    return true;
  }

  bool get _hasMealSummary =>
      widget.mealTitle != null && widget.mealTitle!.trim().isNotEmpty;

  String get _resolvedMealImageAsset {
    final configured = (widget.mealImageAsset ?? '').trim();
    if (configured.isNotEmpty) return configured;
    final type = (widget.mealType ?? '').trim().toLowerCase();
    if (type.isEmpty) return 'assets/icons/eggs.png';

    return 'assets/icons/$type.png';
  }

  String get _displayMealTitle {
    final type = (widget.mealType ?? '').trim().toLowerCase();
    switch (type) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return widget.mealTitle ?? '';
    }
  }

  String _formatSelectedDate(DateTime? date) {
    if (date == null) return '';

    // Keep the full selected date (day/month/year) but display day + month only.
    final fullDate = DateTime(date.year, date.month, date.day);

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final monthIndex = fullDate.month - 1;
    final monthName = monthIndex >= 0 && monthIndex < months.length
        ? months[monthIndex]
        : '';
    return '${fullDate.day} $monthName';
  }

  Future<void> _registerNutrientsAddition(AddedNutrients nutrients) async {
    if (nutrients.restrictionsChecked) {
      setState(() {
        final double safeGrams = () {
          final double candidate = (nutrients.gramsAdded ?? 100).toDouble();
          if (!candidate.isFinite || candidate <= 0) return 100.0;
          return candidate;
        }();

        _addedFoodCount += 1;
        _addedFoodCalories += nutrients.calories;
        _addedFoodProtein += nutrients.protein;
        _addedFoodFat += nutrients.fat;
        _addedFoodCarbs += nutrients.carbs;
        final String resolvedName = (nutrients.foodName ?? '').trim().isEmpty
            ? 'Food item ${_addedFoodCount + 1}'
            : nutrients.foodName!.trim();
        _addedDishes.add(
          _AddedDishEntry(
            id: _dishIdCounter++,
            name: resolvedName,
            calories: nutrients.calories,
            grams: safeGrams,
            protein: nutrients.protein,
            fat: nutrients.fat,
            carbs: nutrients.carbs,
            ingredients: nutrients.ingredients,
            possibleAllergens: nutrients.possibleAllergens,
          ),
        );
      });
      return;
    }

    final mealName = (nutrients.foodName ?? '').trim().isEmpty
        ? 'Food item'
        : nutrients.foodName!.trim();

    final allowed = await _confirmMealAllowed(
      mealName: mealName,
      ingredients: nutrients.ingredients,
      possibleAllergens: nutrients.possibleAllergens,
      calories: nutrients.calories,
      protein: nutrients.protein,
      carbs: nutrients.carbs,
      fat: nutrients.fat,
    );

    if (!allowed || !mounted) return;

    setState(() {
      final double safeGrams = () {
        final double candidate = (nutrients.gramsAdded ?? 100).toDouble();
        if (!candidate.isFinite || candidate <= 0) return 100.0;
        return candidate;
      }();

      _addedFoodCount += 1;
      _addedFoodCalories += nutrients.calories;
      _addedFoodProtein += nutrients.protein;
      _addedFoodFat += nutrients.fat;
      _addedFoodCarbs += nutrients.carbs;
      final String resolvedName = (nutrients.foodName ?? '').trim().isEmpty
          ? 'Food item ${_addedFoodCount + 1}'
          : nutrients.foodName!.trim();
      _addedDishes.add(
        _AddedDishEntry(
          id: _dishIdCounter++,
          name: resolvedName,
          calories: nutrients.calories,
          grams: safeGrams,
          protein: nutrients.protein,
          fat: nutrients.fat,
          carbs: nutrients.carbs,
          ingredients: nutrients.ingredients,
          possibleAllergens: nutrients.possibleAllergens,
        ),
      );
    });
  }

  Future<void> _registerPreviousMealAddition(PreviousMealTemplate meal) async {
    final allowed = await _confirmMealAllowed(
      mealName: meal.mealName,
      calories: meal.calories.toDouble(),
      protein: meal.protein.toDouble(),
      carbs: meal.carbs.toDouble(),
      fat: meal.fat.toDouble(),
    );

    if (!allowed || !mounted) return;

    setState(() {
      final double safeGrams = meal.grams > 0 ? meal.grams.toDouble() : 100.0;

      _addedFoodCount += 1;
      _addedFoodCalories += meal.calories.toDouble();
      _addedFoodProtein += meal.protein.toDouble();
      _addedFoodFat += meal.fat.toDouble();
      _addedFoodCarbs += meal.carbs.toDouble();
      _addedDishes.add(
        _AddedDishEntry(
          id: _dishIdCounter++,
          name: meal.mealName,
          calories: meal.calories.toDouble(),
          grams: safeGrams,
          protein: meal.protein.toDouble(),
          fat: meal.fat.toDouble(),
          carbs: meal.carbs.toDouble(),
          ingredients: const [],
          possibleAllergens: const [],
        ),
      );
    });
  }

  Future<void> _removeAddedDishWithAnimation(int dishId) async {
    if (_removingDishIds.contains(dishId)) return;

    final int dishIndex = _addedDishes.indexWhere((dish) => dish.id == dishId);
    if (dishIndex == -1) return;

    setState(() {
      _removingDishIds.add(dishId);
    });

    await Future<void>.delayed(_dishRemoveAnimationDuration);

    if (!mounted) return;

    setState(() {
      _removingDishIds.remove(dishId);
      final int removeIndex = _addedDishes.indexWhere(
        (dish) => dish.id == dishId,
      );
      if (removeIndex == -1) return;

      final dish = _addedDishes.removeAt(removeIndex);
      _addedFoodCount = _addedDishes.length;
      _addedFoodCalories = (_addedFoodCalories - dish.calories).clamp(
        0,
        999999,
      );
      _addedFoodProtein = (_addedFoodProtein - dish.protein).clamp(0, 999999);
      _addedFoodFat = (_addedFoodFat - dish.fat).clamp(0, 999999);
      _addedFoodCarbs = (_addedFoodCarbs - dish.carbs).clamp(0, 999999);
    });
  }

  Future<void> _handleDoneTap() async {
    if (_addedDishes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    final String mealType = (widget.mealType ?? '').trim().toLowerCase();
    final allowedMealTypes = {'breakfast', 'lunch', 'snack', 'dinner'};
    final String resolvedMealType = allowedMealTypes.contains(mealType)
        ? mealType
        : 'snack';
    final DateTime selectedDate = DateUtils.dateOnly(
      widget.selectedDate ?? DateTime.now(),
    );

    final payload = _addedDishes
        .map(
          (dish) => <String, dynamic>{
            'mealName': dish.name,
            'calories': dish.calories,
            'protein': dish.protein,
            'carbs': dish.carbs,
            'fat': dish.fat,
            'grams': dish.grams,
            'ingredients': dish.ingredients,
            'possibleAllergens': dish.possibleAllergens,
          },
        )
        .toList(growable: false);

    try {
      await context.read<HomeProvider>().saveMealEntries(
        mealType: resolvedMealType,
        date: selectedDate,
        meals: payload,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save meal: $error')));
    }
  }

  Widget _buildActionItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _selectedActionIndex == index;

    return SizedBox(
      width: 82,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedActionIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.mediumBlue.withOpacity(0.12),
          highlightColor: AppColors.mediumBlue.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  height: 45,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.lightBlue.withOpacity(0.35)
                        : AppColors.white.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.mediumBlue
                          : AppColors.dark.withOpacity(0.05),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: isSelected ? AppColors.deepBlue : AppColors.navy,
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AppColors.deepBlue : AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _fallbackMealRatio(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 0.30;
      case 'lunch':
        return 0.35;
      case 'dinner':
        return 0.25;
      case 'snack':
        return 0.10;
      default:
        return 0.25;
    }
  }

  int _mealMacroTargetFromDaily(int? dailyTarget, double ratio) {
    final int safeDaily = (dailyTarget ?? 0).clamp(0, 999999);
    if (safeDaily <= 0) return 0;
    return (safeDaily * ratio).round().clamp(0, 999999);
  }

  double _metricProgress(int added, int target) {
    if (target <= 0) return 0;
    return (added / target).clamp(0.0, 1.0);
  }

  Widget _buildMealMetricCircle({
    required String label,
    required int added,
    required int target,
    required String unit,
    required double progress,
    required Color color,
  }) {
    final double safeProgress = progress.clamp(0.0, 1.0);
    final String targetWithUnit = unit.isEmpty ? '$target' : '$target$unit';
    final Color trackColor = color.withOpacity(0.42);
    final HSLColor hslBase = HSLColor.fromColor(color);
    final double darkening = Curves.easeIn.transform(safeProgress);
    final double tunedLightness = (hslBase.lightness - (0.22 * darkening))
        .clamp(0.18, 0.72);
    final Color progressColor = hslBase
        .withLightness(tunedLightness)
        .withSaturation((hslBase.saturation + 0.06).clamp(0.0, 1.0))
        .toColor();

    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CustomPaint(
                    painter: _MealMetricRingPainter(
                      progress: safeProgress,
                      trackColor: trackColor,
                      progressColor: progressColor,
                      strokeWidth: 4.8,
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFDFEFF),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$added',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/$targetWithUnit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.navy.withOpacity(0.95),
                        fontSize: 6.8,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String mealType = (widget.mealType ?? '').trim().toLowerCase();
    final int targetCalories = (widget.targetCalories ?? 0).clamp(0, 999999);
    final int consumedCalories = (widget.consumedCalories ?? 0).clamp(
      0,
      999999,
    );
    final int addedCalories = _addedFoodCalories.round();
    final int addedProtein = _addedFoodProtein.round();
    final int addedFat = _addedFoodFat.round();
    final int addedCarbs = _addedFoodCarbs.round();
    final int displayedCalories = (consumedCalories + addedCalories).clamp(
      0,
      999999,
    );
    final double calorieProgress = targetCalories <= 0
        ? 0
        : (displayedCalories / targetCalories).clamp(0.0, 1.0);

    final double mealImageSize = mealType == 'snack' ? 58 : 58;
    final String caloriesLine = '$displayedCalories / $targetCalories kcal';
    final String addedMealCaloriesLine =
        '$addedCalories / $targetCalories kcal';
    final double addedMealProgress = targetCalories <= 0
        ? 0
        : (addedCalories / targetCalories).clamp(0.0, 1.0);
    final String selectedDateLabel = _formatSelectedDate(widget.selectedDate);
    final bool showTopSummaryHeader = _sheetExtent > 0.24;
    final bool showAddMoreFoodButton = _sheetExtent <= 0.24;

    final int safeDailyCalories = (widget.dailyCalorieTarget ?? 0).clamp(
      0,
      999999,
    );
    final double mealRatio = safeDailyCalories > 0 && targetCalories > 0
        ? (targetCalories / safeDailyCalories).clamp(0.0, 1.0)
        : _fallbackMealRatio(mealType);

    final int mealCaloriesTarget = targetCalories > 0
        ? targetCalories
        : (safeDailyCalories * mealRatio).round().clamp(0, 999999);
    final int mealFatTarget = _mealMacroTargetFromDaily(
      widget.dailyFatTarget,
      mealRatio,
    );
    final int mealProteinTarget = _mealMacroTargetFromDaily(
      widget.dailyProteinTarget,
      mealRatio,
    );
    final int mealCarbsTarget = _mealMacroTargetFromDaily(
      widget.dailyCarbsTarget,
      mealRatio,
    );
    final double mealCaloriesFill = _metricProgress(
      addedCalories,
      mealCaloriesTarget,
    );
    final double mealFatFill = _metricProgress(addedFat, mealFatTarget);
    final double mealProteinFill = _metricProgress(
      addedProtein,
      mealProteinTarget,
    );
    final double mealCarbsFill = _metricProgress(addedCarbs, mealCarbsTarget);

    final double headerBlueStrength =
        ((_sheetExtent - _sheetMinSize) / (_sheetMaxSize - _sheetMinSize))
            .clamp(0.0, 1.0);

    final Color softenedHeaderBlue =
        Color.lerp(AppColors.mediumBlue, Colors.white, 0.12) ??
        AppColors.mediumBlue;

    final Color pageBackgroundColor =
        Color.lerp(
          AppColors.background,
          softenedHeaderBlue,
          headerBlueStrength,
        ) ??
        AppColors.background;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  if (_hasMealSummary && showTopSummaryHeader)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.white,
                                      border: Border.all(
                                        color: _addedFoodCount > 0
                                            ? AppColors.navy
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        _resolvedMealImageAsset,
                                        width: mealImageSize,
                                        height: mealImageSize,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) {
                                          return const Icon(
                                            Icons.restaurant_rounded,
                                            color: AppColors.deepBlue,
                                            size: 30,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                if (_addedFoodCount > 0)
                                  Positioned(
                                    top: 10,
                                    right: 12,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                          ),
                                          child: FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        key: ValueKey(_addedFoodCount),
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: AppColors.navy,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$_addedFoodCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _displayMealTitle,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 0.5),
                                Text(
                                  caloriesLine,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    width: 104,
                                    height: 6,
                                    color: Colors.white.withOpacity(0.35),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: calorieProgress,
                                        child: Container(
                                          color: Colors.white.withOpacity(0.95),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.translate(
                          offset: const Offset(0, -8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _addedFoodCount > 0
                                  ? SizedBox(
                                      height: 40,
                                      child: ElevatedButton(
                                        onPressed: _handleDoneTap,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.navy,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Done',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.45),
                                        ),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                              if (selectedDateLabel.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                Text(
                                  selectedDateLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, -0.08),
                        end: Offset.zero,
                      ).animate(animation);

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: showAddMoreFoodButton
                        ? Padding(
                            key: const ValueKey('collapsed_top_controls'),
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 44,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedActionIndex = 0;
                                          });

                                          if (_sheetController.isAttached) {
                                            _sheetController.animateTo(
                                              _sheetMaxSize,
                                              duration: const Duration(
                                                milliseconds: 280,
                                              ),
                                              curve: Curves.easeOutCubic,
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFF0F2F5,
                                          ),
                                          foregroundColor: AppColors.deepBlue,
                                          elevation: 0,
                                          minimumSize: const Size(182, 44),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.keyboard_arrow_up_rounded,
                                              size: 18,
                                              color: AppColors.deepBlue,
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              ' Add More Food ',
                                              style: TextStyle(
                                                color: AppColors.deepBlue,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    _addedFoodCount > 0
                                        ? SizedBox(
                                            height: 44,
                                            child: ElevatedButton(
                                              onPressed: _handleDoneTap,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.navy,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 22,
                                                    ),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              ),
                                              child: const Text(
                                                'Done',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 52,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.45,
                                                ),
                                              ),
                                            ),
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                                if (_displayMealTitle.trim().isNotEmpty) ...[
                                  const SizedBox(height: 40),
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          _displayMealTitle,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          addedMealCaloriesLine,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          child: Container(
                                            width: 180,
                                            height: 8,
                                            color: Color(0xFFCDECCF),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: FractionallySizedBox(
                                                widthFactor: addedMealProgress,
                                                child: Container(
                                                  color: Color(0xFF1F8A3C),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildMealMetricCircle(
                                              label: 'Calories',
                                              added: addedCalories,
                                              target: mealCaloriesTarget,
                                              unit: 'kcal',
                                              progress: mealCaloriesFill,
                                              color: AppColors
                                                  .calorieRingGradientStart,
                                            ),
                                            _buildMealMetricCircle(
                                              label: 'Fat',
                                              added: addedFat,
                                              target: mealFatTarget,
                                              unit: 'g',
                                              progress: mealFatFill,
                                              color: AppColors.macroFat,
                                            ),
                                            _buildMealMetricCircle(
                                              label: 'Protein',
                                              added: addedProtein,
                                              target: mealProteinTarget,
                                              unit: 'g',
                                              progress: mealProteinFill,
                                              color: AppColors.macroProtein,
                                            ),
                                            _buildMealMetricCircle(
                                              label: 'Carbs',
                                              added: addedCarbs,
                                              target: mealCarbsTarget,
                                              unit: 'g',
                                              progress: mealCarbsFill,
                                              color: AppColors.macroCarbs,
                                            ),
                                          ],
                                        ),
                                        if (_addedDishes.isEmpty) ...[
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            width: 250,
                                            height: 250,
                                            child: Lottie.asset(
                                              'assets/lottie/nothing.json',
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ],
                                        if (_addedDishes.isNotEmpty) ...[
                                          //  const SizedBox(height: 30),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              8,
                                              16,
                                              0,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: _addedDishes
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                        final index = entry.key;
                                                        final dish =
                                                            entry.value;
                                                        final isRemoving =
                                                            _removingDishIds
                                                                .contains(
                                                                  dish.id,
                                                                );
                                                        final isLast =
                                                            index ==
                                                            _addedDishes
                                                                    .length -
                                                                1;
                                                        return AnimatedSlide(
                                                          duration:
                                                              _dishRemoveAnimationDuration,
                                                          curve: Curves
                                                              .easeOutCubic,
                                                          offset: isRemoving
                                                              ? const Offset(
                                                                  0.08,
                                                                  0,
                                                                )
                                                              : Offset.zero,
                                                          child: AnimatedOpacity(
                                                            duration:
                                                                _dishRemoveAnimationDuration,
                                                            curve:
                                                                Curves.easeOut,
                                                            opacity: isRemoving
                                                                ? 0
                                                                : 1,
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    bottom: 12,
                                                                  ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    dish.name,
                                                                    textAlign:
                                                                        TextAlign
                                                                            .left,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          14.5,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color: AppColors
                                                                          .navy,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 3,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child: Text(
                                                                          '${dish.calories.round()} kcal • ${dish.grams.round()} g',
                                                                          textAlign:
                                                                              TextAlign.left,
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            fontWeight:
                                                                                FontWeight.w400,
                                                                            color:
                                                                                AppColors.navy,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      GestureDetector(
                                                                        onTap:
                                                                            isRemoving
                                                                            ? null
                                                                            : () => _removeAddedDishWithAnimation(
                                                                                dish.id,
                                                                              ),
                                                                        behavior:
                                                                            HitTestBehavior.opaque,
                                                                        child: Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            left:
                                                                                10,
                                                                          ),
                                                                          child: Icon(
                                                                            Icons.delete_outline_rounded,
                                                                            size:
                                                                                21,
                                                                            color: AppColors.navy.withOpacity(
                                                                              isRemoving
                                                                                  ? 0.35
                                                                                  : 0.72,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  if (!isLast)
                                                                    Padding(
                                                                      padding:
                                                                          const EdgeInsets.only(
                                                                            top:
                                                                                9,
                                                                          ),
                                                                      child: Container(
                                                                        width: double
                                                                            .infinity,
                                                                        height:
                                                                            0.8,
                                                                        color: Colors
                                                                            .grey
                                                                            .shade300
                                                                            .withOpacity(
                                                                              0.55,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      })
                                                      .toList(growable: false),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('collapsed_top_controls_hidden'),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  final nextExtent = notification.extent;
                  if ((nextExtent - _sheetExtent).abs() > 0.001) {
                    setState(() {
                      _sheetExtent = nextExtent;
                    });
                  }
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  snap: true,
                  snapSizes: const [_sheetMinSize, _sheetMaxSize],
                  initialChildSize: _sheetMaxSize,
                  minChildSize: _sheetMinSize,
                  maxChildSize: _sheetMaxSize,
                  builder: (context, scrollController) {
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildActionItem(
                                      index: 0,
                                      icon: Icons.search_rounded,
                                      label: 'Search',
                                    ),
                                    const SizedBox(width: 4),
                                    _buildActionItem(
                                      index: 1,
                                      icon: Icons.auto_awesome_outlined,
                                      label: 'Quick Add',
                                    ),
                                    const SizedBox(width: 4),
                                    _buildActionItem(
                                      index: 2,
                                      icon: Icons.ramen_dining_rounded,
                                      label: 'My foods',
                                    ),
                                    const SizedBox(width: 4),
                                    _buildActionItem(
                                      index: 3,
                                      icon: Icons.camera_alt_outlined,
                                      label: 'Photo',
                                    ),
                                    const SizedBox(width: 4),
                                    _buildActionItem(
                                      index: 4,
                                      icon: Icons.qr_code_scanner_rounded,
                                      label: 'Barcode',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_selectedActionIndex == 0)
                                FoodSearchPanel(
                                  dailyCalorieTarget: widget.dailyCalorieTarget,
                                  dailyProteinTarget: widget.dailyProteinTarget,
                                  dailyFatTarget: widget.dailyFatTarget,
                                  dailyCarbsTarget: widget.dailyCarbsTarget,
                                  onNutrientsAdded: (nutrients) {
                                    unawaited(
                                      _registerNutrientsAddition(nutrients),
                                    );
                                  },
                                )
                              else if (_selectedActionIndex == 1)
                                QuickAddScreen(
                                  mealType: widget.mealType ?? 'snack',
                                  onNutrientsAdded: (nutrients) {
                                    unawaited(
                                      _registerNutrientsAddition(nutrients),
                                    );
                                  },
                                )
                              else if (_selectedActionIndex == 2)
                                MyFoodScreenPanel(
                                  onAddMeal: (meal) {
                                    unawaited(
                                      _registerPreviousMealAddition(meal),
                                    );
                                  },
                                )
                              else if (_selectedActionIndex == 4)
                                BarcodeScanPanel(
                                  onNutrientsAdded: (nutrients) {
                                    unawaited(
                                      _registerNutrientsAddition(nutrients),
                                    );
                                  },
                                )
                              else if (_selectedActionIndex == 3)
                                PhotoAnalyzePanel(
                                  mealType: widget.mealType ?? 'snack',
                                  onNutrientsAdded: (nutrients) {
                                    unawaited(
                                      _registerNutrientsAddition(nutrients),
                                    );
                                  },
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.babyBlueLight,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.lightBlue.withOpacity(
                                        0.75,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Choose Search to find foods from USDA FoodData Central.',
                                    style: TextStyle(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddedDishEntry {
  final int id;
  final String name;
  final double calories;
  final double grams;
  final double protein;
  final double fat;
  final double carbs;
  final List<String> ingredients;
  final List<String> possibleAllergens;

  const _AddedDishEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.grams,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.ingredients = const [],
    this.possibleAllergens = const [],
  });
}

class _MealMetricRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _MealMetricRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.width - strokeWidth) / 2;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MealMetricRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}