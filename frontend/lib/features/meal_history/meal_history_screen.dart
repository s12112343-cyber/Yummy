import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/meal_service.dart';
import '../../core/theme/app_colors.dart';

enum _PeriodOption { today, week, month, all, custom }

extension _PeriodOptionX on _PeriodOption {
  String get apiValue {
    switch (this) {
      case _PeriodOption.today:
        return 'today';
      case _PeriodOption.week:
        return 'week';
      case _PeriodOption.month:
        return 'month';
      case _PeriodOption.all:
        return 'all';
      case _PeriodOption.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case _PeriodOption.today:
        return 'Today';
      case _PeriodOption.week:
        return 'Week';
      case _PeriodOption.month:
        return 'Month';
      case _PeriodOption.all:
        return 'All';
      case _PeriodOption.custom:
        return 'Custom';
    }
  }
}

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  final MealService _mealService = MealService();
  final DateFormat _dateFormat = DateFormat('d/M');

  _PeriodOption _selectedPeriod = _PeriodOption.week;
  DateTime? _customDate;
  Future<_PeriodSummaryData>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadSummary();
  }

  Future<_PeriodSummaryData> _loadSummary() async {
    if (_selectedPeriod == _PeriodOption.today) {
      final response = await _mealService.getDailySummary(DateTime.now());
      return _PeriodSummaryData.fromDailyJson(response);
    }

    if (_selectedPeriod == _PeriodOption.custom) {
      final date = _customDate ?? DateTime.now();
      final response = await _mealService.getDailySummary(date);
      return _PeriodSummaryData.fromDailyJson(response);
    }

    final response = await _mealService.getPeriodSummary(
      period: _selectedPeriod.apiValue,
    );
    return _PeriodSummaryData.fromPeriodJson(response);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _loadSummary();
    });
    await _loadFuture;
  }

  void _selectPeriod(_PeriodOption period) {
    if (_selectedPeriod == period) return;

    setState(() {
      _selectedPeriod = period;
      _loadFuture = _loadSummary();
    });
  }

  String _formatDateKey(String dateKey) {
    final parsed = DateTime.tryParse('$dateKey 00:00:00');
    if (parsed == null) return dateKey;
    return _dateFormat.format(parsed.toLocal());
  }

  String _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) {
      return raw;
    }

    final authority = baseUri.hasPort
        ? '${baseUri.host}:${baseUri.port}'
        : baseUri.host;
    final origin = '${baseUri.scheme}://$authority';

    if (raw.startsWith('/')) {
      return '$origin$raw';
    }

    return '$origin/$raw';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.deepBlue,
        ),
        title: const Text(
          'Meal History',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.deepBlue,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.deepBlue,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _UserOverviewCard(user: user, resolveImageUrl: _resolveImageUrl),
            const SizedBox(height: 16),
            _PeriodSelector(
              selectedPeriod: _selectedPeriod,
              onChanged: _selectPeriod,
              customDate: _customDate,
              onCalendarTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _customDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _customDate = DateUtils.dateOnly(picked);
                    _selectedPeriod = _PeriodOption.custom;
                    _loadFuture = _loadSummary();
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            FutureBuilder<_PeriodSummaryData>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const _LoadingState();
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final data = snapshot.data ?? const _PeriodSummaryData.empty();

                return Column(
                  children: [
                    _OverviewStatsGrid(data: data),
                    const SizedBox(height: 16),
                    _MacroRingCard(data: data),
                    const SizedBox(height: 16),
                    _WaterChartCard(data: data, formatDateKey: _formatDateKey),
                    const SizedBox(height: 16),
                    _MealItemsCard(data: data),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummaryData {
  final String period;
  final String label;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int waterConsumedMl;
  final int mealCount;
  final int daysWithMeals;
  final int daysWithWater;
  final double averageCaloriesPerDay;
  final double averageWaterPerDay;
  final int dailyWaterGoalMl;
  final Map<String, int> mealTypeCounts;
  final Map<String, int> mealTypeCalories;
  final Map<String, double> macroPercentages;
  final List<_WaterPoint> waterSeries;
  final List<_MealItem> mealItems;

  const _PeriodSummaryData({
    required this.period,
    required this.label,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.waterConsumedMl,
    required this.mealCount,
    required this.daysWithMeals,
    required this.daysWithWater,
    required this.averageCaloriesPerDay,
    required this.averageWaterPerDay,
    required this.dailyWaterGoalMl,
    required this.mealTypeCounts,
    required this.mealTypeCalories,
    required this.macroPercentages,
    required this.waterSeries,
    required this.mealItems,
  });

  const _PeriodSummaryData.empty()
    : period = 'week',
      label = 'Last 7 days',
      calories = 0,
      protein = 0,
      carbs = 0,
      fat = 0,
      waterConsumedMl = 0,
      mealCount = 0,
      daysWithMeals = 0,
      daysWithWater = 0,
      averageCaloriesPerDay = 0,
      averageWaterPerDay = 0,
      dailyWaterGoalMl = 0,
      mealTypeCounts = const {
        'breakfast': 0,
        'lunch': 0,
        'snack': 0,
        'dinner': 0,
      },
      mealTypeCalories = const {
        'breakfast': 0,
        'lunch': 0,
        'snack': 0,
        'dinner': 0,
      },
      macroPercentages = const {'protein': 0, 'carbs': 0, 'fat': 0},
      waterSeries = const [],
      mealItems = const [];

  factory _PeriodSummaryData.fromPeriodJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final mealTypeCountsRaw =
        (json['mealTypeCounts'] as Map<String, dynamic>?) ?? const {};
    final mealTypeCaloriesRaw =
        (json['mealTypeCalories'] as Map<String, dynamic>?) ?? const {};
    final macroPercentagesRaw =
        (json['macroPercentages'] as Map<String, dynamic>?) ?? const {};
    final waterSeriesRaw = (json['waterSeries'] as List<dynamic>?) ?? const [];
    final mealItemsRaw = (json['mealItems'] as List<dynamic>?) ?? const [];

    return _PeriodSummaryData(
      period: (json['period'] ?? 'week').toString(),
      label: (json['label'] ?? 'Last 7 days').toString(),
      calories: (summary['calories'] as num?)?.round() ?? 0,
      protein: (summary['protein'] as num?)?.round() ?? 0,
      carbs: (summary['carbs'] as num?)?.round() ?? 0,
      fat: (summary['fat'] as num?)?.round() ?? 0,
      waterConsumedMl: (summary['waterConsumedMl'] as num?)?.round() ?? 0,
      mealCount: (summary['mealCount'] as num?)?.round() ?? 0,
      daysWithMeals: (summary['daysWithMeals'] as num?)?.round() ?? 0,
      daysWithWater: (summary['daysWithWater'] as num?)?.round() ?? 0,
      averageCaloriesPerDay:
          (summary['averageCaloriesPerDay'] as num?)?.toDouble() ?? 0,
      averageWaterPerDay:
          (summary['averageWaterPerDay'] as num?)?.toDouble() ?? 0,
      dailyWaterGoalMl: (summary['dailyWaterGoalMl'] as num?)?.round() ?? 0,
      mealTypeCounts: {
        'breakfast': (mealTypeCountsRaw['breakfast'] as num?)?.round() ?? 0,
        'lunch': (mealTypeCountsRaw['lunch'] as num?)?.round() ?? 0,
        'snack': (mealTypeCountsRaw['snack'] as num?)?.round() ?? 0,
        'dinner': (mealTypeCountsRaw['dinner'] as num?)?.round() ?? 0,
      },
      mealTypeCalories: {
        'breakfast': (mealTypeCaloriesRaw['breakfast'] as num?)?.round() ?? 0,
        'lunch': (mealTypeCaloriesRaw['lunch'] as num?)?.round() ?? 0,
        'snack': (mealTypeCaloriesRaw['snack'] as num?)?.round() ?? 0,
        'dinner': (mealTypeCaloriesRaw['dinner'] as num?)?.round() ?? 0,
      },
      macroPercentages: {
        'protein': (macroPercentagesRaw['protein'] as num?)?.toDouble() ?? 0,
        'carbs': (macroPercentagesRaw['carbs'] as num?)?.toDouble() ?? 0,
        'fat': (macroPercentagesRaw['fat'] as num?)?.toDouble() ?? 0,
      },
      waterSeries: waterSeriesRaw
          .whereType<Map>()
          .map((item) => _WaterPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      mealItems: mealItemsRaw
          .whereType<Map>()
          .map((item) => _MealItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  factory _PeriodSummaryData.fromDailyJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final water = (json['water'] as Map<String, dynamic>?) ?? const {};
    final entries = (json['entries'] as List<dynamic>?) ?? const [];

    final mealItems = entries
        .whereType<Map>()
        .map(
          (item) => _MealItem.fromDailyEntry(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);

    return _PeriodSummaryData(
      period: 'today',
      label: 'Today',
      calories: (summary['calories'] as num?)?.round() ?? 0,
      protein: (summary['protein'] as num?)?.round() ?? 0,
      carbs: (summary['carbs'] as num?)?.round() ?? 0,
      fat: (summary['fat'] as num?)?.round() ?? 0,
      waterConsumedMl: (water['consumedWaterMl'] as num?)?.round() ?? 0,
      mealCount: entries.length,
      daysWithMeals: entries.isNotEmpty ? 1 : 0,
      daysWithWater: (water['consumedWaterMl'] as num?) != null ? 1 : 0,
      averageCaloriesPerDay: (summary['calories'] as num?)?.toDouble() ?? 0,
      averageWaterPerDay: (water['consumedWaterMl'] as num?)?.toDouble() ?? 0,
      dailyWaterGoalMl: (water['dailyWaterGoalMl'] as num?)?.round() ?? 0,
      mealTypeCounts: _countMealTypes(mealItems),
      mealTypeCalories: _sumMealCalories(mealItems),
      macroPercentages: _macroPercentagesFrom(summary),
      waterSeries: [
        _WaterPoint(
          dateKey: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          consumedWaterMl: (water['consumedWaterMl'] as num?)?.round() ?? 0,
          dailyWaterGoalMl: (water['dailyWaterGoalMl'] as num?)?.round() ?? 0,
        ),
      ],
      mealItems: mealItems,
    );
  }

  static Map<String, int> _countMealTypes(List<_MealItem> items) {
    final result = <String, int>{
      'breakfast': 0,
      'lunch': 0,
      'snack': 0,
      'dinner': 0,
    };

    for (final item in items) {
      if (result[item.mealType] != null) {
        result[item.mealType] = result[item.mealType]! + 1;
      }
    }

    return result;
  }

  static Map<String, int> _sumMealCalories(List<_MealItem> items) {
    final result = <String, int>{
      'breakfast': 0,
      'lunch': 0,
      'snack': 0,
      'dinner': 0,
    };

    for (final item in items) {
      if (result[item.mealType] != null) {
        result[item.mealType] = result[item.mealType]! + item.calories;
      }
    }

    return result;
  }

  static Map<String, double> _macroPercentagesFrom(
    Map<String, dynamic> summary,
  ) {
    final protein = (summary['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (summary['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (summary['fat'] as num?)?.toDouble() ?? 0;
    final total = protein + carbs + fat;

    if (total <= 0) {
      return const {'protein': 0, 'carbs': 0, 'fat': 0};
    }

    return {
      'protein': (protein / total) * 100,
      'carbs': (carbs / total) * 100,
      'fat': (fat / total) * 100,
    };
  }
}

class _MealItem {
  final String mealType;
  final String mealName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int grams;
  final String? dateKey;
  final DateTime? createdAt;

  const _MealItem({
    required this.mealType,
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.grams,
    required this.dateKey,
    required this.createdAt,
  });

  factory _MealItem.fromJson(Map<String, dynamic> json) {
    return _MealItem(
      mealType: (json['mealType'] ?? '').toString(),
      mealName: (json['mealName'] ?? '').toString(),
      calories: (json['calories'] as num?)?.round() ?? 0,
      protein: (json['protein'] as num?)?.round() ?? 0,
      carbs: (json['carbs'] as num?)?.round() ?? 0,
      fat: (json['fat'] as num?)?.round() ?? 0,
      grams: (json['grams'] as num?)?.round() ?? 0,
      dateKey: (json['dateKey'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  factory _MealItem.fromDailyEntry(Map<String, dynamic> json) {
    return _MealItem(
      mealType: (json['meal_type'] ?? '').toString(),
      mealName: (json['meal_name'] ?? '').toString(),
      calories: (json['calories'] as num?)?.round() ?? 0,
      protein: (json['protein'] as num?)?.round() ?? 0,
      carbs: (json['carbs'] as num?)?.round() ?? 0,
      fat: (json['fat'] as num?)?.round() ?? 0,
      grams: (json['grams'] as num?)?.round() ?? 0,
      dateKey: (json['date_key'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class _WaterPoint {
  final String dateKey;
  final int consumedWaterMl;
  final int dailyWaterGoalMl;

  const _WaterPoint({
    required this.dateKey,
    required this.consumedWaterMl,
    required this.dailyWaterGoalMl,
  });

  factory _WaterPoint.fromJson(Map<String, dynamic> json) {
    return _WaterPoint(
      dateKey: (json['dateKey'] ?? '').toString(),
      consumedWaterMl: (json['consumedWaterMl'] as num?)?.round() ?? 0,
      dailyWaterGoalMl: (json['dailyWaterGoalMl'] as num?)?.round() ?? 0,
    );
  }

  DateTime? get parsedDate {
    if (dateKey.isEmpty) return null;
    return DateTime.tryParse('$dateKey 00:00:00')?.toLocal();
  }
}

class _UserOverviewCard extends StatelessWidget {
  final Map<String, dynamic>? user;
  final String Function(dynamic value) resolveImageUrl;

  const _UserOverviewCard({required this.user, required this.resolveImageUrl});

  Map<String, dynamic>? get _profile {
    final raw = user?['profile'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  String _textValue(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final name = _textValue(user?['name'], 'Your profile');
    final email = _textValue(user?['email'], '');
    final profile = _profile;
    final imageUrl = resolveImageUrl(
      profile?['image'] ??
          profile?['image_url'] ??
          user?['image'] ??
          user?['image_url'],
    );

    final goal = _textValue(profile?['goal'], 'Goal not set');
    final gender = _textValue(profile?['gender'], 'Unknown');
    final activity = _textValue(profile?['activity_level'], 'Activity not set');
    final weightValue = profile?['weight'] is Map<String, dynamic>
        ? (profile?['weight'] as Map<String, dynamic>)['value']
        : null;
    final heightValue = profile?['height'] is Map<String, dynamic>
        ? (profile?['height'] as Map<String, dynamic>)['value']
        : null;
    final streak = (profile?['streak_count'] as num?)?.round() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.babyBlueLight, AppColors.babyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.deepBlue, AppColors.royalBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          _initials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.deepBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$streak day streak',
                          style: const TextStyle(
                            color: AppColors.deepBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.blueGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  goal,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfilePill(
                      label: gender,
                      icon: Icons.person_outline_rounded,
                    ),
                    if (heightValue != null &&
                        heightValue.toString().isNotEmpty)
                      _ProfilePill(
                        label: '${heightValue.toString()} cm',
                        icon: Icons.height_rounded,
                      ),
                    if (weightValue != null &&
                        weightValue.toString().isNotEmpty)
                      _ProfilePill(
                        label: '${weightValue.toString()} kg',
                        icon: Icons.monitor_weight_outlined,
                      ),
                    _ProfilePill(
                      label: activity,
                      icon: Icons.directions_walk_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ProfilePill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.deepBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final _PeriodOption selectedPeriod;
  final ValueChanged<_PeriodOption> onChanged;
  final VoidCallback? onCalendarTap;
  final DateTime? customDate;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
    this.onCalendarTap,
    this.customDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ..._PeriodOption.values
              .where((p) => p != _PeriodOption.custom)
              .map((period) {
                final selected = period == selectedPeriod;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(period),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.deepBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        period.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.blueGray,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              })
              ,
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCalendarTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: selectedPeriod == _PeriodOption.custom
                    ? AppColors.deepBlue
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 16,
                    color: selectedPeriod == _PeriodOption.custom
                        ? Colors.white
                        : AppColors.deepBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedPeriod == _PeriodOption.custom && customDate != null
                        ? DateFormat('dd MMM').format(customDate!)
                        : 'Custom',
                    style: TextStyle(
                      color: selectedPeriod == _PeriodOption.custom
                          ? Colors.white
                          : AppColors.blueGray,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 70),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.royalBlue),
      ),
    );
  }
}

class _OverviewStatsGrid extends StatelessWidget {
  final _PeriodSummaryData data;

  const _OverviewStatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Calories',
            value: '${data.calories}',
            unit: 'kcal',
            icon: Icons.local_fire_department_rounded,
            tint: AppColors.caloriesPurple,
            background: AppColors.caloriesBg,
            subtitle:
                'avg ${data.averageCaloriesPerDay.toStringAsFixed(0)} / day',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Water',
            value: '${data.waterConsumedMl}',
            unit: 'ml',
            icon: Icons.water_drop_rounded,
            tint: AppColors.waterPrimary,
            background: AppColors.waterBottleBackground,
            subtitle: 'avg ${data.averageWaterPerDay.toStringAsFixed(0)} / day',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Meals',
            value: '${data.mealCount}',
            unit: 'items',
            icon: Icons.restaurant_menu_rounded,
            tint: AppColors.successPrimary,
            background: AppColors.carbsBg,
            subtitle: '${data.daysWithMeals} active days',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color background;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.blueGray.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.blueGray,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRingCard extends StatelessWidget {
  final _PeriodSummaryData data;

  const _MacroRingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.protein + data.carbs + data.fat;
    final proteinPercent = data.macroPercentages['protein'] ?? 0;
    final carbsPercent = data.macroPercentages['carbs'] ?? 0;
    final fatPercent = data.macroPercentages['fat'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.caloriesPurple.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.caloriesPurple, AppColors.proteinBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Macro Balance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        total > 0
                            ? 'Protein, carbs, and fat share across the selected range.'
                            : 'No macro data for this range yet.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(160, 160),
                          painter: _MacroRingPainter(
                            proteinPercent: proteinPercent,
                            carbsPercent: carbsPercent,
                            fatPercent: fatPercent,
                          ),
                        ),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.babyBlueLight,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.caloriesPurple.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${total > 0 ? total : 0} g',
                                style: const TextStyle(
                                  color: AppColors.deepBlue,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: AppColors.blueGray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MacroLegend(
                      label: 'Protein',
                      value: '${data.protein} g',
                      percent: proteinPercent,
                      color: AppColors.proteinBlue,
                      background: AppColors.proteinBg,
                    ),
                    _MacroLegend(
                      label: 'Carbs',
                      value: '${data.carbs} g',
                      percent: carbsPercent,
                      color: AppColors.carbsGreen,
                      background: AppColors.carbsBg,
                    ),
                    _MacroLegend(
                      label: 'Fat',
                      value: '${data.fat} g',
                      percent: fatPercent,
                      color: AppColors.fatOrange,
                      background: AppColors.fatBg,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  final String label;
  final String value;
  final double percent;
  final Color color;
  final Color background;

  const _MacroLegend({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label ${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  const _MacroRingPainter({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = AppColors.lightBlue.withValues(alpha: 0.35)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final segments = [
      (proteinPercent, AppColors.proteinBlue),
      (carbsPercent, AppColors.carbsGreen),
      (fatPercent, AppColors.fatOrange),
    ];

    var startAngle = -math.pi / 2;
    const gap = 0.06;

    for (final segment in segments) {
      final percent = segment.$1.clamp(0, 100).toDouble();
      if (percent <= 0) continue;

      final sweepAngle = ((math.pi * 2) * (percent / 100)) - gap;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = segment.$2
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) {
    return oldDelegate.proteinPercent != proteinPercent ||
        oldDelegate.carbsPercent != carbsPercent ||
        oldDelegate.fatPercent != fatPercent;
  }
}

class _WaterChartCard extends StatelessWidget {
  final _PeriodSummaryData data;
  final String Function(String dateKey) formatDateKey;

  const _WaterChartCard({required this.data, required this.formatDateKey});

  @override
  Widget build(BuildContext context) {
    final points = data.waterSeries;
    final maxWater = math.max(
      1,
      points.fold<int>(
        data.dailyWaterGoalMl,
        (maxValue, point) => math.max(
          maxValue,
          math.max(point.consumedWaterMl, point.dailyWaterGoalMl),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.waterPrimary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.waterSecondary, AppColors.waterPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Water Consumption',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        points.isEmpty
                            ? 'No water data for this range.'
                            : 'Daily water intake against your goal.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _WaterSummaryPill(
                        label: 'Consumed',
                        value: '${data.waterConsumedMl} ml',
                        tint: AppColors.waterPrimary,
                        background: AppColors.waterBottleBackground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WaterSummaryPill(
                        label: 'Goal per day',
                        value: data.dailyWaterGoalMl > 0
                            ? '${data.dailyWaterGoalMl} ml'
                            : '--',
                        tint: AppColors.deepBlue,
                        background: AppColors.babyBlueLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (points.isEmpty)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.waterBottleBackground,
                          AppColors.babyBlueLight.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: Text(
                        'No water entries yet',
                        style: TextStyle(
                          color: AppColors.blueGray,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: points
                          .map((point) {
                            final dateLabel = point.parsedDate == null
                                ? point.dateKey
                                : formatDateKey(point.dateKey);
                            final fillRatio = point.consumedWaterMl / maxWater;
                            final goalRatio = point.dailyWaterGoalMl / maxWater;
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _WaterBar(
                                dateLabel: dateLabel,
                                consumedWaterMl: point.consumedWaterMl,
                                dailyWaterGoalMl: point.dailyWaterGoalMl,
                                fillRatio: fillRatio,
                                goalRatio: goalRatio,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.babyBlueLight, Colors.white],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.waterPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.waterPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: AppColors.waterPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          data.dailyWaterGoalMl > 0
                              ? 'Goal: ${data.dailyWaterGoalMl} ml | Consumed: ${data.waterConsumedMl} ml'
                              : 'Consumed: ${data.waterConsumedMl} ml',
                          style: const TextStyle(
                            color: AppColors.deepBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterBar extends StatelessWidget {
  final String dateLabel;
  final int consumedWaterMl;
  final int dailyWaterGoalMl;
  final double fillRatio;
  final double goalRatio;

  const _WaterBar({
    required this.dateLabel,
    required this.consumedWaterMl,
    required this.dailyWaterGoalMl,
    required this.fillRatio,
    required this.goalRatio,
  });

  @override
  Widget build(BuildContext context) {
    const barHeight = 168.0;
    final safeFill = fillRatio.clamp(0.0, 1.0);
    final safeGoal = goalRatio.clamp(0.0, 1.0);

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$consumedWaterMl',
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: barHeight,
            width: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.waterBottleBackground,
                  AppColors.babyBlueLight.withValues(alpha: 0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: (barHeight - 4) * safeFill,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.waterSecondary,
                          AppColors.waterPrimary,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.waterPrimary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: barHeight * safeGoal,
                  left: 5,
                  right: 5,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepBlue.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            dateLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.blueGray,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterSummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;
  final Color background;

  const _WaterSummaryPill({
    required this.label,
    required this.value,
    required this.tint,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealItemsCard extends StatelessWidget {
  final _PeriodSummaryData data;

  const _MealItemsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.period == 'today' ? 'Today Meals' : 'User Meals',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (data.mealItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No meals found for this range.',
                style: TextStyle(color: AppColors.blueGray, fontSize: 12),
              ),
            )
          else
            Column(
              children: [
                for (final mealType in const [
                  'breakfast',
                  'lunch',
                  'snack',
                  'dinner',
                ])
                  _MealGroupSection(
                    title: _mealLabel(mealType),
                    accent: _mealAccent(mealType),
                    items: data.mealItems
                        .where((item) => item.mealType == mealType)
                        .toList(growable: false),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MealGroupSection extends StatelessWidget {
  final String title;
  final Color accent;
  final List<_MealItem> items;

  const _MealGroupSection({
    required this.title,
    required this.accent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _mealGradient(items.first.mealType),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _mealIcon(items.first.mealType),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} item${items.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meals',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: items
                        .map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _mealGradient(item.mealType),
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _mealIcon(item.mealType),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.mealName,
                                        style: const TextStyle(
                                          color: AppColors.deepBlue,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.dateKey == null ||
                                                item.dateKey!.isEmpty
                                            ? title
                                            : '$title • ${item.dateKey}',
                                        style: const TextStyle(
                                          color: AppColors.blueGray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MacroChip(
                                            label: '${item.calories} kcal',
                                            color: AppColors.caloriesPurple,
                                          ),
                                          _MacroChip(
                                            label: '${item.protein}g protein',
                                            color: AppColors.proteinBlue,
                                          ),
                                          _MacroChip(
                                            label: '${item.carbs}g carbs',
                                            color: AppColors.carbsGreen,
                                          ),
                                          _MacroChip(
                                            label: '${item.fat}g fat',
                                            color: AppColors.fatOrange,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MacroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

IconData _mealIcon(String mealType) {
  switch (mealType) {
    case 'breakfast':
      return Icons.free_breakfast_rounded;
    case 'lunch':
      return Icons.lunch_dining_rounded;
    case 'snack':
      return Icons.cookie_rounded;
    case 'dinner':
      return Icons.dinner_dining_rounded;
    default:
      return Icons.restaurant_rounded;
  }
}

List<Color> _mealGradient(String mealType) {
  switch (mealType) {
    case 'breakfast':
      return const [
        AppColors.breakfastGradientStart,
        AppColors.breakfastGradientEnd,
      ];
    case 'lunch':
      return const [AppColors.lunchGradientStart, AppColors.lunchGradientEnd];
    case 'snack':
      return const [AppColors.snackGradientStart, AppColors.snackGradientEnd];
    case 'dinner':
      return const [AppColors.dinnerGradientStart, AppColors.dinnerGradientEnd];
    default:
      return const [AppColors.lightBlue, AppColors.mediumBlue];
  }
}

Color _mealAccent(String mealType) {
  switch (mealType) {
    case 'breakfast':
      return AppColors.breakfastGradientEnd;
    case 'lunch':
      return AppColors.lunchGradientEnd;
    case 'snack':
      return AppColors.snackGradientEnd;
    case 'dinner':
      return AppColors.dinnerGradientEnd;
    default:
      return AppColors.deepBlue;
  }
}

String _mealLabel(String mealType) {
  switch (mealType) {
    case 'breakfast':
      return 'Breakfast';
    case 'lunch':
      return 'Lunch';
    case 'snack':
      return 'Snack';
    case 'dinner':
      return 'Dinner';
    default:
      return mealType;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 34),
          const SizedBox(height: 12),
          const Text(
            'Could not load meal history',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.blueGray, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
