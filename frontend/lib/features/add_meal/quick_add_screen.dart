import 'package:flutter/material.dart';

import '../../core/services/meal_service.dart';
import '../../core/theme/app_colors.dart';
import 'food_search_panel.dart';

class QuickAddScreen extends StatefulWidget {
  final String mealType;
  final ValueChanged<AddedNutrients> onNutrientsAdded;

  const QuickAddScreen({
    super.key,
    required this.mealType,
    required this.onNutrientsAdded,
  });

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  final MealService _mealService = MealService();
  final TextEditingController _textController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;
  Map<String, dynamic>? _analysis;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorText = 'Please enter a food description.';
        _analysis = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await _mealService.analyzeQuickAddText(
        text: text,
        mealType: widget.mealType,
      );

      if (!mounted) return;
      setState(() {
        _analysis = response;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analysis = null;
        _errorText = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addToMeal() {
    final result = _analysis;
    if (result == null) return;

    final calories = (result['calories'] as num?)?.toDouble() ?? 0;
    final protein = (result['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (result['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (result['fat'] as num?)?.toDouble() ?? 0;
    final grams = (result['grams'] as num?)?.toDouble() ?? 0;
    final explicitGrams = (result['explicitGrams'] as num?)?.toDouble() ?? 0;
    final weightSource = (result['weightSource'] ?? 'api').toString();
    final mealName = (result['mealName'] ?? '').toString().trim();
    final ingredients = (result['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => (item['name'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    widget.onNutrientsAdded(
      AddedNutrients(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        foodName: mealName.isEmpty ? 'Quick add item' : mealName,
        gramsAdded: weightSource == 'input'
            ? (explicitGrams > 0 ? explicitGrams : grams)
            : (grams > 0 ? grams : 100),
        ingredients: ingredients,
      ),
    );

    setState(() {
      _analysis = null;
      _textController.clear();
    });
  }

  Widget _macroChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$title $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatQuantity(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  Widget _buildItemsSummary(List<dynamic> rawItems) {
    final items = rawItems.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.babyBlueLight.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quick summary',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...items.take(6).map((item) {
            final name = (item['name'] ?? 'Food item').toString();
            final quantity = (item['quantity'] as num?) ?? 1;
            final unit = (item['unit'] ?? 'serving').toString();
            final grams = (item['grams'] as num?)?.toDouble() ?? 0;
            final calories = (item['calories'] as num?)?.toDouble() ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '- $name: ${_formatQuantity(quantity)} $unit, ${grams.toStringAsFixed(0)} g, ${calories.toStringAsFixed(0)} cal',
                style: TextStyle(
                  color: AppColors.navy.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
          if (items.length > 6)
            Text(
              '+ ${items.length - 6} more items',
              style: TextStyle(
                color: AppColors.navy.withOpacity(0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final mealName = (analysis?['mealName'] ?? '').toString();
    final calories = (analysis?['calories'] as num?)?.toDouble() ?? 0;
    final protein = (analysis?['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (analysis?['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (analysis?['fat'] as num?)?.toDouble() ?? 0;
    final grams = (analysis?['grams'] as num?)?.toDouble() ?? 0;
    final explicitGrams = (analysis?['explicitGrams'] as num?)?.toDouble() ?? 0;
    final weightSource = (analysis?['weightSource'] ?? 'api').toString();
    final displayGrams = explicitGrams > 0 ? explicitGrams : grams;
    final rawItems =
        (analysis?['items'] as List<dynamic>?) ?? const <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightBlue.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Quick Add',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Write your meal or recipe with quantity to get calories and macros ',
                style: TextStyle(
                  color: AppColors.navy.withOpacity(0.75),
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _textController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'discribe what you eat',
                  fillColor: AppColors.babyBlueLight,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.lightBlue.withOpacity(0.65),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.mediumBlue,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Analyze',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3CEC8)),
            ),
            child: Text(
              _errorText!,
              style: const TextStyle(
                color: Color(0xFFB33C2E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (analysis != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBlue.withOpacity(0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mealName.isEmpty ? 'Analyzed meal' : mealName,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _macroChip(
                      'Cal',
                      calories.toStringAsFixed(0),
                      AppColors.caloriesPurple,
                    ),
                    _macroChip(
                      'P',
                      '${protein.toStringAsFixed(1)}g',
                      AppColors.proteinBlue,
                    ),
                    _macroChip(
                      'C',
                      '${carbs.toStringAsFixed(1)}g',
                      AppColors.carbsGreen,
                    ),
                    _macroChip(
                      'F',
                      '${fat.toStringAsFixed(1)}g',
                      AppColors.fatOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  weightSource == 'input' && displayGrams > 0
                      ? 'Input weight: ${displayGrams.toStringAsFixed(0)} g'
                      : 'Estimated weight: ${grams.toStringAsFixed(0)} g',
                  style: TextStyle(
                    color: AppColors.navy.withOpacity(0.78),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                _buildItemsSummary(rawItems),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _addToMeal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mediumBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Add to meal',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
