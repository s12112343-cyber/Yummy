import 'package:flutter/material.dart';

import '../../core/services/meal_service.dart';
import '../../core/theme/app_colors.dart';

class PreviousMealTemplate {
  final String id;
  final String mealName;
  final String mealType;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int grams;
  final int timesUsed;
  final DateTime lastUsed;

  const PreviousMealTemplate({
    required this.id,
    required this.mealName,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.grams,
    required this.timesUsed,
    required this.lastUsed,
  });

  factory PreviousMealTemplate.fromJson(Map<String, dynamic> json) {
    return PreviousMealTemplate(
      id: (json['id'] ?? '').toString(),
      mealName: (json['mealName'] ?? '').toString(),
      mealType: (json['mealType'] ?? 'snack').toString(),
      calories: (json['calories'] as num?)?.round() ?? 0,
      protein: (json['protein'] as num?)?.round() ?? 0,
      carbs: (json['carbs'] as num?)?.round() ?? 0,
      fat: (json['fat'] as num?)?.round() ?? 0,
      grams: (json['grams'] as num?)?.round() ?? 0,
      timesUsed: (json['timesUsed'] as num?)?.round() ?? 1,
      lastUsed: json['lastUsed'] != null
          ? DateTime.tryParse(json['lastUsed'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMealEntry() {
    return {
      'mealName': mealName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'grams': grams,
    };
  }
}

class MyFoodScreenPanel extends StatefulWidget {
  final ValueChanged<PreviousMealTemplate> onAddMeal;

  const MyFoodScreenPanel({super.key, required this.onAddMeal});

  @override
  State<MyFoodScreenPanel> createState() => _MyFoodScreenPanelState();
}

class _MyFoodScreenPanelState extends State<MyFoodScreenPanel> {
  final MealService _mealService = MealService();
  Future<List<PreviousMealTemplate>>? _loadFuture;
  String _selectedMealType = 'all';

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadPreviousMeals();
  }

  Future<List<PreviousMealTemplate>> _loadPreviousMeals() async {
    final response = await _mealService.getPreviousMeals(limit: 100);
    final items = (response['previousMeals'] as List<dynamic>? ?? const [])
        .map(
          (item) => PreviousMealTemplate.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    return items;
  }

  void _reload() {
    setState(() {
      _loadFuture = _loadPreviousMeals();
    });
  }

  List<PreviousMealTemplate> _filterMeals(List<PreviousMealTemplate> meals) {
    if (_selectedMealType == 'all') return meals;
    return meals.where((meal) => meal.mealType == _selectedMealType).toList();
  }

  String _mealTitle(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return 'Food';
    }
  }

  

  Color _mealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return AppColors.breakfastGradientEnd;
      case 'lunch':
        return AppColors.lunchGradientEnd;
      case 'dinner':
        return AppColors.dinnerGradientEnd;
      case 'snack':
        return AppColors.snackGradientEnd;
      default:
        return AppColors.navy;
    }
  }

  List<Color> _mealGradientColors(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return const [
          AppColors.breakfastGradientStart,
          AppColors.breakfastGradientEnd,
        ];
      case 'lunch':
        return const [AppColors.lunchGradientStart, AppColors.lunchGradientEnd];
      case 'dinner':
        return const [
          AppColors.dinnerGradientStart,
          AppColors.dinnerGradientEnd,
        ];
      case 'snack':
        return const [AppColors.snackGradientStart, AppColors.snackGradientEnd];
      default:
        return const [AppColors.lightBlue, AppColors.mediumBlue];
    }
  }

  Widget _buildFilterChip(String value, String label) {
    final bool isSelected = _selectedMealType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedMealType = value;
        });
      },
      selectedColor: AppColors.lightBlue.withOpacity(0.34),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.deepBlue : AppColors.navy,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.mediumBlue
            : AppColors.dark.withOpacity(0.08),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    );
  }

  Widget _buildMetricChip(String label, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }

  Widget _buildMealCard(PreviousMealTemplate meal) {
    final Color mealColor = _mealColor(meal.mealType);
    final List<Color> gradientColors = _mealGradientColors(meal.mealType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 52),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mealTitle(meal.mealType),
                        style: TextStyle(
                          fontSize: 12,
                          color: mealColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildMetricChip(
                            '${meal.calories} cal',
                            AppColors.caloriesPurple,
                          ),
                          _buildMetricChip(
                            'P ${meal.protein}g',
                            AppColors.proteinBlue,
                          ),
                          _buildMetricChip(
                            'C ${meal.carbs}g',
                            AppColors.carbsGreen,
                          ),
                          _buildMetricChip(
                            'F ${meal.fat}g',
                            AppColors.fatOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Used ${meal.timesUsed} time${meal.timesUsed == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => widget.onAddMeal(meal),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PreviousMealTemplate>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.deepBlue),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.babyBlueLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.lightBlue.withOpacity(0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to load previous foods',
                  style: TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final meals = _filterMeals(snapshot.data ?? const []);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('breakfast', 'Breakfast'),
                  const SizedBox(width: 8),
                  _buildFilterChip('lunch', 'Lunch'),
                  const SizedBox(width: 8),
                  _buildFilterChip('snack', 'Snack'),
                  const SizedBox(width: 8),
                  _buildFilterChip('dinner', 'Dinner'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (meals.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.babyBlueLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'No saved foods found yet.',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: meals.length,
                itemBuilder: (context, index) => _buildMealCard(meals[index]),
              ),
          ],
        );
      },
    );
  }
}
