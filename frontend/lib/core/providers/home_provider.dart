import 'package:flutter/material.dart';

import '../services/meal_service.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({MealService? mealService})
    : _mealService = mealService ?? MealService();

  final MealService _mealService;

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime? _lastSummaryDate;

  int _dailyCalories = 0;
  int _dailyProtein = 0;
  int _dailyFat = 0;
  int _dailyCarbs = 0;

  int _consumedCalories = 0;
  int _consumedProtein = 0;
  int _consumedFat = 0;
  int _consumedCarbs = 0;

  Map<String, int> _mealConsumedCalories = {
    'breakfast': 0,
    'lunch': 0,
    'snack': 0,
    'dinner': 0,
  };

  Map<String, String> _mealNames = {
    'breakfast': '',
    'lunch': '',
    'snack': '',
    'dinner': '',
  };

  double _dailyWaterGoalL = 3.5;
  int _consumedWaterMl = 0;
  DateTime? _lastDrinkTime;

  DateTime get selectedDate => _selectedDate;
  DateTime? get lastSummaryDate => _lastSummaryDate;

  int get dailyCalories => _dailyCalories;
  int get dailyProtein => _dailyProtein;
  int get dailyFat => _dailyFat;
  int get dailyCarbs => _dailyCarbs;

  int get consumedCalories => _consumedCalories;
  int get consumedProtein => _consumedProtein;
  int get consumedFat => _consumedFat;
  int get consumedCarbs => _consumedCarbs;

  Map<String, int> get mealConsumedCalories =>
      Map<String, int>.from(_mealConsumedCalories);
  Map<String, String> get mealNames => Map<String, String>.from(_mealNames);

  double get dailyWaterGoalL => _dailyWaterGoalL;
  int get consumedWaterMl => _consumedWaterMl;
  DateTime? get lastDrinkTime => _lastDrinkTime;

  int get dailyWaterGoalMl => (_dailyWaterGoalL * 1000).round();

  void setDailyWaterGoalLiters(double value) {
    if (!value.isFinite || value <= 0) return;
    _dailyWaterGoalL = value;
    notifyListeners();
    _persistDailyWater();
  }

  void setSelectedDate(DateTime value) {
    _selectedDate = DateUtils.dateOnly(value);
    notifyListeners();
  }

  void setDailyTargets({
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
  }) {
    _dailyCalories = calories;
    _dailyProtein = protein;
    _dailyFat = fat;
    _dailyCarbs = carbs;
    notifyListeners();
  }

  void addConsumedMacros({
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
  }) {
    _consumedCalories += calories;
    _consumedProtein += protein;
    _consumedFat += fat;
    _consumedCarbs += carbs;
    notifyListeners();
  }

  Future<void> fetchDailyMealSummary({DateTime? date}) async {
    final targetDate = DateUtils.dateOnly(date ?? _selectedDate);

    try {
      final data = await _mealService.getDailySummary(targetDate);
      final summary = (data['summary'] as Map<String, dynamic>? ?? {});
      final mealConsumed =
          (data['mealConsumedCalories'] as Map<String, dynamic>? ?? {});
      final mealNames = (data['mealNames'] as Map<String, dynamic>? ?? {});
      final water = (data['water'] as Map<String, dynamic>? ?? {});

      _consumedCalories = (summary['calories'] as num?)?.round() ?? 0;
      _consumedProtein = (summary['protein'] as num?)?.round() ?? 0;
      _consumedCarbs = (summary['carbs'] as num?)?.round() ?? 0;
      _consumedFat = (summary['fat'] as num?)?.round() ?? 0;

      _mealConsumedCalories = {
        'breakfast': (mealConsumed['breakfast'] as num?)?.round() ?? 0,
        'lunch': (mealConsumed['lunch'] as num?)?.round() ?? 0,
        'snack': (mealConsumed['snack'] as num?)?.round() ?? 0,
        'dinner': (mealConsumed['dinner'] as num?)?.round() ?? 0,
      };

      _mealNames = {
        'breakfast': (mealNames['breakfast'] ?? '').toString(),
        'lunch': (mealNames['lunch'] ?? '').toString(),
        'snack': (mealNames['snack'] ?? '').toString(),
        'dinner': (mealNames['dinner'] ?? '').toString(),
      };

      _consumedWaterMl = (water['consumedWaterMl'] as num?)?.round() ?? 0;
      final storedGoalMl = (water['dailyWaterGoalMl'] as num?)?.round();
      if (storedGoalMl != null && storedGoalMl > 0) {
        _dailyWaterGoalL = storedGoalMl / 1000.0;
      }
      final rawLastDrink = water['lastDrinkTime'];
      _lastDrinkTime = rawLastDrink == null
          ? null
          : DateTime.tryParse(rawLastDrink.toString())?.toLocal();

      _lastSummaryDate = targetDate;
    } catch (_) {
      // Keep previous state on transient failures.
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> saveMealEntries({
    required String mealType,
    required DateTime date,
    required List<Map<String, dynamic>> meals,
  }) async {
    final response = await _mealService.addMealsBatch(
      mealType: mealType,
      date: DateUtils.dateOnly(date),
      meals: meals,
    );

    await fetchDailyMealSummary(date: date);
    return response;
  }

  void addWaterBy(int amountMl) {
    if (amountMl <= 0) return;
    _consumedWaterMl += amountMl;
    _lastDrinkTime = DateTime.now();
    notifyListeners();
    _persistDailyWater();
  }

  void decrementWaterBy(int amountMl) {
    if (amountMl <= 0) return;
    _consumedWaterMl = (_consumedWaterMl - amountMl).clamp(0, 999999);
    if (_consumedWaterMl == 0) {
      _lastDrinkTime = null;
    }
    notifyListeners();
    _persistDailyWater();
  }

  Future<void> _persistDailyWater() async {
    try {
      await _mealService.updateDailyWater(
        date: _selectedDate,
        consumedWaterMl: _consumedWaterMl,
        dailyWaterGoalMl: dailyWaterGoalMl,
        lastDrinkTime: _lastDrinkTime,
      );
    } catch (_) {
      // Keep local state even if network call fails.
    }
  }
}
