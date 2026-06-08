import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/home_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai_meal_plan_service.dart';
import '../../core/services/meal_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../shared/back_button_widget.dart';

class _MealPlanRow {
  const _MealPlanRow({
    required this.label,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final String label;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;
}

class _AiMealPlanMeal {
  const _AiMealPlanMeal({
    required this.meal,
    required this.name,
    required this.description,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final String meal;
  final String name;
  final String description;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;

  factory _AiMealPlanMeal.fromJson(Map<String, dynamic> json) {
    int number(dynamic value) => (value as num?)?.round() ?? 0;

    return _AiMealPlanMeal(
      meal: (json['meal'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      calories: number(json['calories']),
      carbs: number(json['carbs']),
      protein: number(json['protein']),
      fat: number(json['fat']),
    );
  }
}

class _AiMealPlanDay {
  const _AiMealPlanDay({
    required this.day,
    required this.totalCalories,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.meals,
  });

  final String day;
  final int totalCalories;
  final int totalCarbs;
  final int totalProtein;
  final int totalFat;
  final List<_AiMealPlanMeal> meals;

  factory _AiMealPlanDay.fromJson(Map<String, dynamic> json) {
    int number(dynamic value) => (value as num?)?.round() ?? 0;
    final rawMeals = json['meals'];

    return _AiMealPlanDay(
      day: (json['day'] ?? '').toString(),
      totalCalories: number(json['total_calories']),
      totalCarbs: number(json['total_carbs']),
      totalProtein: number(json['total_protein']),
      totalFat: number(json['total_fat']),
      meals: rawMeals is List
          ? rawMeals
                .whereType<Map>()
                .map((item) => _AiMealPlanMeal.fromJson(Map.from(item)))
                .toList()
          : const [],
    );
  }
}

class _MealReminderSetting {
  const _MealReminderSetting({
    required this.mealType,
    required this.enabled,
    required this.time,
  });

  final String mealType;
  final bool enabled;
  final String time;

  _MealReminderSetting copyWith({bool? enabled, String? time}) {
    return _MealReminderSetting(
      mealType: mealType,
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
    );
  }

  Map<String, dynamic> toJson() {
    return {'mealType': mealType, 'enabled': enabled, 'time': time};
  }

  factory _MealReminderSetting.fromJson(Map<String, dynamic> json) {
    return _MealReminderSetting(
      mealType: (json['mealType'] ?? '').toString(),
      enabled: json['enabled'] != false,
      time: (json['time'] ?? '08:00').toString(),
    );
  }
}

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen>
    with SingleTickerProviderStateMixin {
  bool _isEditingWaterGoal = false;
  bool _isGeneratingAiPlan = false;
  bool _isLoadingMealReminders = true;
  bool _isSavingMealReminders = false;
  bool _mealRemindersEnabled = true;
  String _aiPlanType = 'daily';
  String? _aiPlanError;
  String? _mealReminderError;
  List<_AiMealPlanDay> _aiMealPlanDays = const [];
  List<_MealReminderSetting> _mealReminders = const [];
  double? _pendingWaterGoalL;
  late final AnimationController _waterPulseController;
  final AiMealPlanService _aiMealPlanService = AiMealPlanService();
  final MealService _mealService = MealService();

  @override
  void initState() {
    super.initState();
    _waterPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadMealReminders();
  }

  @override
  void dispose() {
    _waterPulseController.dispose();
    super.dispose();
  }

  double _calculateBmi(Map<String, dynamic> profile) {
    final weightKg = (profile['weight']?['value'] ?? 0).toDouble();
    final heightCm = (profile['height']?['value'] ?? 0).toDouble();
    if (weightKg <= 0 || heightCm <= 0) return 0;

    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  String _goalLabel(String? goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Lose weight';
      case 'gain_weight':
        return 'Gain weight';
      case 'stay_healthy':
        return 'Stay healthy';
      default:
        return 'Stay healthy';
    }
  }

  String _genderLabel(String? gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return '--';
    }
  }

  String _activityLabel(String? activity) {
    switch (activity) {
      case 'sedentary':
        return 'Sedentary';
      case 'lightly_active':
        return 'Lightly Active';
      case 'moderately_active':
        return 'Moderately Active';
      case 'very_active':
        return 'Very Active';
      default:
        return '--';
    }
  }

  String _toTitleCase(String value) {
    final normalized = value
        .trim()
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    if (normalized.isEmpty) return '';

    return normalized
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _profileListText(dynamic rawList) {
    if (rawList is! List || rawList.isEmpty) return 'None';

    final values = rawList
        .map((item) => _toTitleCase(item.toString()))
        .where((item) => item.isNotEmpty && item.toLowerCase() != 'none')
        .toList();

    return values.isEmpty ? 'None' : values.join(', ');
  }

  String _measurementText(dynamic rawMeasurement) {
    if (rawMeasurement is! Map) return '--';

    final measurement = Map<String, dynamic>.from(rawMeasurement);
    final rawValue = measurement['value'];
    final unit = measurement['unit']?.toString();

    if (rawValue is! num || rawValue <= 0) return '--';

    final valueText = rawValue == rawValue.roundToDouble()
        ? rawValue.toInt().toString()
        : rawValue.toStringAsFixed(1);

    return unit == null || unit.isEmpty ? valueText : '$valueText $unit';
  }

  int _ageFromProfile(Map<String, dynamic> profile) {
    final dob = profile['date_of_birth']?.toString() ?? '';
    if (dob.isEmpty) return 0;
    return NutritionCalculator.calculateAge(dob);
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  String _resolveImageUrl(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? '${baseUri.host}:${baseUri.port}'
        : baseUri.host;
    final origin = '${baseUri.scheme}://$authority';

    if (raw.startsWith('/')) {
      return '$origin$raw';
    }

    return '$origin/$raw';
  }

  ({String label, Color color}) _bmiStatus(double bmi) {
    if (bmi <= 0) {
      return (label: 'N/A', color: AppColors.blueGray);
    }
    if (bmi < 18.5) {
      return (label: 'Underweight', color: const Color(0xFF5E88FF));
    }
    if (bmi < 25) {
      return (label: 'Normal', color: const Color(0xFF2FBF71));
    }
    if (bmi < 30) {
      return (label: 'Overweight', color: const Color(0xFFFFB020));
    }
    return (label: 'Obese', color: const Color(0xFFFF5E5E));
  }

  ({int dailyCalories, int dailyProtein, int dailyFat, int dailyCarbs})
  _resolveDailyTargets(
    HomeProvider homeProvider,
    Map<String, dynamic> profile,
  ) {
    if (homeProvider.dailyCalories > 0) {
      return (
        dailyCalories: homeProvider.dailyCalories,
        dailyProtein: homeProvider.dailyProtein,
        dailyFat: homeProvider.dailyFat,
        dailyCarbs: homeProvider.dailyCarbs,
      );
    }

    final calories = profile.isEmpty
        ? 0
        : NutritionCalculator.calculateCalories(profile);
    final macros = NutritionCalculator.calculateMacros(profile, calories);

    return (
      dailyCalories: calories,
      dailyProtein: macros['protein'] ?? 0,
      dailyFat: macros['fat'] ?? 0,
      dailyCarbs: macros['carbs'] ?? 0,
    );
  }

  List<_MealPlanRow> _buildMealRows({
    required String? goal,
    required int dailyCalories,
    required int dailyProtein,
    required int dailyFat,
    required int dailyCarbs,
  }) {
    final dist = NutritionCalculator.mealDistributionForGoal(goal);
    const meals = [
      ('Breakfast', 'breakfast'),
      ('Lunch', 'lunch'),
      ('Snack', 'snack'),
      ('Dinner', 'dinner'),
    ];

    return meals.map((meal) {
      final ratio = dist[meal.$2] ?? 0.0;
      final mealCalories = (dailyCalories * ratio).round();
      return _MealPlanRow(
        label: meal.$1,
        calories: mealCalories,
        carbs: NutritionCalculator.distributeMacro(
          dailyCarbs,
          mealCalories,
          dailyCalories,
        ),
        protein: NutritionCalculator.distributeMacro(
          dailyProtein,
          mealCalories,
          dailyCalories,
        ),
        fat: NutritionCalculator.distributeMacro(
          dailyFat,
          mealCalories,
          dailyCalories,
        ),
      );
    }).toList();
  }

  List<_MealReminderSetting> _defaultMealReminders() {
    return const [
      _MealReminderSetting(mealType: 'breakfast', enabled: true, time: '08:00'),
      _MealReminderSetting(mealType: 'lunch', enabled: true, time: '13:00'),
      _MealReminderSetting(mealType: 'snack', enabled: true, time: '16:30'),
      _MealReminderSetting(mealType: 'dinner', enabled: true, time: '19:30'),
    ];
  }

  String _mealReminderLabel(String mealType) {
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
        return _toTitleCase(mealType);
    }
  }

  TimeOfDay _timeOfDayFromText(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _timeTextFromTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _displayReminderTime(String time) {
    final parsed = _timeOfDayFromText(time);
    final hour = parsed.hourOfPeriod == 0 ? 12 : parsed.hourOfPeriod;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _loadMealReminders() async {
    try {
      final response = await _mealService.getMealReminders();
      final settings = response['settings'] as Map<String, dynamic>? ?? {};
      final rawReminders = settings['reminders'];

      if (!mounted) return;
      setState(() {
        _mealRemindersEnabled = settings['enabled'] != false;
        _mealReminders = rawReminders is List
            ? rawReminders
                  .whereType<Map>()
                  .map((item) => _MealReminderSetting.fromJson(Map.from(item)))
                  .toList()
            : _defaultMealReminders();
        _mealReminderError = null;
        _isLoadingMealReminders = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mealReminders = _defaultMealReminders();
        _mealReminderError = 'Could not load meal reminders.';
        _isLoadingMealReminders = false;
      });
    }
  }

  Future<void> _saveMealReminders({
    bool? enabled,
    List<_MealReminderSetting>? reminders,
  }) async {
    if (_isSavingMealReminders) return;

    final nextEnabled = enabled ?? _mealRemindersEnabled;
    final nextReminders = reminders ?? _mealReminders;

    setState(() {
      _isSavingMealReminders = true;
      _mealReminderError = null;
      _mealRemindersEnabled = nextEnabled;
      _mealReminders = nextReminders;
    });

    try {
      final response = await _mealService.updateMealReminders(
        enabled: nextEnabled,
        reminders: nextReminders.map((item) => item.toJson()).toList(),
      );
      final settings = response['settings'] as Map<String, dynamic>? ?? {};
      final rawReminders = settings['reminders'];

      if (!mounted) return;
      setState(() {
        _mealRemindersEnabled = settings['enabled'] != false;
        _mealReminders = rawReminders is List
            ? rawReminders
                  .whereType<Map>()
                  .map((item) => _MealReminderSetting.fromJson(Map.from(item)))
                  .toList()
            : nextReminders;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mealReminderError = error
            .toString()
            .replaceFirst('Exception: ', '')
            .trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingMealReminders = false;
        });
      }
    }
  }

  Future<void> _pickMealReminderTime(_MealReminderSetting reminder) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromText(reminder.time),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.deepBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.deepBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final updated = _mealReminders
        .map(
          (item) => item.mealType == reminder.mealType
              ? item.copyWith(time: _timeTextFromTimeOfDay(picked))
              : item,
        )
        .toList();

    await _saveMealReminders(reminders: updated);
  }

  Future<void> _generateAiMealPlan({
    required String planType,
    required String userName,
    required String goalLabel,
    required String genderLabel,
    required int age,
    required String heightText,
    required String weightText,
    required String activityLabel,
    required String allergiesText,
    required String medicalConditionsText,
    required int dailyCalories,
    required int dailyProtein,
    required int dailyCarbs,
    required int dailyFat,
    required double dailyWaterGoalL,
    required List<_MealPlanRow> mealRows,
  }) async {
    if (_isGeneratingAiPlan) return;

    if (dailyCalories <= 0 || dailyProtein <= 0 || dailyCarbs <= 0) {
      setState(() {
        _aiPlanError =
            'Complete your profile first so AI can use your calorie and macro targets.';
      });
      return;
    }

    setState(() {
      _isGeneratingAiPlan = true;
      _aiPlanType = planType;
      _aiPlanError = null;
    });

    try {
      final plan = await _aiMealPlanService.generateMealPlan(
        planType: planType,
        profile: {
          'name': userName,
          'goalLabel': goalLabel,
          'genderLabel': genderLabel,
          'age': age,
          'heightText': heightText,
          'weightText': weightText,
          'activityLabel': activityLabel,
          'allergiesText': allergiesText,
          'medicalConditionsText': medicalConditionsText,
        },
        targets: {
          'dailyCalories': dailyCalories,
          'dailyProtein': dailyProtein,
          'dailyCarbs': dailyCarbs,
          'dailyFat': dailyFat,
          'dailyWaterGoalL': dailyWaterGoalL,
        },
        mealTargets: mealRows
            .map(
              (row) => {
                'label': row.label,
                'calories': row.calories,
                'carbs': row.carbs,
                'protein': row.protein,
                'fat': row.fat,
              },
            )
            .toList(),
      );

      final rawDays = plan['days'];
      final days = rawDays is List
          ? rawDays
                .whereType<Map>()
                .map((item) => _AiMealPlanDay.fromJson(Map.from(item)))
                .where((day) => day.meals.isNotEmpty)
                .toList()
          : <_AiMealPlanDay>[];

      if (days.isEmpty) {
        throw const FormatException('AI returned an empty plan');
      }

      if (!mounted) return;
      setState(() {
        _aiMealPlanDays = days;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _aiPlanError = message.isEmpty
            ? 'Could not generate the AI meal plan. Try again.'
            : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiPlan = false;
        });
      }
    }
  }

  Future<void> _printPdf({
    required String userName,
    required String profileImageUrl,
    required int dailyCalories,
    required int dailyProtein,
    required int dailyFat,
    required int dailyCarbs,
    required double bmi,
    required String bmiLabel,
    required List<_MealPlanRow> mealRows,
    required double dailyWaterGoalL,
    required int age,
    required String goalLabel,
    required String genderLabel,
    required String activityLabel,
    required String heightText,
    required String weightText,
    required String allergiesText,
    required String medicalConditionsText,
    required String aiPlanType,
    required List<_AiMealPlanDay> aiMealPlanDays,
  }) async {
    pw.ImageProvider? profileImage;
    if (profileImageUrl.isNotEmpty) {
      try {
        profileImage = await networkImage(profileImageUrl);
      } catch (_) {
        profileImage = null;
      }
    }

    final doc = pw.Document();
    const borderColor = PdfColors.grey300;
    const headerFill = PdfColor.fromInt(0xFFEAF6FF);
    const navy = PdfColor.fromInt(0xFF12325B);
    const softBlue = PdfColor.fromInt(0xFFF3FAFF);
    const chipFill = PdfColor.fromInt(0xFFFFFFFF);
    final sectionTitleStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: navy,
    );

    pw.Widget tableCell(
      String text, {
      bool bold = false,
      pw.TextAlign align = pw.TextAlign.left,
      double verticalPadding = 9,
      double horizontalPadding = 10,
    }) {
      return pw.Padding(
        padding: pw.EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    pw.Widget sectionTitle(String text) {
      return pw.Row(
        children: [
          pw.Container(
            width: 5,
            height: 16,
            decoration: pw.BoxDecoration(
              color: navy,
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(text, style: sectionTitleStyle),
        ],
      );
    }

    pw.Widget profileChip(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: chipFill,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: borderColor, width: 0.7),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '$label: ',
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.blueGrey500,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget healthBox(String title, String value) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: borderColor, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.blueGrey500,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget targetCard(String label, String value, PdfColor color) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: borderColor, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: navy,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget profileOverviewCard() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: softBlue,
          borderRadius: pw.BorderRadius.circular(16),
          border: pw.Border.all(color: borderColor),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 58,
              height: 58,
              decoration: pw.BoxDecoration(
                color: navy,
                borderRadius: pw.BorderRadius.circular(16),
                image: profileImage == null
                    ? null
                    : pw.DecorationImage(
                        image: profileImage,
                        fit: pw.BoxFit.cover,
                      ),
              ),
              child: profileImage == null
                  ? pw.Center(
                      child: pw.Text(
                        _initials(userName),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          userName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: navy,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(12),
                          border: pw.Border.all(color: borderColor),
                        ),
                        child: pw.Text(
                          goalLabel,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 9),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      profileChip('Age', age > 0 ? '$age years' : '--'),
                      profileChip('Gender', genderLabel),
                      profileChip('Height', heightText),
                      profileChip('Weight', weightText),
                      profileChip('Activity', activityLabel),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  healthBox('Allergies / restrictions', allergiesText),
                  pw.SizedBox(height: 7),
                  healthBox('Medical conditions', medicalConditionsText),
                ],
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget aiMacroChip(String label, String value, PdfColor color) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: borderColor, width: 0.6),
        ),
        child: pw.Text(
          '$label: $value',
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      );
    }

    pw.Widget aiMealBox(_AiMealPlanMeal meal) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: borderColor, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 46,
                  child: pw.Text(
                    meal.meal,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        meal.name.isEmpty ? '--' : meal.name,
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      if (meal.description.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          meal.description,
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                aiMacroChip(
                  'Calories',
                  '${meal.calories} kcal',
                  PdfColors.deepPurple,
                ),
                aiMacroChip('Carbs', '${meal.carbs}g', PdfColors.green800),
                aiMacroChip('Protein', '${meal.protein}g', PdfColors.blue800),
                aiMacroChip('Fat', '${meal.fat}g', PdfColors.orange800),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget aiDayCard(_AiMealPlanDay day) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: softBlue,
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: borderColor),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    day.day.isEmpty ? 'Day' : day.day,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
                pw.Text(
                  '${day.totalCalories} kcal',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepPurple,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                aiMacroChip('Carbs', '${day.totalCarbs}g', PdfColors.green800),
                aiMacroChip(
                  'Protein',
                  '${day.totalProtein}g',
                  PdfColors.blue800,
                ),
                aiMacroChip('Fat', '${day.totalFat}g', PdfColors.orange800),
              ],
            ),
            pw.SizedBox(height: 10),
            ...day.meals.map(aiMealBox),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: pw.BoxDecoration(
                  color: headerFill,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'My Plan',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      userName,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              sectionTitle('Profile overview'),
              pw.SizedBox(height: 8),
              profileOverviewCard(),
              pw.SizedBox(height: 18),
              sectionTitle('Daily targets'),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: targetCard(
                      'Calories',
                      dailyCalories > 0 ? '$dailyCalories kcal' : '--',
                      PdfColors.deepPurple,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: targetCard(
                      'Protein',
                      dailyProtein > 0 ? '${dailyProtein}g' : '--',
                      PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: targetCard(
                      'Carbs',
                      dailyCarbs > 0 ? '${dailyCarbs}g' : '--',
                      PdfColors.green800,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: targetCard(
                      'Fat',
                      dailyFat > 0 ? '${dailyFat}g' : '--',
                      PdfColors.orange800,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: targetCard(
                      'BMI',
                      bmi > 0 ? '${bmi.toStringAsFixed(1)} - $bmiLabel' : '--',
                      PdfColors.cyan800,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: targetCard(
                      'Daily water goal',
                      '${dailyWaterGoalL.toStringAsFixed(1)} L',
                      PdfColors.lightBlue800,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              sectionTitle('Targets per meal'),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.65),
                  1: const pw.FlexColumnWidth(0.9),
                  2: const pw.FlexColumnWidth(0.78),
                  3: const pw.FlexColumnWidth(0.9),
                  4: const pw.FlexColumnWidth(0.72),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerFill),
                    children: [
                      tableCell('Meal', bold: true),
                      tableCell(
                        'Calories',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                      tableCell(
                        'Carbs',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                      tableCell(
                        'Protein',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                      tableCell('Fat', bold: true, align: pw.TextAlign.center),
                    ],
                  ),
                  ...mealRows.map(
                    (row) => pw.TableRow(
                      children: [
                        tableCell(row.label, bold: true),
                        tableCell(
                          '${row.calories}',
                          align: pw.TextAlign.center,
                        ),
                        tableCell('${row.carbs}g', align: pw.TextAlign.center),
                        tableCell(
                          '${row.protein}g',
                          align: pw.TextAlign.center,
                        ),
                        tableCell('${row.fat}g', align: pw.TextAlign.center),
                      ],
                    ),
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      tableCell('Daily total', bold: true),
                      tableCell(
                        '$dailyCalories',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                      tableCell(
                        '${dailyCarbs}g',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                      tableCell(
                        '${dailyProtein}g',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                      tableCell(
                        '${dailyFat}g',
                        bold: true,
                        align: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: borderColor),
              pw.SizedBox(height: 6),
              pw.Text(
                'Generated ${DateTime.now().toLocal()}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (aiMealPlanDays.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (_) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: pw.BoxDecoration(
                color: navy,
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AI Meal Plan',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    aiPlanType == 'weekly'
                        ? 'Weekly personalized meal plan'
                        : 'Daily personalized meal plan',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey200,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: borderColor, width: 0.7),
              ),
              child: pw.Text(
                'Generated according to your goal, allergies, medical conditions, daily calories, macros, meal split, and water goal.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ),
            pw.SizedBox(height: 14),
            ...aiMealPlanDays.map(aiDayCard),
          ],
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'my-plan.pdf',
    );
  }

  Widget _animatedBlock({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('plan-block-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildNavyHeader({
    required String userName,
    required VoidCallback onPrint,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipPath(
                  clipper: _PlanHeaderWaveClipper(),
                  child: Container(
                    height: 128,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.navy,
                          AppColors.navy.withValues(alpha: 0.92),
                          AppColors.deepBlue.withValues(alpha: 0.88),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -24,
                          top: -18,
                          child: Icon(
                            Icons.insights_rounded,
                            size: 110,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                        Positioned(
                          left: -10,
                          bottom: 8,
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const AppBackButton(
                      backgroundColor: Colors.transparent,
                      showBorder: false,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Export PDF',
                      icon: const Icon(
                        Icons.print_rounded,
                        color: Colors.white,
                      ),
                      onPressed: onPrint,
                    ),
                  ),
                ),
                Positioned(
                  left: 56,
                  right: 56,
                  top: 22,
                  child: Column(
                    children: [
                      const Text(
                        'My Plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.navy),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  IconData _mealIcon(String mealLabel) {
    switch (mealLabel) {
      case 'Breakfast':
        return Icons.free_breakfast_rounded;
      case 'Lunch':
        return Icons.lunch_dining_rounded;
      case 'Snack':
        return Icons.cookie_rounded;
      case 'Dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _macroChip({
    required String label,
    required String value,
    required Color color,
    required Color background,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calorieCard(int dailyCalories) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.caloriesBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.caloriesPurple,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Daily calories',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blueGray,
                ),
              ),
            ),
            Text(
              dailyCalories > 0 ? '$dailyCalories kcal' : '--',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.caloriesPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bmiCard({
    required double bmi,
    required String bmiLabel,
    required Color bmiColor,
  }) {
    final hasBmi = bmi > 0;

    return _card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bmiColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.monitor_weight_outlined, color: bmiColor),
            ),
            const SizedBox(width: 12),
            const Text(
              'BMI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.blueGray,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hasBmi ? bmi.toStringAsFixed(1) : '--',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: hasBmi ? bmiColor : AppColors.deepBlue,
              ),
            ),
            const Spacer(),
            if (hasBmi)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bmiColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bmiColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  bmiLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: bmiColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileOverviewCard({
    required String userName,
    required String profileImageUrl,
    required int age,
    required String genderLabel,
    required String heightText,
    required String weightText,
    required String goalLabel,
    required String activityLabel,
    required String allergiesText,
    required String medicalConditionsText,
  }) {
    Widget profilePill(String label, IconData icon) {
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

    Widget detailRow(String label, String value, IconData icon) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.deepBlue),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.blueGray,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
          Container(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: profileImageUrl.isNotEmpty
                  ? Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          _initials(userName),
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
                        _initials(userName),
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
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
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
                        goalLabel,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    profilePill(
                      age > 0 ? '$age years' : '--',
                      Icons.cake_outlined,
                    ),
                    profilePill(genderLabel, Icons.person_outline_rounded),
                    profilePill(heightText, Icons.height_rounded),
                    profilePill(weightText, Icons.monitor_weight_outlined),
                    profilePill(activityLabel, Icons.directions_walk_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                detailRow(
                  'Allergies / restrictions',
                  allergiesText,
                  Icons.no_food_rounded,
                ),
                const SizedBox(height: 8),
                detailRow(
                  'Medical conditions',
                  medicalConditionsText,
                  Icons.medical_information_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealsTable({required List<_MealPlanRow> rows}) {
    Widget headerCell(String text, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
    }

    Widget bodyCell(String text, {FontWeight weight = FontWeight.w700}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: weight,
            color: AppColors.deepBlue,
          ),
        ),
      );
    }

    Widget mealLabelCell(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            Icon(_mealIcon(text), size: 15, color: AppColors.navy),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.65),
            1: FlexColumnWidth(0.92),
            2: FlexColumnWidth(0.8),
            3: FlexColumnWidth(0.9),
            4: FlexColumnWidth(0.72),
          },
          border: TableBorder(
            horizontalInside: BorderSide(
              color: AppColors.royalBlue.withValues(alpha: 0.08),
            ),
            verticalInside: BorderSide(
              color: AppColors.royalBlue.withValues(alpha: 0.06),
            ),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: AppColors.babyBlueLight.withValues(alpha: 0.55),
              ),
              children: [
                mealLabelCell('Meal'),
                headerCell('Calories', AppColors.caloriesPurple),
                headerCell('Carbs', AppColors.macroCarbs),
                headerCell('Protein', AppColors.macroProtein),
                headerCell('Fat', AppColors.macroFat),
              ],
            ),
            ...rows.map(
              (row) => TableRow(
                children: [
                  mealLabelCell(row.label),
                  bodyCell('${row.calories}'),
                  bodyCell('${row.carbs}g'),
                  bodyCell('${row.protein}g'),
                  bodyCell('${row.fat}g'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiMealPlanCard({
    required VoidCallback onDaily,
    required VoidCallback onWeekly,
  }) {
    Widget planButton({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onPressed,
    }) {
      return Expanded(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: selected ? AppColors.navy : AppColors.deepBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.deepBlue.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isGeneratingAiPlan ? null : onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
      );
    }

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI meal plan',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                planButton(
                  label: 'Daily',
                  icon: Icons.today_rounded,
                  selected: _aiPlanType == 'daily',
                  onPressed: onDaily,
                ),
                const SizedBox(width: 10),
                planButton(
                  label: 'Weekly',
                  icon: Icons.calendar_month_rounded,
                  selected: _aiPlanType == 'weekly',
                  onPressed: onWeekly,
                ),
              ],
            ),
            if (_isGeneratingAiPlan) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(
                minHeight: 5,
                color: AppColors.deepBlue,
                backgroundColor: AppColors.babyBlueLight,
              ),
            ],
            if (_aiPlanError != null) ...[
              const SizedBox(height: 12),
              Text(
                _aiPlanError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_aiMealPlanDays.isNotEmpty) ...[
              const SizedBox(height: 14),
              ..._aiMealPlanDays.map(_aiPlanDayCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _aiPlanDayCard(_AiMealPlanDay day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.babyBlueLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.day.isEmpty ? 'Day' : day.day,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${day.totalCalories} kcal',
                style: const TextStyle(
                  color: AppColors.caloriesPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _aiMacroPill('${day.totalCarbs}g carbs', AppColors.macroCarbs),
              _aiMacroPill(
                '${day.totalProtein}g protein',
                AppColors.macroProtein,
              ),
              _aiMacroPill('${day.totalFat}g fat', AppColors.macroFat),
            ],
          ),
          const SizedBox(height: 10),
          ...day.meals.map(_aiMealTile),
        ],
      ),
    );
  }

  Widget _aiMealTile(_AiMealPlanMeal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.royalBlue.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.deepBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _mealIcon(meal.meal),
              color: AppColors.deepBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.meal,
                  style: const TextStyle(
                    color: AppColors.blueGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meal.name,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (meal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meal.description,
                    style: const TextStyle(
                      color: AppColors.blueGray,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _aiMacroPill(
                      '${meal.calories} kcal',
                      AppColors.caloriesPurple,
                    ),
                    _aiMacroPill('${meal.carbs}g C', AppColors.macroCarbs),
                    _aiMacroPill('${meal.protein}g P', AppColors.macroProtein),
                    _aiMacroPill('${meal.fat}g F', AppColors.macroFat),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiMacroPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _mealReminderCard() {
    if (_isLoadingMealReminders) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Text(
                'Loading meal reminders...',
                style: TextStyle(
                  color: AppColors.blueGray,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final reminders = _mealReminders.isEmpty
        ? _defaultMealReminders()
        : _mealReminders;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Meal reminders',
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Switch(
                  value: _mealRemindersEnabled,
                  activeThumbColor: AppColors.deepBlue,
                  onChanged: _isSavingMealReminders
                      ? null
                      : (value) => _saveMealReminders(enabled: value),
                ),
              ],
            ),
            if (_isSavingMealReminders) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                minHeight: 4,
                color: AppColors.deepBlue,
                backgroundColor: AppColors.babyBlueLight,
              ),
            ],
            if (_mealReminderError != null) ...[
              const SizedBox(height: 10),
              Text(
                _mealReminderError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...reminders.map((reminder) {
              final label = _mealReminderLabel(reminder.mealType);
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.babyBlueLight.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.lightBlue.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_mealIcon(label), color: AppColors.deepBlue, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Switch(
                      value: reminder.enabled,
                      activeThumbColor: AppColors.deepBlue,
                      onChanged:
                          !_mealRemindersEnabled || _isSavingMealReminders
                          ? null
                          : (value) {
                              final updated = reminders
                                  .map(
                                    (item) => item.mealType == reminder.mealType
                                        ? item.copyWith(enabled: value)
                                        : item,
                                  )
                                  .toList();
                              _saveMealReminders(reminders: updated);
                            },
                    ),
                    TextButton.icon(
                      onPressed:
                          !_mealRemindersEnabled || _isSavingMealReminders
                          ? null
                          : () => _pickMealReminderTime(reminder),
                      icon: const Icon(Icons.schedule_rounded, size: 17),
                      label: Text(
                        _displayReminderTime(reminder.time),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _waterCard({
    required double dailyWaterGoalL,
    required ValueChanged<double> onGoalChangedLiters,
  }) {
    final editingValue = (_pendingWaterGoalL ?? dailyWaterGoalL).clamp(
      0.5,
      6.0,
    );
    final displayGoal = _isEditingWaterGoal ? editingValue : dailyWaterGoalL;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  color: AppColors.deepBlue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Daily water goal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepBlue,
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepBlue,
                    side: BorderSide(
                      color: AppColors.deepBlue.withValues(alpha: 0.22),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditingWaterGoal = !_isEditingWaterGoal;
                      _pendingWaterGoalL ??= dailyWaterGoalL;
                    });
                  },
                  child: Text(
                    _isEditingWaterGoal ? 'Close' : 'Edit goal',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (!_isEditingWaterGoal) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 0.94, end: 1.06).animate(
                      CurvedAnimation(
                        parent: _waterPulseController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.babyBlueLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: AppColors.royalBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${displayGoal.toStringAsFixed(1)} L',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.deepBlue,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'per day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blueGray.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            if (_isEditingWaterGoal) ...[
              const SizedBox(height: 12),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Daily goal',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blueGray,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.royalBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${editingValue.toStringAsFixed(1)}L',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: editingValue,
                min: 0.5,
                max: 6.0,
                divisions: 11,
                label: '${editingValue.toStringAsFixed(1)}L',
                onChanged: (v) {
                  setState(() => _pendingWaterGoalL = v);
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    final value = (_pendingWaterGoalL ?? dailyWaterGoalL).clamp(
                      0.5,
                      6.0,
                    );
                    onGoalChangedLiters(value);
                    setState(() {
                      _isEditingWaterGoal = false;
                    });
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf({
    required String userName,
    required String profileImageUrl,
    required int dailyCalories,
    required int dailyProtein,
    required int dailyFat,
    required int dailyCarbs,
    required double bmi,
    required String bmiLabel,
    required List<_MealPlanRow> mealRows,
    required double dailyWaterGoalL,
    required int age,
    required String goalLabel,
    required String genderLabel,
    required String activityLabel,
    required String heightText,
    required String weightText,
    required String allergiesText,
    required String medicalConditionsText,
    required String aiPlanType,
    required List<_AiMealPlanDay> aiMealPlanDays,
  }) {
    return _printPdf(
      userName: userName,
      profileImageUrl: profileImageUrl,
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyFat: dailyFat,
      dailyCarbs: dailyCarbs,
      bmi: bmi,
      bmiLabel: bmiLabel,
      mealRows: mealRows,
      dailyWaterGoalL: dailyWaterGoalL,
      age: age,
      goalLabel: goalLabel,
      genderLabel: genderLabel,
      activityLabel: activityLabel,
      heightText: heightText,
      weightText: weightText,
      allergiesText: allergiesText,
      medicalConditionsText: medicalConditionsText,
      aiPlanType: aiPlanType,
      aiMealPlanDays: aiMealPlanDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final homeProvider = context.watch<HomeProvider>();
    final user = userProvider.user;
    final profileRaw = user?['profile'];
    final profile = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw)
        : <String, dynamic>{};

    final userName = user?['name']?.toString() ?? 'User';
    final profileImageUrl = _resolveImageUrl(
      profile['image_url'] ??
          profile['image'] ??
          profile['imageUrl'] ??
          user?['image_url'] ??
          user?['image'] ??
          user?['imageUrl'],
    );
    final goal = profile['goal']?.toString();
    final age = _ageFromProfile(profile);
    final goalLabel = _goalLabel(goal);
    final genderLabel = _genderLabel(profile['gender']?.toString());
    final activityLabel = _activityLabel(profile['activity_level']?.toString());
    final heightText = _measurementText(profile['height']);
    final weightText = _measurementText(profile['weight']);
    final allergiesText = _profileListText(profile['allergies']);
    final medicalConditionsText = _profileListText(
      profile['medical_conditions'],
    );
    final targets = _resolveDailyTargets(homeProvider, profile);
    final dailyCalories = targets.dailyCalories;
    final dailyProtein = targets.dailyProtein;
    final dailyFat = targets.dailyFat;
    final dailyCarbs = targets.dailyCarbs;

    final bmi = profile.isEmpty ? 0.0 : _calculateBmi(profile);
    final status = _bmiStatus(bmi);
    final mealRows = _buildMealRows(
      goal: goal,
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyFat: dailyFat,
      dailyCarbs: dailyCarbs,
    );

    final dailyWaterGoalL = homeProvider.dailyWaterGoalL;

    void exportPdf() => _exportPdf(
      userName: userName,
      profileImageUrl: profileImageUrl,
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyFat: dailyFat,
      dailyCarbs: dailyCarbs,
      bmi: bmi,
      bmiLabel: status.label,
      mealRows: mealRows,
      dailyWaterGoalL: dailyWaterGoalL,
      age: age,
      goalLabel: goalLabel,
      genderLabel: genderLabel,
      activityLabel: activityLabel,
      heightText: heightText,
      weightText: weightText,
      allergiesText: allergiesText,
      medicalConditionsText: medicalConditionsText,
      aiPlanType: _aiPlanType,
      aiMealPlanDays: _aiMealPlanDays,
    );

    void generateAiPlan(String planType) => _generateAiMealPlan(
      planType: planType,
      userName: userName,
      goalLabel: goalLabel,
      genderLabel: genderLabel,
      age: age,
      heightText: heightText,
      weightText: weightText,
      activityLabel: activityLabel,
      allergiesText: allergiesText,
      medicalConditionsText: medicalConditionsText,
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyCarbs: dailyCarbs,
      dailyFat: dailyFat,
      dailyWaterGoalL: dailyWaterGoalL,
      mealRows: mealRows,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildNavyHeader(userName: userName, onPrint: exportPdf),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                children: [
                  _animatedBlock(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Profile overview',
                          Icons.person_search_rounded,
                        ),
                        const SizedBox(height: 10),
                        _profileOverviewCard(
                          userName: userName,
                          profileImageUrl: profileImageUrl,
                          age: age,
                          genderLabel: genderLabel,
                          heightText: heightText,
                          weightText: weightText,
                          goalLabel: goalLabel,
                          activityLabel: activityLabel,
                          allergiesText: allergiesText,
                          medicalConditionsText: medicalConditionsText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _animatedBlock(
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Daily targets',
                          Icons.flag_circle_rounded,
                        ),
                        const SizedBox(height: 10),
                        _calorieCard(dailyCalories),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _macroChip(
                              label: 'Carbs',
                              value: dailyCarbs > 0 ? '${dailyCarbs}g' : '--',
                              color: AppColors.macroCarbs,
                              background: AppColors.carbsBg,
                              icon: Icons.grain_rounded,
                            ),
                            const SizedBox(width: 8),
                            _macroChip(
                              label: 'Protein',
                              value: dailyProtein > 0
                                  ? '${dailyProtein}g'
                                  : '--',
                              color: AppColors.macroProtein,
                              background: AppColors.proteinBg,
                              icon: Icons.fitness_center_rounded,
                            ),
                            const SizedBox(width: 8),
                            _macroChip(
                              label: 'Fat',
                              value: dailyFat > 0 ? '${dailyFat}g' : '--',
                              color: AppColors.macroFat,
                              background: AppColors.fatBg,
                              icon: Icons.opacity_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _bmiCard(
                          bmi: bmi,
                          bmiLabel: status.label,
                          bmiColor: status.color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _animatedBlock(
                    index: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Targets per meal',
                          Icons.table_chart_rounded,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Split by your goal ($goalLabel). Same values as Home and PDF.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blueGray.withValues(alpha: 0.95),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _mealsTable(rows: mealRows),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _animatedBlock(
                    index: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'AI meal plan',
                          Icons.auto_awesome_rounded,
                        ),
                        const SizedBox(height: 10),
                        _aiMealPlanCard(
                          onDaily: () => generateAiPlan('daily'),
                          onWeekly: () => generateAiPlan('weekly'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _animatedBlock(
                    index: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Meal reminders',
                          Icons.notifications_active_rounded,
                        ),
                        const SizedBox(height: 10),
                        _mealReminderCard(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _animatedBlock(
                    index: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Hydration', Icons.water_drop_rounded),
                        const SizedBox(height: 10),
                        _waterCard(
                          dailyWaterGoalL: dailyWaterGoalL,
                          onGoalChangedLiters:
                              homeProvider.setDailyWaterGoalLiters,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _animatedBlock(
                    index: 6,
                    child: _card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Export or print this plan as PDF.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blueGray,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: exportPdf,
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text(
                                'PDF',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _PlanHeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 10);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height - 1,
      size.width * 0.5,
      size.height - 5,
    );
    path.quadraticBezierTo(
      size.width * 0.76,
      size.height - 9,
      size.width,
      size.height - 7,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
