import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_colors.dart';

class FireStreakDialogCard extends StatelessWidget {
  final int streakCount;
  final DateTime selectedDate;
  final bool isGoalReached;
  final List<DateTime> streakDates;

  const FireStreakDialogCard({
    super.key,
    required this.streakCount,
    required this.selectedDate,
    required this.isGoalReached,
    required this.streakDates,
  });

  String _statusText() {
    if (streakCount <= 0) return 'Start your streak today';
    if (streakCount == 1) return 'Great start, keep going';
    if (streakCount < 5) return 'You are building momentum';
    return 'Amazing consistency';
  }

  List<DateTime> _buildWeekDays(DateTime reference) {
    final today = DateUtils.dateOnly(reference);
    final start = today.subtract(Duration(days: today.weekday - 1));
    return List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(selectedDate);
    final weekDays = _buildWeekDays(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.babyBlueLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Streak',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.babyBlueLight.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _statusText(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.blueGray,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.fatOrange.withValues(alpha: 0.25),
                    AppColors.fatOrange.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Lottie.asset(
                  'assets/lottie/Fire animation.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _WeekStreakStrip(
            weekDays: weekDays,
            today: today,
            isGoalReached: isGoalReached,
            streakDates: streakDates,
          ),
        ],
      ),
    );
  }
}

class _WeekStreakStrip extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime today;
  final bool isGoalReached;
  final List<DateTime> streakDates;

  const _WeekStreakStrip({
    required this.weekDays,
    required this.today,
    required this.isGoalReached,
    required this.streakDates,
  });

  String _dayLetter(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
      case DateTime.sunday:
      default:
        return 'S';
    }
  }

  bool _isCompleted(
    DateTime day,
    DateTime todayDate,
    bool goalReached,
    Set<String> completedDateKeys,
  ) {
    final normalizedDay = DateUtils.dateOnly(day);
    final normalizedToday = DateUtils.dateOnly(todayDate);
    if (normalizedDay.isAfter(normalizedToday)) return false;
    if (DateUtils.isSameDay(normalizedDay, normalizedToday)) {
      return goalReached ||
          completedDateKeys.contains(
            normalizedDay.toIso8601String().split('T').first,
          );
    }
    return completedDateKeys.contains(
      normalizedDay.toIso8601String().split('T').first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedDateKeys = streakDates
        .map(DateUtils.dateOnly)
        .map((d) => d.toIso8601String().split('T').first)
        .toSet();

    final completedIndices = <int>[];
    for (int i = 0; i < weekDays.length; i++) {
      if (_isCompleted(weekDays[i], today, isGoalReached, completedDateKeys)) {
        completedIndices.add(i);
      }
    }

    return Column(
      children: [
        Row(
          children: weekDays
              .map(
                (day) => Expanded(
                  child: Text(
                    _dayLetter(day.weekday),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / 7;
            final hasTrail = completedIndices.isNotEmpty;
            final firstIndex = hasTrail ? completedIndices.first : 0;
            final lastIndex = hasTrail ? completedIndices.last : 0;

            return SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasTrail)
                    Positioned(
                      left: (firstIndex * cellWidth) + (cellWidth * 0.16),
                      right:
                          constraints.maxWidth -
                          ((lastIndex + 1) * cellWidth) +
                          (cellWidth * 0.16),
                      child: Container(
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.fatOrange.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  Row(
                    children: weekDays
                        .map(
                          (day) => Expanded(
                            child: Center(
                              child: _WeekDayCircle(
                                day: day,
                                today: today,
                                isCompleted: _isCompleted(
                                  day,
                                  today,
                                  isGoalReached,
                                  completedDateKeys,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WeekDayCircle extends StatelessWidget {
  final DateTime day;
  final DateTime today;
  final bool isCompleted;

  const _WeekDayCircle({
    required this.day,
    required this.today,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedDay = DateUtils.dateOnly(day);
    final normalizedToday = DateUtils.dateOnly(today);
    final isFuture = normalizedDay.isAfter(normalizedToday);
    final isToday = DateUtils.isSameDay(normalizedDay, normalizedToday);

    Color fillColor = AppColors.babyBlueLight;
    Color borderColor = AppColors.babyBlueDark.withValues(alpha: 0.40);
    Color textColor = AppColors.deepBlue;
    List<BoxShadow> shadows = const [];

    if (isFuture) {
      fillColor = Colors.white;
      borderColor = AppColors.blueGray.withValues(alpha: 0.40);
      textColor = AppColors.blueGray;
    } else if (isCompleted) {
      fillColor = AppColors.fatOrange;
      borderColor = AppColors.fatOrange.withValues(alpha: 0.90);
      textColor = Colors.white;
      shadows = [
        BoxShadow(
          color: AppColors.fatOrange.withValues(alpha: 0.30),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isToday) {
      fillColor = AppColors.mediumBlue;
      borderColor = AppColors.navy;
      textColor = Colors.white;
      shadows = [
        BoxShadow(
          color: AppColors.mediumBlue.withValues(alpha: 0.40),
          blurRadius: 12,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: isToday ? 34 : 32,
      height: isToday ? 34 : 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor, width: isToday ? 1.4 : 1.1),
        boxShadow: shadows,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}
