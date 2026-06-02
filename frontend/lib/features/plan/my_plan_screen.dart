import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/providers/home_provider.dart';
import '../../core/providers/user_provider.dart';
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

class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen>
    with SingleTickerProviderStateMixin {
  bool _isEditingWaterGoal = false;
  double? _pendingWaterGoalL;
  late final AnimationController _waterPulseController;

  @override
  void initState() {
    super.initState();
    _waterPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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

  Future<void> _printPdf({
    required String userName,
    required int dailyCalories,
    required int dailyProtein,
    required int dailyFat,
    required int dailyCarbs,
    required double bmi,
    required String bmiLabel,
    required List<_MealPlanRow> mealRows,
    required double dailyWaterGoalL,
  }) async {
    final doc = pw.Document();
    const borderColor = PdfColors.grey300;
    const headerFill = PdfColor.fromInt(0xFFEAF6FF);
    final sectionTitleStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue,
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

    pw.Table summaryTable(List<List<String>> rows) {
      return pw.Table(
        border: pw.TableBorder.all(color: borderColor),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.35),
          1: const pw.FlexColumnWidth(1),
        },
        children: rows
            .map(
              (row) => pw.TableRow(
                children: [
                  tableCell(row[0], bold: true),
                  tableCell(row[1], align: pw.TextAlign.right),
                ],
              ),
            )
            .toList(),
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
                        color: PdfColors.blue900,
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
              pw.Text('Daily targets', style: sectionTitleStyle),
              pw.SizedBox(height: 8),
              summaryTable([
                [
                  'Daily calories',
                  dailyCalories > 0 ? '$dailyCalories kcal' : '--',
                ],
                ['Carbs (daily)', dailyCarbs > 0 ? '${dailyCarbs}g' : '--'],
                [
                  'Protein (daily)',
                  dailyProtein > 0 ? '${dailyProtein}g' : '--',
                ],
                ['Fat (daily)', dailyFat > 0 ? '${dailyFat}g' : '--'],
                [
                  'BMI',
                  bmi > 0 ? '${bmi.toStringAsFixed(1)} ($bmiLabel)' : '--',
                ],
                [
                  'Water goal (daily)',
                  '${dailyWaterGoalL.toStringAsFixed(1)} L',
                ],
              ]),
              pw.SizedBox(height: 18),
              pw.Text('Targets per meal', style: sectionTitleStyle),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.35),
                  1: const pw.FlexColumnWidth(0.95),
                  2: const pw.FlexColumnWidth(0.85),
                  3: const pw.FlexColumnWidth(0.95),
                  4: const pw.FlexColumnWidth(0.8),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(_mealIcon(text), size: 17, color: AppColors.navy),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
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
            0: FlexColumnWidth(1.35),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(0.9),
            3: FlexColumnWidth(0.95),
            4: FlexColumnWidth(0.85),
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
    required int dailyCalories,
    required int dailyProtein,
    required int dailyFat,
    required int dailyCarbs,
    required double bmi,
    required String bmiLabel,
    required List<_MealPlanRow> mealRows,
    required double dailyWaterGoalL,
  }) {
    return _printPdf(
      userName: userName,
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyFat: dailyFat,
      dailyCarbs: dailyCarbs,
      bmi: bmi,
      bmiLabel: bmiLabel,
      mealRows: mealRows,
      dailyWaterGoalL: dailyWaterGoalL,
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
    final goal = profile['goal']?.toString();
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
      dailyCalories: dailyCalories,
      dailyProtein: dailyProtein,
      dailyFat: dailyFat,
      dailyCarbs: dailyCarbs,
      bmi: bmi,
      bmiLabel: status.label,
      mealRows: mealRows,
      dailyWaterGoalL: dailyWaterGoalL,
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
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(
                          'Targets per meal',
                          Icons.table_chart_rounded,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Split by your goal (${_goalLabel(goal)}). Same values as Home and PDF.',
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
                    index: 2,
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
                    index: 3,
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
