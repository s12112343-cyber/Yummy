import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../api/edamam_api_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/meal_restrictions_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/back_button_widget.dart';
import 'food_search_panel.dart';

final EdamamApiService _edamamApiService = EdamamApiService();

final Map<String, List<UsdaFoodItem>> _edamamQueryCache =
    <String, List<UsdaFoodItem>>{};

String _cacheKeyForQuery(String query) {
  return query.trim().toLowerCase();
}

class FoodProductDetailsScreen extends StatefulWidget {
  final UsdaFoodItem item;
  final ValueChanged<double>? onCaloriesAdded;
  final ValueChanged<AddedNutrients>? onNutrientsAdded;
  final bool isIngredientMode;
  final int? dailyCalorieTarget;
  final int? dailyProteinTarget;
  final int? dailyFatTarget;
  final int? dailyCarbsTarget;

  const FoodProductDetailsScreen({
    super.key,
    required this.item,
    this.onCaloriesAdded,
    this.onNutrientsAdded,
    this.isIngredientMode = false,
    this.dailyCalorieTarget,
    this.dailyProteinTarget,
    this.dailyFatTarget,
    this.dailyCarbsTarget,
  });

  @override
  State<FoodProductDetailsScreen> createState() =>
      _FoodProductDetailsScreenState();
}

class _FoodProductDetailsScreenState extends State<FoodProductDetailsScreen> {
  int _selectedSection = 0; // 0: nutrition, 1: customize
  late final List<EditableIngredient> _ingredients;
  late final TextEditingController _portionGramsController;
  double _portionGrams = 100;
  String _portionLabel = '1 piece';
  String? _ingredientSearchErrorMessage;
  late FoodCategory _foodCategory;
  int _wholePortionCount = 1;
  double _fractionPortion = 0;
  String _selectedPortionUnit = 'piece';

  MealRestrictionProfile _restrictionProfile() {
    return MealRestrictionProfile.fromUser(context.read<UserProvider>().user);
  }

  Future<bool> _confirmMealAllowed({
    required String mealName,
    required List<String> ingredients,
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
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    if (!assessment.hasIssues) return true;

    final blockedIssues = assessment.issues
        .where((issue) => issue.severity == MealRestrictionSeverity.blocked)
        .toList(growable: false);

    if (blockedIssues.isEmpty) return true;

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

    final proceed = await showDialog<bool>(
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
                      onPressed: () => Navigator.of(dialogContext).pop(false),
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
                              side: const BorderSide(color: Color(0xFFD8DDE6)),
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
        );
      },
    );

