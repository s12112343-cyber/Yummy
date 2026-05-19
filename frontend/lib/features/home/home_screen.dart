import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/home_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/custom_bottom_nav.dart';
import '../../shared/app_drawer.dart';
import '../about/about_us_page.dart';
import '../profile/user_profile_screen.dart';
import '../auth/welcome_screen.dart';
import '../add_meal/add_meal_screen.dart';
import 'widgets/fire_streak_dialog_card.dart';
import 'widgets/streak_gain_popup_card.dart';
import 'widgets/streak_lost_popup_card.dart';
import '../meal_history/meal_history_screen.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class MealCardData {
  final String type; // breakfast, lunch, snack, dinner
  final String title;
  final String subtitle;
  final String iconAsset;
  final List<Color> gradientColors;

  String? mealName;
  int? calories;

  MealCardData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.gradientColors,
    this.mealName,
    this.calories,
  });
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Placeholder values until backend logic is added.
  int fireCounter = 0;
  DateTime? _lastStreakAwardedDate;
  List<DateTime> _streakDates = [];
  bool _isSavingStreak = false;
  bool _isShowingStreakGainPopup = false;
  bool _isShowingStreakLostPopup = false;
  bool _isFirstStreakEvaluation = true;
  bool _hadReachedGoalToday = false;
  DateTime? _lastGainPopupDate;
  DateTime? _lastLossPopupDate;
  bool _hasEvaluatedLossOnAppOpen = false;
  bool _isHydratingHomeData = false;
  bool _hasPendingGainPopup = false;
  int? _pendingGainPopupCount;

  late final AnimationController _waveController;

  late List<MealCardData> mealCards;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  VoidCallback? _homeProviderListener;

  static const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.deepBlue,
  );

  HomeProvider get _homeProvider => context.read<HomeProvider>();
  UserProvider get _userProvider => context.read<UserProvider>();

  Map<String, dynamic>? get user => _userProvider.user;
  bool get isLoading => _userProvider.isLoading;

  DateTime get _selectedDate => _homeProvider.selectedDate;
  bool get _hasFreshSummaryForSelectedDate {
    final lastSummaryDate = _homeProvider.lastSummaryDate;
    if (lastSummaryDate == null) return false;
    return DateUtils.isSameDay(lastSummaryDate, _selectedDate);
  }

  int get dailyCalories => _homeProvider.dailyCalories;
  int get dailyProtein => _homeProvider.dailyProtein;
  int get dailyFat => _homeProvider.dailyFat;
  int get dailyCarbs => _homeProvider.dailyCarbs;

  int get consumedCalories => _homeProvider.consumedCalories;
  int get consumedProtein => _homeProvider.consumedProtein;
  int get consumedFat => _homeProvider.consumedFat;
  int get consumedCarbs => _homeProvider.consumedCarbs;

  double get dailyWaterGoalL => _homeProvider.dailyWaterGoalL;
  int get consumedWaterMl => _homeProvider.consumedWaterMl;
  DateTime? get lastDrinkTime => _homeProvider.lastDrinkTime;

  @override
  void initState() {
    super.initState();

    _homeProviderListener = () {
      _syncMealCardsFromProvider();
      if (_hasFreshSummaryForSelectedDate) {
        _syncStreakFromCalories(allowAwardToday: !_isHydratingHomeData);
      }
    };
    _homeProvider.addListener(_homeProviderListener!);

    // Hydrate streak immediately from any already-cached user data.
    _syncStreakFromUserProfile();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    mealCards = [
      MealCardData(
        type: 'breakfast',
        title: 'Breakfast',
        subtitle: 'Start your day right',
        iconAsset: 'assets/icons/breakfast.png',
        gradientColors: [
          AppColors.breakfastGradientStart,
          AppColors.breakfastGradientEnd,
        ],
      ),
      MealCardData(
        type: 'lunch',
        title: 'Lunch',
        subtitle: 'Fuel your afternoon',
        iconAsset: 'assets/icons/lunch.png',
        gradientColors: [
          AppColors.lunchGradientStart,
          AppColors.lunchGradientEnd,
        ],
      ),
      MealCardData(
        type: 'snack',
        title: 'Snack',
        subtitle: 'Light bite',
        iconAsset: 'assets/icons/snack.png',
        gradientColors: [
          AppColors.snackGradientStart,
          AppColors.snackGradientEnd,
        ],
      ),
      MealCardData(
        type: 'dinner',
        title: 'Dinner',
        subtitle: 'End your day well',
        iconAsset: 'assets/icons/dinner.png',
        gradientColors: [
          AppColors.dinnerGradientStart,
          AppColors.dinnerGradientEnd,
        ],
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadHomeData();
    });
  }

  @override
  void dispose() {
    if (_homeProviderListener != null) {
      _homeProvider.removeListener(_homeProviderListener!);
    }
    _waveController.dispose();
    super.dispose();
  }

  int get dailyWaterGoalMl => _homeProvider.dailyWaterGoalMl;

  double get _waterProgress {
    if (dailyWaterGoalMl <= 0) return 0;
    return (consumedWaterMl / dailyWaterGoalMl).clamp(0.0, 1.0);
  }

  double get _waterBottleVisualProgress {
    // Keep the measured progress unchanged, but avoid a fully empty-looking bottle.
    if (_waterProgress == 0) return 0.15;
    return _waterProgress;
  }

  void _incrementWater() {
    _addWaterBy(250);
  }

  void _addWaterBy(int amountMl) {
    _homeProvider.addWaterBy(amountMl);
  }

  void _decrementWater() {
    _homeProvider.decrementWaterBy(250);
  }

  String _formatLastDrinkTime(DateTime? time) {
    if (time == null) return '--';
    final t = TimeOfDay.fromDateTime(time);
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get _waterStatus {
    if (consumedWaterMl <= 300) return 'Your bottle is empty, refill it';
    if (consumedWaterMl < dailyWaterGoalMl) return 'Great job, keep going';
    if (consumedWaterMl == dailyWaterGoalMl) return 'Daily water goal achieved';
    return 'You exceeded your water goal today';
  }

  Widget _buildWaterActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.deepBlue),
        ),
      ),
    );
  }

  Widget _buildWaterBottle() {
    return SizedBox(
      width: 76,
      height: 162,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(42),
          color: AppColors.babyBlueLight.withOpacity(0.55),
          border: Border.all(
            color: AppColors.babyBlueDark.withOpacity(0.24),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.94),
              AppColors.lightBlue.withOpacity(0.62),
              AppColors.babyBlueLight.withOpacity(0.46),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(42),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.white.withOpacity(0.52)),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.58),
                        Colors.white.withOpacity(0.14),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 30,
                top: 9,
                bottom: 12,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.55),
                        Colors.white.withOpacity(0.16),
                        Colors.white.withOpacity(0.02),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 40,
                top: 16,
                bottom: 24,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: _waterBottleVisualProgress,
                  ),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedProgress, _) {
                    return FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: animatedProgress,
                      child: AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _WaterWavePainter(
                                  phase: _waveController.value * 2 * math.pi,
                                  primaryColor: AppColors.waterPrimary,
                                  secondaryColor: AppColors.waterSecondary,
                                ),
                              ),
                              CustomPaint(
                                painter: _WaterBubblesPainter(
                                  phase: _waveController.value * 2 * math.pi,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Text(
                  '${(_waterProgress * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadHomeData() async {
    _isHydratingHomeData = true;
    try {
      await _userProvider.fetchUser();
      _syncStreakFromUserProfile();
      _syncTargetsFromUser();
      _evaluateStreakLossOnAppOpen();
      await _homeProvider.fetchDailyMealSummary(date: _selectedDate);
      _syncMealCardsFromProvider();
      _syncStreakFromCalories(allowAwardToday: false);
    } finally {
      _isHydratingHomeData = false;
    }
  }

  void _evaluateStreakLossOnAppOpen() {
    if (_hasEvaluatedLossOnAppOpen) return;
    _hasEvaluatedLossOnAppOpen = true;

    if (!mounted || fireCounter <= 0 || _streakDates.isEmpty) return;

    final today = DateUtils.dateOnly(DateTime.now());
    final sortedDates = _streakDates.map(DateUtils.dateOnly).toList()
      ..sort((a, b) => a.compareTo(b));
    final latest = sortedDates.last;
    final gapFromToday = today.difference(latest).inDays;

    // A missed full day means streak is fully lost.
    if (gapFromToday <= 1) return;

    final missedDay = today.subtract(const Duration(days: 1));

    if (!mounted) return;
    setState(() {
      fireCounter = 0;
      _streakDates = [];
      _lastStreakAwardedDate = null;
      _hadReachedGoalToday = false;
      _isFirstStreakEvaluation = false;
    });

    _syncStreakToServer(streakCount: 0, streakDates: const []);

    if (!DateUtils.isSameDay(_lastLossPopupDate, missedDay)) {
      _lastLossPopupDate = missedDay;
      _showStreakLostPopup();
    }
  }

  void _syncStreakFromUserProfile() {
    final profile = user?['profile'];
    if (profile is! Map) return;
    final profileMap = Map<String, dynamic>.from(profile);

    final int dbCounter = (profileMap['streak_count'] as num?)?.toInt() ?? 0;
    final rawDates = profileMap['streak_dates'];
    final dates = <DateTime>[];

    if (rawDates is List) {
      for (final item in rawDates) {
        final parsed = DateTime.tryParse(item.toString());
        if (parsed == null) continue;
        dates.add(DateUtils.dateOnly(parsed.toLocal()));
      }
    }

    dates.sort((a, b) => a.compareTo(b));
    final uniqueDates = <DateTime>[];
    for (final date in dates) {
      if (uniqueDates.any((d) => DateUtils.isSameDay(d, date))) continue;
      uniqueDates.add(date);
    }

    final newLast = uniqueDates.isEmpty ? null : uniqueDates.last;
    final shouldUpdate =
        dbCounter != fireCounter ||
        !_sameDateLists(uniqueDates, _streakDates) ||
        !DateUtils.isSameDay(newLast, _lastStreakAwardedDate);

    if (!shouldUpdate) return;

    setState(() {
      fireCounter = dbCounter;
      _streakDates = uniqueDates;
      _lastStreakAwardedDate = newLast;
    });
  }

  Future<void> _syncStreakToServer({
    required int streakCount,
    required List<DateTime> streakDates,
  }) async {
    if (_isSavingStreak) return;

    _isSavingStreak = true;
    try {
      await _userProvider.syncStreak(
        streakCount: streakCount,
        streakDates: streakDates,
      );
    } finally {
      _isSavingStreak = false;
    }
  }

  Future<void> _showStreakGainPopup(int newStreakCount) async {
    if (!mounted || _isShowingStreakGainPopup) return;

    _isShowingStreakGainPopup = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'streak-gain',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        pageBuilder: (_, _, _) {
          return Center(
            child: StreakGainPopupCard(streakCount: newStreakCount),
          );
        },
        transitionDuration: const Duration(milliseconds: 240),
        transitionBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          );

          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      _isShowingStreakGainPopup = false;
    }
  }

  bool get _isCurrentHomeRoute => ModalRoute.of(context)?.isCurrent ?? true;

  void _queueGainPopup(int streakCount) {
    _hasPendingGainPopup = true;
    _pendingGainPopupCount = streakCount;
  }

  void _tryShowPendingGainPopup() {
    if (!_hasPendingGainPopup || !mounted || !_isCurrentHomeRoute) return;

    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(_lastGainPopupDate, today)) {
      _hasPendingGainPopup = false;
      _pendingGainPopupCount = null;
      return;
    }

    final streakCount = _pendingGainPopupCount ?? fireCounter;
    _hasPendingGainPopup = false;
    _pendingGainPopupCount = null;
    _lastGainPopupDate = today;
    _showStreakGainPopup(streakCount);
  }

  Future<void> _showStreakLostPopup() async {
    if (!mounted || _isShowingStreakLostPopup) return;

    _isShowingStreakLostPopup = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'streak-lost',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        pageBuilder: (_, _, _) {
          return const Center(child: StreakLostPopupCard());
        },
        transitionDuration: const Duration(milliseconds: 240),
        transitionBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          );

          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      _isShowingStreakLostPopup = false;
    }
  }

  int _calculateConsecutiveStreak(List<DateTime> dates, DateTime today) {
    if (dates.isEmpty) return 0;

    final normalizedToday = DateUtils.dateOnly(today);
    final normalizedDates = dates.map(DateUtils.dateOnly).toList()
      ..sort((a, b) => a.compareTo(b));

    final keys = normalizedDates
        .map((d) => d.toIso8601String().split('T').first)
        .toSet();

    final latest = normalizedDates.last;
    final gapFromToday = normalizedToday.difference(latest).inDays;

    // Lose streak only when a full day is missed.
    if (gapFromToday > 1) return 0;

    int streak = 0;
    DateTime cursor = latest;
    while (keys.contains(cursor.toIso8601String().split('T').first)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  bool _sameDateLists(List<DateTime> a, List<DateTime> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!DateUtils.isSameDay(a[i], b[i])) return false;
    }
    return true;
  }

  void _syncStreakFromCalories({bool allowAwardToday = true}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(_selectedDate);
    if (!DateUtils.isSameDay(selected, today)) return;

    final reachedGoalToday =
        dailyCalories > 0 && consumedCalories >= dailyCalories;

    final updatedDates = _streakDates.map(DateUtils.dateOnly).toList()
      ..sort((a, b) => a.compareTo(b));

    final hasToday = updatedDates.any((d) => DateUtils.isSameDay(d, today));
    final oldCounter = fireCounter;
    final canAwardToday = allowAwardToday && !_hadReachedGoalToday;
    final justCompletedToday = reachedGoalToday && !hasToday && canAwardToday;

    if (justCompletedToday) {
      updatedDates.add(today);
      updatedDates.sort((a, b) => a.compareTo(b));
    } else if (!reachedGoalToday && hasToday) {
      updatedDates.removeWhere((d) => DateUtils.isSameDay(d, today));
    }

    final newCounter = _calculateConsecutiveStreak(updatedDates, today);
    final newLastAwarded = updatedDates.isEmpty ? null : updatedDates.last;

    final hasCounterChanged = newCounter != fireCounter;
    final hasDatesChanged = !_sameDateLists(updatedDates, _streakDates);
    final hasLastAwardedChanged = !DateUtils.isSameDay(
      newLastAwarded,
      _lastStreakAwardedDate,
    );

    if (!hasCounterChanged && !hasDatesChanged && !hasLastAwardedChanged) {
      if (allowAwardToday) {
        _hadReachedGoalToday = reachedGoalToday;
        _isFirstStreakEvaluation = false;
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      fireCounter = newCounter;
      _streakDates = updatedDates;
      _lastStreakAwardedDate = newLastAwarded;
    });

    _syncStreakToServer(streakCount: newCounter, streakDates: updatedDates);

    final awardedToday = DateUtils.isSameDay(newLastAwarded, today);
    final shouldShowGainPopup =
        allowAwardToday &&
        newCounter > oldCounter &&
        awardedToday &&
        !DateUtils.isSameDay(_lastGainPopupDate, today);

    if (allowAwardToday) {
      _hadReachedGoalToday = reachedGoalToday;
      _isFirstStreakEvaluation = false;
    }

    if (shouldShowGainPopup) {
      if (_isCurrentHomeRoute) {
        _lastGainPopupDate = today;
        _showStreakGainPopup(newCounter);
      } else {
        _queueGainPopup(newCounter);
      }
    }
  }

  void _syncMealCardsFromProvider() {
    final consumedMap = _homeProvider.mealConsumedCalories;
    final namesMap = _homeProvider.mealNames;

    if (!mounted) return;
    setState(() {
      for (final meal in mealCards) {
        meal.calories = (consumedMap[meal.type] ?? 0).clamp(0, 999999);
        final mealName = (namesMap[meal.type] ?? '').trim();
        meal.mealName = mealName.isEmpty ? null : mealName;
      }
    });
  }

  void _syncTargetsFromUser() {
    final profile = user?["profile"];
    if (profile == null) return;

    final calories = calculateCalories(profile);
    final macros = calculateMacros(profile, calories);

    _homeProvider.setDailyTargets(
      calories: calories,
      protein: macros["protein"] ?? 0,
      fat: macros["fat"] ?? 0,
      carbs: macros["carbs"] ?? 0,
    );
  }

  Future<void> _onRefresh() async {
    await _loadHomeData();
  }

  int calculateAge(String dateOfBirth) {
    final birthDate = DateTime.parse(dateOfBirth);
    final today = DateTime.now();

    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  Widget _buildMealCard(MealCardData meal) {
    final bool hasMeal =
        meal.mealName != null && meal.mealName!.trim().isNotEmpty;
    final int targetCalories = _mealTargetCalories(meal);
    final int mealCalories = meal.calories ?? 0;
    final int leftCalories = _mealLeftCalories(meal);
    final bool isCompleted =
        hasMeal && targetCalories > 0 && mealCalories >= targetCalories;
    final bool isPartial = hasMeal && !isCompleted;

    return GestureDetector(
      onTap: () => _goToAddMealScreen(meal),
      child: SizedBox(
        width: 131,
        height: 235,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 22,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: meal.gradientColors,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(70),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: meal.gradientColors.last.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      meal.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!hasMeal)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.90),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$targetCalories kcal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.98),
                            ),
                          ),
                        ],
                      ),
                    if (!hasMeal) const SizedBox(height: 8),
                    if (isPartial)
                      Text(
                        meal.mealName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                    if (isPartial) const SizedBox(height: 4),
                    if (isPartial)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remaining',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.90),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$leftCalories kcal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.98),
                            ),
                          ),
                        ],
                      ),
                    if (isCompleted)
                      Text(
                        meal.mealName!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.95),
                          height: 1.25,
                        ),
                      ),
                    const Spacer(),
                    if (isCompleted)
                      Center(
                        child: Text(
                          '$mealCalories kcal',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.98),
                            letterSpacing: -0.2,
                          ),
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 25,
                            color: meal.gradientColors.last,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -15,
              left: -7,
              child: Container(
                width: meal.type == 'snack' ? 98 : 92,
                height: meal.type == 'snack' ? 98 : 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.13),
                ),
              ),
            ),
            Positioned(
              top: meal.type == 'dinner' ? -5 : -15,
              left: -7,
              child: SizedBox(
                width: meal.type == 'snack' ? 96 : 88,
                height: meal.type == 'snack' ? 96 : 88,
                child: Image.asset(meal.iconAsset, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Meals today', style: _sectionTitleStyle),
            const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 238,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mealCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return _buildMealCard(mealCards[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWaterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 30, 14, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(65),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.skyBlue.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 0),
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$consumedWaterMl',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                          height: 1,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const TextSpan(
                        text: ' ml',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepBlue.withOpacity(0.6),
                    ),
                    children: [
                      const TextSpan(text: 'of daily goal '),
                      TextSpan(
                        text: '${dailyWaterGoalL.toStringAsFixed(1)}L',
                        style: const TextStyle(color: AppColors.mediumBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: AppColors.babyBlueLight),
                const SizedBox(height: 50),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: AppColors.deepBlue.withOpacity(0.42),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Last drink ${_formatLastDrinkTime(lastDrinkTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBlue.withOpacity(0.52),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: Image.asset(
                        'assets/icons/bell pink.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) {
                          return const Icon(
                            Icons.notifications_none_rounded,
                            size: 14,
                            color: AppColors.navy,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _waterStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD05E7E),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 162,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildWaterActionButton(
                  icon: Icons.add_rounded,
                  onTap: _incrementWater,
                ),
                const SizedBox(height: 14),
                _buildWaterActionButton(
                  icon: Icons.remove_rounded,
                  onTap: _decrementWater,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildWaterBottle(),
        ],
      ),
    );
  }

  Widget _buildWaterHintBox() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(54, 18, 16, 18),
          decoration: BoxDecoration(
            color: AppColors.lightBlue.withOpacity(0.38),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.babyBlueDark.withOpacity(0.18)),
          ),
          child: Text(
            'Give your body the hydration it needs before lunch to stay energized and support better digestion.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumBlue.withOpacity(0.92),
              height: 1.28,
            ),
          ),
        ),
        Positioned(
          left: 5,
          top: -18,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Image.asset(
              'assets/icons/water.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return Icon(
                  Icons.local_drink_rounded,
                  size: 24,
                  color: AppColors.mediumBlue,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  int calculateCalories(dynamic profile) {
    if (profile == null) return 0;

    final weight = (profile["weight"]?["value"] ?? 0).toDouble();
    final height = (profile["height"]?["value"] ?? 0).toDouble();
    final gender = profile["gender"];
    final activity = profile["activity_level"];
    final goal = profile["goal"];
    final dob = profile["date_of_birth"];

    if (dob == null || dob.toString().isEmpty) return 0;

    final age = calculateAge(dob.toString());
    if (age == 0 || height == 0 || weight == 0) return 0;

    double bmr;

    if (gender == "male") {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }

    double activityFactor = 1.2;

    switch (activity) {
      case "lightly_active":
        activityFactor = 1.375;
        break;
      case "moderately_active":
        activityFactor = 1.55;
        break;
      case "very_active":
        activityFactor = 1.725;
        break;
      case "sedentary":
      default:
        activityFactor = 1.2;
    }

    double calories = bmr * activityFactor;

    if (goal == "lose_weight") {
      calories -= 350;
    } else if (goal == "gain_weight") {
      calories += 300;
    }

    return calories.round();
  }

  Map<String, int> calculateMacros(dynamic profile, int calories) {
    if (profile == null || calories == 0) {
      return {"protein": 0, "fat": 0, "carbs": 0};
    }

    final weight = (profile["weight"]?["value"] ?? 0).toDouble();
    final goal = profile["goal"];

    if (weight == 0) {
      return {"protein": 0, "fat": 0, "carbs": 0};
    }

    double proteinPerKg;
    double fatPercentage;

    switch (goal) {
      case "lose_weight":
        proteinPerKg = 1.6;
        fatPercentage = 0.25;
        break;
      case "gain_weight":
        proteinPerKg = 1.8;
        fatPercentage = 0.25;
        break;
      case "stay_healthy":
      default:
        proteinPerKg = 1.2;
        fatPercentage = 0.30;
        break;
    }

    final proteinGrams = weight * proteinPerKg;
    final proteinCalories = proteinGrams * 4;

    final fatGrams = (calories * fatPercentage) / 9;
    final fatCalories = fatGrams * 9;

    final carbsGrams = (calories - proteinCalories - fatCalories) / 4;

    return {
      "protein": proteinGrams.round(),
      "fat": fatGrams.round(),
      "carbs": carbsGrams.round() < 0 ? 0 : carbsGrams.round(),
    };
  }

  double getProgress(int consumed, int total) {
    if (total <= 0) return 0.0;
    return consumed / total;
  }

  Map<String, double> _mealDistributionForGoal(String? goal) {
    switch (goal) {
      case "lose_weight":
        return {
          "breakfast": 0.30,
          "lunch": 0.40,
          "dinner": 0.20,
          "snack": 0.10,
        };
      case "gain_weight":
        return {
          "breakfast": 0.25,
          "lunch": 0.35,
          "dinner": 0.25,
          "snack": 0.15,
        };
      case "stay_healthy":
      default:
        return {
          "breakfast": 0.30,
          "lunch": 0.35,
          "dinner": 0.25,
          "snack": 0.10,
        };
    }
  }

  double _mealRatio(String mealType) {
    final goal = user?["profile"]?["goal"]?.toString();
    final distribution = _mealDistributionForGoal(goal);
    return distribution[mealType] ?? 0.25;
  }

  int _mealTargetCalories(MealCardData meal) {
    if (dailyCalories <= 0) return 0;
    return (dailyCalories * _mealRatio(meal.type)).round();
  }

  int _mealLeftCalories(MealCardData meal) {
    final target = _mealTargetCalories(meal);
    final consumed = (meal.calories ?? 0).clamp(0, 999999);
    final left = target - consumed;
    return left < 0 ? 0 : left;
  }

  int _mealLeftPercent(MealCardData meal) {
    final target = _mealTargetCalories(meal);
    if (target <= 0) return 0;
    return ((_mealLeftCalories(meal) / target) * 100).round().clamp(0, 100);
  }

  Future<void> _goToAddMealScreen(MealCardData meal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMealManualScreen(
          mealType: meal.type,
          mealTitle: meal.title,
          targetCalories: _mealTargetCalories(meal),
          consumedCalories: (meal.calories ?? 0).clamp(0, 999999),
          mealImageAsset: meal.iconAsset,
          selectedDate: _selectedDate,
          dailyCalorieTarget: dailyCalories,
          dailyProteinTarget: dailyProtein,
          dailyFatTarget: dailyFat,
          dailyCarbsTarget: dailyCarbs,
        ),
      ),
    );

    if (!mounted) return;
    await _homeProvider.fetchDailyMealSummary(date: _selectedDate);
    _syncMealCardsFromProvider();
  }

  String greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  String getInitials(String name) {
    if (name.trim().isEmpty) return "U";

    final parts = name.trim().split(" ");
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? "").trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? "${baseUri.host}:${baseUri.port}"
        : baseUri.host;
    final origin = "${baseUri.scheme}://$authority";

    if (raw.startsWith("/")) {
      return "$origin$raw";
    }

    return "$origin/$raw";
  }

  String? _extractUserImageUrl() {
    final profile = user?["profile"] as Map<String, dynamic>?;
    final rawImageValue =
        profile?["image_url"] ??
        profile?["image"] ??
        profile?["imageUrl"] ??
        user?["image_url"] ??
        user?["image"] ??
        user?["imageUrl"];

    return _resolveImageUrl(rawImageValue);
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    await authProvider.logout();
    if (!mounted) return;

    userProvider.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
    );
  }

  void _goToAboutUs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutUsPage()),
    );
  }

  void _showAddDishDialog([MealCardData? meal]) {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final fatController = TextEditingController();
    final carbsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(meal != null ? 'Add ${meal.title}' : 'Add Dish'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Dish Name'),
                ),
                TextField(
                  controller: caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories'),
                ),
                TextField(
                  controller: proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
                TextField(
                  controller: fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
                TextField(
                  controller: carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final dishName = nameController.text.trim();
                final calories = int.tryParse(caloriesController.text.trim());
                final protein = int.tryParse(proteinController.text.trim());
                final fat = int.tryParse(fatController.text.trim());
                final carbs = int.tryParse(carbsController.text.trim());

                if (dishName.isEmpty ||
                    calories == null ||
                    protein == null ||
                    fat == null ||
                    carbs == null ||
                    calories < 0 ||
                    protein < 0 ||
                    fat < 0 ||
                    carbs < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid values for all fields'),
                    ),
                  );
                  return;
                }

                setState(() {
                  if (meal != null) {
                    if ((meal.mealName ?? '').trim().isEmpty) {
                      meal.mealName = dishName;
                    } else {
                      meal.mealName = '${meal.mealName}\n$dishName';
                    }
                    meal.calories = (meal.calories ?? 0) + calories;
                  }
                });

                _homeProvider.addConsumedMacros(
                  calories: calories,
                  protein: protein,
                  fat: fat,
                  carbs: carbs,
                );

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $dishName successfully')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget buildCaloriesCard() {
    final int goalCalories = dailyCalories < 0 ? 0 : dailyCalories;
    final int eatenCalories = consumedCalories < 0 ? 0 : consumedCalories;
    final int leftCalories = (goalCalories - eatenCalories).clamp(0, 999999);

    final double progress = goalCalories == 0
        ? 0
        : (eatenCalories / goalCalories).clamp(0.0, 1.0);

    // Macro calculations
    final carbsProgress = dailyCarbs == 0
        ? 0.0
        : (consumedCarbs / dailyCarbs).clamp(0.0, 1.0);
    final proteinProgress = dailyProtein == 0
        ? 0.0
        : (consumedProtein / dailyProtein).clamp(0.0, 1.0);
    final fatProgress = dailyFat == 0
        ? 0.0
        : (consumedFat / dailyFat).clamp(0.0, 1.0);

    final carbsLeft = (dailyCarbs - consumedCarbs).clamp(0, 999999);
    final proteinLeft = (dailyProtein - consumedProtein).clamp(0, 999999);
    final fatLeft = (dailyFat - consumedFat).clamp(0, 999999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(65),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.skyBlue.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 0),
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          // Main calories section
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCalorieRow(
                      title: "Eaten",
                      value: eatenCalories,
                      unit: "Kcal",
                      lineColor: AppColors.calorieEatenLine,
                      iconAssetPath: 'assets/icons/grapes.png',
                    ),
                    const SizedBox(height: 18),
                    _buildCalorieRow(
                      title: "Calorie Goal",
                      value: goalCalories,
                      unit: "Kcal",
                      lineColor: AppColors.calorieGoalLine,
                      iconAssetPath: 'assets/icons/fire pink.png',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(118, 118),
                      painter: _CalorieRingPainter(
                        progress: progress,
                        trackColor: AppColors.babyBlueLight,
                        progressStartColor: AppColors.calorieRingGradientStart,
                        progressEndColor: AppColors.calorieRingGradientEnd,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$leftCalories",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Kcal left",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Divider line
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          // Macro summary row
          Row(
            children: [
              Expanded(
                child: _buildMacroItem(
                  label: "Carbs",
                  progress: carbsProgress,
                  remaining: carbsLeft,
                  color: AppColors.macroCarbs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroItem(
                  label: "Protein",
                  progress: proteinProgress,
                  remaining: proteinLeft,
                  color: AppColors.macroProtein,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroItem(
                  label: "Fat",
                  progress: fatProgress,
                  remaining: fatLeft,
                  color: AppColors.macroFat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieRow({
    required String title,
    required int value,
    required String unit,
    required Color lineColor,
    required String iconAssetPath,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 56,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Image.asset(iconAssetPath, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            "$value",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMacroItem({
    required String label,
    required double progress,
    required int remaining,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              // Background track
              Container(height: 7, color: Colors.grey.shade100),
              // Progress bar with gradient
              FractionallySizedBox(
                widthFactor: progress,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      colors: [color.withOpacity(0.4), color],
                    ).createShader(rect);
                  },
                  child: Container(height: 8.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${remaining}g left",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _weekdayLetter(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mo';
      case DateTime.tuesday:
        return 'Tu';
      case DateTime.wednesday:
        return 'We';
      case DateTime.thursday:
        return 'Th';
      case DateTime.friday:
        return 'Fr';
      case DateTime.saturday:
        return 'Sa';
      case DateTime.sunday:
      default:
        return 'Su';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _showDateHistoryPicker() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = _selectedDate.isAfter(today) ? today : _selectedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: today,
      helpText: 'Select date',
    );

    if (pickedDate == null) return;

    _homeProvider.setSelectedDate(pickedDate);
    await _homeProvider.fetchDailyMealSummary(date: pickedDate);
    _syncMealCardsFromProvider();
  }

  Widget _buildDateHistoryButton() {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: _showDateHistoryPicker,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 18,
        icon: Icon(
          Icons.calendar_month_rounded,
          color: AppColors.deepBlue.withValues(alpha: 0.9),
          size: 21,
        ),
        tooltip: 'All previous dates',
      ),
    );
  }

  Widget _buildDaysStrip() {
    final today = DateUtils.dateOnly(DateTime.now());
    final anchorDate = _selectedDate.isAfter(today) ? today : _selectedDate;
    final dates = List.generate(
      7,
      (index) => anchorDate.subtract(Duration(days: 3 - index)),
    );

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isActive = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, today);

          return GestureDetector(
            onTap: () async {
              _homeProvider.setSelectedDate(date);
              await _homeProvider.fetchDailyMealSummary(date: date);
              _syncMealCardsFromProvider();
            },
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: isActive ? 1.0 : 0.95,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 66,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.lightBlue.withValues(alpha: 0.35)
                      : AppColors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isActive
                        ? AppColors.navy.withValues(alpha: 0.30)
                        : AppColors.dark.withValues(alpha: 0.06),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dark.withValues(alpha: 0.03),
                      blurRadius: 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: isActive ? 0.30 : 0.48),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isToday)
                        Text(
                          'today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepBlue.withValues(alpha: 0.34),
                            letterSpacing: 0.4,
                          ),
                        ),
                      if (isToday) const SizedBox(height: 2),
                      if (!isToday)
                        Text(
                          _weekdayLetter(date.weekday),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.navy
                                : AppColors.dark.withValues(alpha: 0.66),
                          ),
                        ),
                      SizedBox(height: isToday ? 4 : 6),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isActive
                              ? AppColors.navy
                              : AppColors.dark.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakFireBadge() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showFireStreakDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.babyBlueLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Image.asset(
                  'assets/icons/flame.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return const Icon(
                      Icons.local_fire_department_rounded,
                      size: 20,
                      color: AppColors.fatOrange,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$fireCounter',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFireStreakDialog() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(_selectedDate);
    final isGoalReached =
        DateUtils.isSameDay(today, selected) &&
        dailyCalories > 0 &&
        consumedCalories >= dailyCalories;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: FireStreakDialogCard(
          streakCount: fireCounter,
          selectedDate: today,
          isGoalReached: isGoalReached,
          streakDates: _streakDates,
        ),
      ),
    );
  }

  Widget buildMiniDetailCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.blueGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPlaceholderButton() {
    return Tooltip(
      message: 'Chat (Coming Soon)',
      child: Material(
        color: AppColors.deepBlue,
        elevation: 7,
        shadowColor: AppColors.navy.withValues(alpha: 0.30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.lightBlue.withValues(alpha: 0.48),
            width: 1.1,
          ),
        ),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(18),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddDishButton() {
    return FloatingActionButton.extended(
      onPressed: _showAddDishDialog,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 7,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'Add Dish',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<UserProvider>();
    context.watch<HomeProvider>();

    if (_hasPendingGainPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryShowPendingGainPopup();
      });
    }

    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.royalBlue),
        ),
      );
    }

    final userName = user?["name"] ?? "User";
    final userImageUrl = _extractUserImageUrl();

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: AppColors.background,
      endDrawer: AppDrawer(
        user: user,
        onProfileTap: _goToProfile,
        onLogoutTap: _logout,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _goToProfile,
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy, width: 2.2),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.babyBlueLight,
                        backgroundImage: userImageUrl != null
                            ? NetworkImage(userImageUrl)
                            : null,
                        child: userImageUrl == null
                            ? Text(
                                getInitials(userName),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepBlue,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.blueGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStreakFireBadge(),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.deepBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: _buildDateHistoryButton(),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 4),
                                child: _buildDaysStrip(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Your Progress",
                              style: _sectionTitleStyle,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MealHistoryScreen(),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const Text(
                                    "Details",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: AppColors.navy,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        buildCaloriesCard(),
                        const SizedBox(height: 24),
                        _buildMealsSection(),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('water', style: _sectionTitleStyle),
                        ),
                        const SizedBox(height: 12),
                        _buildWaterCard(),
                        const SizedBox(height: 20),
                        _buildWaterHintBox(),
                        const SizedBox(height: 50),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildChatPlaceholderButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        selectedDate: _selectedDate,
        dailyCalories: dailyCalories,
        goal: user?["profile"]?["goal"]?.toString(),
        mealConsumedCalories: _homeProvider.mealConsumedCalories,
        consumedWaterMl: consumedWaterMl,
        dailyWaterGoalMl: dailyWaterGoalMl,
        onAddWaterTap: _addWaterBy,
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressStartColor;
  final Color progressEndColor;

  _CalorieRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressStartColor,
    required this.progressEndColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double trackStrokeWidth = 8.0;
    const double progressStrokeWidth = 12.0;
    const double glowStrokeWidth = 11.0;
    const double blurSigma = 8.0;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxStroke = math.max(glowStrokeWidth, progressStrokeWidth);
    final double radius =
        (math.min(size.width, size.height) / 2) - (maxStroke / 2);

    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    const double startAngle = -math.pi / 2;
    final double safeProgress = progress.clamp(0.0, 1.0);
    final double sweepAngle = 2 * math.pi * safeProgress;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint progressPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [progressStartColor, progressEndColor],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (safeProgress > 0) {
      final Paint glowPaint = Paint()
        ..color = progressEndColor.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowStrokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, blurSigma);

      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

      final double endAngle = startAngle + sweepAngle;
      final Offset dotCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final Paint dotPaint = Paint()..color = progressEndColor;
      canvas.drawCircle(dotCenter, progressStrokeWidth * 0.5, dotPaint);

      final Paint innerDotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(dotCenter, progressStrokeWidth * 0.25, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressStartColor != progressStartColor ||
        oldDelegate.progressEndColor != progressEndColor;
  }
}

class _WaterWavePainter extends CustomPainter {
  final double phase;
  final Color primaryColor;
  final Color secondaryColor;

  _WaterWavePainter({
    required this.phase,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final double amplitude = math.min(7, size.height * 0.10);
    final double baseY = size.height * 0.32;
    final double safeWidth = size.width == 0 ? 1 : size.width;

    final Paint backPaint = Paint()
      ..color = secondaryColor.withOpacity(0.75)
      ..style = PaintingStyle.fill;
    final Paint frontPaint = Paint()
      ..color = primaryColor.withOpacity(0.93)
      ..style = PaintingStyle.fill;

    final Path backWave = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final double y =
          baseY + amplitude * math.sin((x / safeWidth) * 2 * math.pi + phase);
      backWave.lineTo(x, y);
    }
    backWave
      ..lineTo(size.width, size.height)
      ..close();

    final Path frontWave = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final double y =
          baseY +
          amplitude *
              0.65 *
              math.sin((x / safeWidth) * 2 * math.pi - (phase * 1.1));
      frontWave.lineTo(x, y);
    }
    frontWave
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(backWave, backPaint);
    canvas.drawPath(frontWave, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class _WaterBubblesPainter extends CustomPainter {
  final double phase;

  _WaterBubblesPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final List<double> bubbleXFactors = [0.18, 0.33, 0.52, 0.71, 0.84];
    final List<double> bubbleBaseY = [0.84, 0.68, 0.92, 0.76, 0.60];
    final List<double> bubbleRadius = [1.6, 2.2, 1.8, 2.6, 1.4];

    for (int i = 0; i < bubbleXFactors.length; i++) {
      final double x = size.width * bubbleXFactors[i];
      final double drift = math.sin(phase + (i * 0.9)) * 1.2;
      final double lift = math.cos(phase * 0.85 + i) * 2.4;
      final double y = (size.height * bubbleBaseY[i]) - lift;
      canvas.drawCircle(Offset(x + drift, y), bubbleRadius[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterBubblesPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