    if (hasAllergyIssues) return false;
    return proceed == true;
  }

  Future<void> _handleAddPressed() async {
    final addedCalories = _totalCalories();
    final addedProtein = _totalProtein();
    final addedCarbs = _totalCarbs();
    final addedFat = _totalFat();
    final ingredients = _ingredients
        .map((ingredient) => ingredient.name.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final navigator = Navigator.of(context);

    final allowed = await _confirmMealAllowed(
      mealName: widget.item.name,
      ingredients: ingredients,
      calories: addedCalories,
      protein: addedProtein,
      carbs: addedCarbs,
      fat: addedFat,
    );

    if (!mounted || !allowed) return;

    if (!widget.isIngredientMode) {
      widget.onCaloriesAdded?.call(addedCalories);
    }
    widget.onNutrientsAdded?.call(
      AddedNutrients(
        calories: addedCalories,
        protein: addedProtein,
        carbs: addedCarbs,
        fat: addedFat,
        foodName: widget.item.name,
        gramsAdded: _portionGrams + _customIngredientsWeightTotal(),
        ingredients: ingredients,
        restrictionsChecked: true,
      ),
    );
    navigator.pop();
  }

  Map<String, double> get _nutritionTargets => {
    'Calories': (widget.dailyCalorieTarget ?? 2000).toDouble(),
    'Protein': (widget.dailyProteinTarget ?? 50).toDouble(),
    'Carbs': (widget.dailyCarbsTarget ?? 275).toDouble(),
    'Fat': (widget.dailyFatTarget ?? 78).toDouble(),
    'Fiber': 28,
    'Sugar': 50,
    'Sodium': 2300,
    'Vitamin C': 90,
    'Iron': 18,
    'Calcium': 1300,
  };

  @override
  void initState() {
    super.initState();
    _ingredients = _seedIngredients(widget.item.ingredients);
    _portionGramsController = TextEditingController(text: '100');

    // Classify the food and select initial unit
    _foodCategory = FoodCategoryClassifier.classify(
      widget.item.name,
      dataType: widget.item.dataType,
      brand: widget.item.brand,
      ingredients: widget.item.ingredients,
    );

    final availableUnits = FoodCategoryClassifier.getUnitsForFood(
      widget.item.name,
      dataType: widget.item.dataType,
      brand: widget.item.brand,
      ingredients: widget.item.ingredients,
    );

    _selectedPortionUnit = availableUnits.isNotEmpty
        ? availableUnits.first
        : 'piece';
    _recalculatePortionFromSelection();
  }

  @override
  void dispose() {
    _portionGramsController.dispose();
    super.dispose();
  }

  List<EditableIngredient> _seedIngredients(String? raw) {
    if (widget.item.ingredientItems.isNotEmpty) {
      return widget.item.ingredientItems
          .map(
            (item) => EditableIngredient(
              name: item.name,
              weight: item.weight == null
                  ? ''
                  : '${item.weight!.toStringAsFixed(0)} ${item.weightUnit}',
            ),
          )
          .toList(growable: true);
    }

    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((name) => EditableIngredient(name: name))
        .toList(growable: true);
  }

  String _grams(double value) => '${value.toStringAsFixed(0)} g';

  String _portionDisplayText() {
    return '${_portionReadableQuantity()} ${_portionUnitLabel(_selectedPortionUnit)} (${_portionGrams.toStringAsFixed(0)} g)';
  }

  String _portionMainText() {
    final perUnit = _portionUnitGramValue(_selectedPortionUnit);
    return '${_portionUnitLabel(_selectedPortionUnit)} (${perUnit.toStringAsFixed(0)} g)';
  }

  List<String> _wholeOptions() {
    return ['--', ...List<String>.generate(999, (i) => '${i + 1}')];
  }

  int _wholeIndexFromValue(int value) {
    if (value <= 0) return 0;
    if (value >= 999) return 999;
    return value;
  }

  int _wholeValueFromIndex(int index) {
    if (index <= 0) return 0;
    if (index >= 999) return 999;
    return index;
  }

  List<Map<String, dynamic>> _fractionOptions() {
    return const [
      {'label': '--', 'value': 0.0},
      {'label': '1/8', 'value': 0.125},
      {'label': '1/6', 'value': 1 / 6},
      {'label': '1/5', 'value': 0.2},
      {'label': '1/4', 'value': 0.25},
      {'label': '1/3', 'value': 1 / 3},
      {'label': '3/8', 'value': 0.375},
      {'label': '1/2', 'value': 0.5},
      {'label': '5/8', 'value': 0.625},
      {'label': '2/3', 'value': 2 / 3},
      {'label': '3/4', 'value': 0.75},
      {'label': '7/8', 'value': 0.875},
    ];
  }

  int _fractionIndexFromValue(double value) {
    final options = _fractionOptions();
    for (int i = 0; i < options.length; i++) {
      if (((options[i]['value'] as double) - value).abs() < 0.0001) {
        return i;
      }
    }
    return 0;
  }

  double _fractionValueFromIndex(int index) {
    final options = _fractionOptions();
    if (index < 0 || index >= options.length) return 0;
    return options[index]['value'] as double;
  }

  List<String> _unitOptions() {
    return FoodCategoryClassifier.getUnitsForFood(
      widget.item.name,
      dataType: widget.item.dataType,
      brand: widget.item.brand,
      ingredients: widget.item.ingredients,
    );
  }

  String _portionUnitLabel(String unit) {
    return FoodCategoryClassifier.getUnitLabel(unit);
  }

  double _portionUnitGramValue(String unit) {
    return FoodCategoryClassifier.getUnitGramValue(unit);
  }

  String _fractionLabel(double value) {
    if ((value - 0.0).abs() < 0.0001) return '--';
    if ((value - 0.125).abs() < 0.0001) return '1/8';
    if ((value - (1 / 6)).abs() < 0.0001) return '1/6';
    if ((value - 0.2).abs() < 0.0001) return '1/5';
    if ((value - 0.25).abs() < 0.0001) return '1/4';
    if ((value - (1 / 3)).abs() < 0.0001) return '1/3';
    if ((value - 0.375).abs() < 0.0001) return '3/8';
    if ((value - 0.5).abs() < 0.0001) return '1/2';
    if ((value - 0.625).abs() < 0.0001) return '5/8';
    if ((value - (2 / 3)).abs() < 0.0001) return '2/3';
    if ((value - 0.75).abs() < 0.0001) return '3/4';
    if ((value - 0.875).abs() < 0.0001) return '7/8';
    return '--';
  }

  String _portionReadableQuantity() {
    final fraction = _fractionLabel(_fractionPortion);
    if (_wholePortionCount == 0 && fraction == '--') return '--';
    if (_wholePortionCount == 0) return fraction;
    if (fraction == '--') return '$_wholePortionCount';
    return '$_wholePortionCount $fraction';
  }

  void _recalculatePortionFromSelection() {
    final quantity = _wholePortionCount + _fractionPortion;
    final grams = (_portionUnitGramValue(_selectedPortionUnit) * quantity)
        .clamp(1.0, 3000.0);

    _applyPortionGrams(grams, syncQuantityFromGrams: false);
  }

  void _applyPortionGrams(double grams, {required bool syncQuantityFromGrams}) {
    _portionGrams = grams.clamp(1.0, 3000.0);

    if (syncQuantityFromGrams) {
      _syncPortionQuantityFromGrams();
    }

    _portionLabel =
        '${_portionReadableQuantity()} ${_portionUnitLabel(_selectedPortionUnit)}';
    _portionGramsController.text = _portionGrams.toStringAsFixed(0);
  }

  void _syncPortionQuantityFromGrams() {
    final perUnit = _portionUnitGramValue(_selectedPortionUnit);
    if (perUnit <= 0) return;

    final quantity = (_portionGrams / perUnit).clamp(0.0, 999.875);
    _wholePortionCount = quantity.floor();

    final decimalPart = quantity - _wholePortionCount;
    final fractions = _fractionOptions()
        .map((item) => item['value'] as double)
        .toList(growable: false);

    double nearest = fractions.first;
    double bestDistance = (decimalPart - nearest).abs();
    for (final value in fractions) {
      final distance = (decimalPart - value).abs();
      if (distance < bestDistance) {
        nearest = value;
        bestDistance = distance;
      }
    }

    _fractionPortion = nearest;

    if (_wholePortionCount == 0 && _fractionPortion == 0) {
      _wholePortionCount = 1;
    }
  }

  double _ingredientsTotalWeight() {
    double total = 0;
    for (final ingredient in _ingredients) {
      final weight = _parseIngredientWeight(ingredient.weight);
      if (weight != null && weight > 0) {
        total += weight;
      }
    }
    return total;
  }

  void _updatePortionFromIngredientDelta(double deltaGrams) {
    if (deltaGrams == 0) return;
    final next = (_portionGrams + deltaGrams).clamp(1.0, 3000.0);
    _applyPortionGrams(next, syncQuantityFromGrams: true);
  }

  Future<void> _showPortionPicker() async {
    int draftWhole = _wholePortionCount;
    double draftFraction = _fractionPortion;
    String draftUnit = _selectedPortionUnit;

    final unitOptions = _unitOptions();

    if (!unitOptions.contains(draftUnit)) {
      draftUnit = unitOptions.first;
    }

    // Initialize controllers once (outside builder) for smooth scrolling
    final wholeController = FixedExtentScrollController(
      initialItem: _wholeIndexFromValue(draftWhole),
    );
    final fractionController = FixedExtentScrollController(
      initialItem: _fractionIndexFromValue(draftFraction),
    );
    final unitController = FixedExtentScrollController(
      initialItem: unitOptions.indexOf(draftUnit),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2D7E0),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Big rounded "Add this food" button + Wheel picker area
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Wheel picker with 3 columns
                      SizedBox(
                        height: 200,
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                // Whole number column
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: wholeController,
                                    itemExtent: 38,
                                    magnification: 1.0,
                                    useMagnifier: false,
                                    onSelectedItemChanged: (index) {
                                      setSheetState(() {
                                        draftWhole = _wholeValueFromIndex(
                                          index,
                                        );
                                      });
                                    },
                                    children: _wholeOptions()
                                        .map(
                                          (item) => Center(
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.navy,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Fraction column
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: fractionController,
                                    itemExtent: 38,
                                    magnification: 1.0,
                                    useMagnifier: false,
                                    onSelectedItemChanged: (index) {
                                      setSheetState(() {
                                        draftFraction = _fractionValueFromIndex(
                                          index,
                                        );
                                      });
                                    },
                                    children: _fractionOptions()
                                        .map(
                                          (item) => Center(
                                            child: Text(
                                              item['label'] as String,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.navy,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Unit column
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: unitController,
                                    itemExtent: 38,
                                    magnification: 1.0,
                                    useMagnifier: false,
                                    onSelectedItemChanged: (index) {
                                      setSheetState(() {
                                        draftUnit = unitOptions[index];
                                      });
                                    },
                                    children: unitOptions
                                        .map(
                                          (unit) => Center(
                                            child: Text(
                                              _portionUnitLabel(unit),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.navy,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                            // Soft light blue center selection band overlay
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Container(
                                    height: 46,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightBlue.withOpacity(
                                        0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Button positioned on top of picker
                      Positioned(
                        top: -18,
                        left: 16,
                        right: 16,
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _wholePortionCount = draftWhole;
                                _fractionPortion = draftFraction;
                                _selectedPortionUnit = draftUnit;
                                _recalculatePortionFromSelection();
                              });
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text(
                              'Add this food',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double _recipeWeightGrams() {
    final value = widget.item.weight;
    if (value == null || value <= 0) return 100;
    return value;
  }

  double _portionFactor() {
    final recipeWeight = _recipeWeightGrams();
    if (recipeWeight <= 0) return 1;
    return _portionGrams / recipeWeight;
  }

  double _scaledValue(double totalValue) {
    return totalValue * _portionFactor();
  }

  double _per100gFromItemValue(UsdaFoodItem item, double totalValue) {
    final recipeWeight = item.weight;
    if (recipeWeight == null || recipeWeight <= 0) return totalValue;
    return totalValue / recipeWeight * 100;
  }

  double _customIngredientsNutrientTotal(
    double Function(EditableIngredient ingredient) getter,
  ) {
    double total = 0;
    for (final ingredient in _ingredients) {
      if (!ingredient.isCustomAddition) continue;
      final weight = _parseIngredientWeight(ingredient.weight) ?? 0;
      if (weight <= 0) continue;
      final nutrientPer100g = getter(ingredient);
      total += nutrientPer100g * (weight / 100);
    }
    return total;
  }

  double _customIngredientsWeightTotal() {
    double total = 0;
    for (final ingredient in _ingredients) {
      if (!ingredient.isCustomAddition) continue;
      final weight = _parseIngredientWeight(ingredient.weight) ?? 0;
      if (weight <= 0) continue;
      total += weight;
    }
    return total;
  }

  double _totalCalories() {
    return _scaledValue(widget.item.calories) +
        _customIngredientsNutrientTotal((ingredient) => ingredient.calories);
  }

  double _totalProtein() {
    return _scaledValue(widget.item.protein) +
        _customIngredientsNutrientTotal((ingredient) => ingredient.protein);
  }

  double _totalCarbs() {
    return _scaledValue(widget.item.carbs) +
        _customIngredientsNutrientTotal((ingredient) => ingredient.carbs);
  }

  double _totalFat() {
    return _scaledValue(widget.item.fat) +
        _customIngredientsNutrientTotal((ingredient) => ingredient.fat);
  }

  void _updatePortionGrams(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(normalized);
    final parsed = match == null ? null : double.tryParse(match.group(0)!);

    if (parsed == null || parsed <= 0) return;

    setState(() {
      _portionGrams = parsed;
    });
  }

  String _weightText(UsdaFoodItem item) {
    final value = item.weight;
    if (value == null || value <= 0) return 'N/A';
    final unit = (item.weightUnit ?? '').trim();
    if (unit.isEmpty) return '${value.toStringAsFixed(0)} g';
    return '${value.toStringAsFixed(0)} $unit';
  }

  Widget _macroChip(String title, String value, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$title: $value',
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _nutritionBar({
    required String label,
    required double value,
    required String unit,
    required double target,
    required Color barColor,
    required Color trackColor,
  }) {
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  color: AppColors.navy.withOpacity(0.72),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: trackColor,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: barColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$percentage% of daily need covered',
            style: TextStyle(
              color: AppColors.navy.withOpacity(0.58),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  double _findNutrientValue(String keyword) {
    for (final nutrient in widget.item.nutrients) {
      final name = nutrient.name.toLowerCase();
      if (name.contains(keyword.toLowerCase())) {
        return _scaledValue(nutrient.value);
      }
    }
    return 0;
  }

  double? _parseIngredientWeight(String rawWeight) {
    final normalized = rawWeight.trim().replaceAll(',', '.');
    final match = RegExp(r'\d+(\.\d+)?').firstMatch(normalized);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }

  String _formatIngredientWeight(String rawWeight) {
    if (rawWeight.trim().isEmpty) return 'Weight: N/A';

    // إذا كان الوزن يحتوي على وحدة بالفعل (مثل "123 g")
    if (rawWeight.contains(RegExp(r'[a-zA-Z]'))) {
      return 'Weight: $rawWeight';
    }

    // وإلا، parse الرقم وأضف الوحدة
    final parsed = _parseIngredientWeight(rawWeight);
    if (parsed == null || parsed <= 0) return 'Weight: N/A';
    return 'Weight: ${parsed.toStringAsFixed(0)} g';
  }

  String _formatIngredientWeightShort(String rawWeight) {
    final parsed = _parseIngredientWeight(rawWeight);
    if (parsed == null || parsed <= 0) return 'N/A';
    return '${parsed.toStringAsFixed(0)} g';
  }

  double _ingredientCalories(EditableIngredient ingredient) {
    final ingredientWeight = _parseIngredientWeight(ingredient.weight);
    if (ingredientWeight == null || ingredientWeight <= 0) return 0;

    if (ingredient.isCustomAddition) {
      return ingredient.calories * (ingredientWeight / 100);
    }

    final recipeWeight = _recipeWeightGrams();
    if (recipeWeight <= 0) return 0;

    final share = ingredientWeight / recipeWeight;
    return widget.item.calories * share * _portionFactor();
  }

  String _totalCustomizeWeightText() {
    final totalWeight = _portionGrams + _customIngredientsWeightTotal();
    return '${totalWeight.toStringAsFixed(0)} g';
  }

  Widget _buildSinglePortionSelector() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _showPortionPicker,
        child: Container(
          height: 52,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.lightBlue.withOpacity(0.75)),
            boxShadow: [
              BoxShadow(
                color: AppColors.lightBlue.withOpacity(0.28),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Center(
                  child: Text(
                    _portionReadableQuantity(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: AppColors.lightBlue.withOpacity(0.45),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _portionMainText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy.withOpacity(0.86),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.navy.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImageHeader() {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = (screenHeight * 0.36).clamp(260.0, 380.0);

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.item.imageUrl != null)
            Image.network(
              widget.item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.navy,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            )
          else
            Container(
              color: AppColors.navy,
              alignment: Alignment.center,
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          Container(color: Colors.black.withOpacity(0.24)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppBackButton(
                    backgroundColor: AppColors.white,
                    showBorder: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<UsdaFoodItem>> _searchIngredientsFromApi(String query) async {
    final key = _cacheKeyForQuery(query);

    final remainingLimit = _edamamApiService.remainingRateLimitDuration();
    if (remainingLimit > Duration.zero) {
      _ingredientSearchErrorMessage =
          'Rate limit reached. Please wait ${remainingLimit.inSeconds}s and try again.';
      return const [];
    }

    final cached = _edamamQueryCache[key];
    if (cached != null) {
      _ingredientSearchErrorMessage = null;
      return cached;
    }

    final trimmed = query.trim();
    if (trimmed.length < 2 || !_edamamApiService.hasCredentials) {
      return const [];
    }

    final result = await _edamamApiService.searchRecipes(trimmed);
    if (!result.isSuccess) {
      _ingredientSearchErrorMessage = result.errorMessage;
      return const [];
    }

    try {
      final parsed = result.hits
          .map(UsdaFoodItem.fromApi)
          .toList(growable: false);

      _edamamQueryCache[key] = parsed;
      _ingredientSearchErrorMessage = null;
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _showAddIngredientDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: FoodSearchPanel(
            isIngredientMode: true,
            onClose: () => Navigator.of(context).pop(),
            onIngredientPortionSelected: (selectedItem, grams) {
              setState(() {
                final addedWeight = grams.clamp(1, 3000).toDouble();
                final weightDisplay = '${addedWeight.toStringAsFixed(0)} g';

                _ingredients.add(
                  EditableIngredient(
                    name: selectedItem.name,
                    weight: weightDisplay,
                    calories: _per100gFromItemValue(
                      selectedItem,
                      selectedItem.calories,
                    ),
                    protein: _per100gFromItemValue(
                      selectedItem,
                      selectedItem.protein,
                    ),
                    fat: _per100gFromItemValue(selectedItem, selectedItem.fat),
                    carbs: _per100gFromItemValue(
                      selectedItem,
                      selectedItem.carbs,
                    ),
                    isCustomAddition: true,
                  ),
                );
              });

              Navigator.of(context).pop();
            },
            onIngredientSelected: (selectedItem) {
              setState(() {
                const String weightDisplay = '100 g';

                _ingredients.add(
                  EditableIngredient(
                    name: selectedItem.name,
                    weight: weightDisplay,
                    calories: _per100gFromItemValue(
                      selectedItem,
                      selectedItem.calories,
                    ),
                    protein: _per100gFromItemValue(
                      selectedItem,
                      selectedItem.protein,
                    ),
                    fat: _per100gFromItemValue(selectedItem, selectedItem.fat),
                    carbs: _per100gFromItemValue(
                      selectedItem,
                      selectedItem.carbs,
                    ),
                    isCustomAddition: true,
                  ),
                );
              });

              // أغلق البوتوم شيت بعد الإضافة
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  Widget _nutritionGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.deepBlue,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildNutritionSection() {
    final calories = _totalCalories();
    final protein = _totalProtein();
    final carbs = _totalCarbs();
    final fat = _totalFat();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutritional facts',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        _nutritionBar(
          label: 'Calories',
          value: calories,
          unit: 'kcal',
          target: _nutritionTargets['Calories'] ?? 2000,
          barColor: AppColors.calorieRingGradientStart,
          trackColor: AppColors.caloriesBg,
        ),
        _nutritionBar(
          label: 'Fat',
          value: fat,
          unit: 'g',
          target: _nutritionTargets['Fat'] ?? 78,
          barColor: AppColors.macroFat,
          trackColor: AppColors.fatBg,
        ),
        _nutritionBar(
          label: 'Protein',
          value: protein,
          unit: 'g',
          target: _nutritionTargets['Protein'] ?? 50,
          barColor: AppColors.macroProtein,
          trackColor: AppColors.proteinBg,
        ),
        _nutritionBar(
          label: 'Carbs',
          value: carbs,
          unit: 'g',
          target: _nutritionTargets['Carbs'] ?? 275,
          barColor: AppColors.macroCarbs,
          trackColor: AppColors.carbsBg,
        ),
      ],
    );
  }

  Widget _buildCustomizeSection() {
    final baseWeight = _portionGrams;
    final addedIngredientsWeight = _customIngredientsWeightTotal();
    final totalWeight = baseWeight + addedIngredientsWeight;
    final calories = _totalCalories();
    final protein = _totalProtein();
    final carbs = _totalCarbs();
    final fat = _totalFat();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consumed amount: ${_totalCustomizeWeightText()}',
          style: const TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Base ${baseWeight.toStringAsFixed(0)} g + Ingredients ${addedIngredientsWeight.toStringAsFixed(0)} g = ${totalWeight.toStringAsFixed(0)} g.',
          style: TextStyle(
            color: AppColors.navy.withOpacity(0.58),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _macroChip(
              'Calories',
              '${calories.toStringAsFixed(0)} kcal',
              AppColors.caloriesBg,
            ),
            _macroChip(
              'Protein',
              '${protein.toStringAsFixed(1)} g',
              AppColors.proteinBg,
            ),
            _macroChip(
              'Carbs',
              '${carbs.toStringAsFixed(1)} g',
              AppColors.carbsBg,
            ),
            _macroChip('Fat', '${fat.toStringAsFixed(1)} g', AppColors.fatBg),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Ingredients',
          style: TextStyle(
            color: AppColors.navy.withOpacity(0.85),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (_ingredients.isEmpty)
          Text(
            'No ingredients yet.',
            style: TextStyle(
              color: AppColors.navy.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            ),
          )
        else
          ..._ingredients.asMap().entries.map((entry) {
            final index = entry.key;
            final ingredient = entry.value;
            final ingredientCalories = _ingredientCalories(ingredient);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.lightBlue.withOpacity(0.30),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: const TextStyle(
                            color: AppColors.deepBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ingredientCalories.toStringAsFixed(0)} Cal • ${_formatIngredientWeightShort(ingredient.weight)}',
                          style: TextStyle(
                            color: AppColors.navy.withOpacity(0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        final removedWeight = _parseIngredientWeight(
                          ingredient.weight,
                        );
                        _ingredients.removeAt(index);

                        if (!ingredient.isCustomAddition &&
                            removedWeight != null &&
                            removedWeight > 0) {
                          _updatePortionFromIngredientDelta(-removedWeight);
                        } else if (!ingredient.isCustomAddition) {
                          final totalWeight = _ingredientsTotalWeight();
                          if (totalWeight > 0) {
                            _applyPortionGrams(
                              totalWeight,
                              syncQuantityFromGrams: true,
                            );
                          }
                        }
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.red,
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _showAddIngredientDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add ingredients'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionOption({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.deepBlue : AppColors.navy,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selected ? 56 : 28,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.deepBlue
                      : AppColors.lightBlue.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _handleAddPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.isIngredientMode ? 'Add ingredient' : 'Add this food',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroImageHeader(),
                  Transform.translate(
                    offset: const Offset(0, -80),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.deepBlue,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: AppColors.deepBlue,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _totalCalories().toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' Cal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              'Consumed: ${_totalCustomizeWeightText()}',
                              style: const TextStyle(
                                color: AppColors.deepBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSinglePortionSelector(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildSectionOption(
                                selected: _selectedSection == 0,
                                label: 'Nutrition',
                                onTap: () =>
                                    setState(() => _selectedSection = 0),
                              ),
                              const SizedBox(width: 8),
                              _buildSectionOption(
                                selected: _selectedSection == 1,
                                label: 'Customize',
                                onTap: () =>
                                    setState(() => _selectedSection = 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _selectedSection == 0
                                ? _buildNutritionSection()
                                : _buildCustomizeSection(),
                          ),
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
