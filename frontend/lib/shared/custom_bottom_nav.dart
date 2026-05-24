import 'package:flutter/material.dart';
import 'package:frontend/features/screen/page_recipe_screen/recipes_page.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../core/providers/home_provider.dart';
import '../../core/theme/app_colors.dart';
import '../features/add_meal/add_meal_screen.dart';
import '../../features/home/home_screen.dart';
import '../features/screen/page_cook_screen/home_cooks_screen.dart';
import '../features/posts/post_screen.dart';

class NavItemData {
  final IconData icon;
  final String label;

  const NavItemData({required this.icon, required this.label});
}

class _QuickAddOption {
  final String mealType;
  final String label;
  final String imageAsset;
  final List<Color> gradient;
  final Color plusColor;
  final String calorieStatus;
  final bool isOver;
  final int targetCalories;
  final int consumedCalories;

  const _QuickAddOption({
    required this.mealType,
    required this.label,
    required this.imageAsset,
    required this.gradient,
    required this.plusColor,
    required this.calorieStatus,
    required this.isOver,
    required this.targetCalories,
    required this.consumedCalories,
  });
}

class _BottomNavNotchClipper extends CustomClipper<Path> {
  const _BottomNavNotchClipper();

  @override
  Path getClip(Size size) {
    const double cornerRadius = 28;
    const double notchWidth = 88;
    const double notchDepth = 000;
    final double centerX = size.width / 2;

    final path = Path()
      ..moveTo(0, cornerRadius)
      ..quadraticBezierTo(0, 0, cornerRadius, 0)
      ..lineTo(centerX - (notchWidth / 2), 0)
      ..quadraticBezierTo(centerX, notchDepth, centerX + (notchWidth / 2), 0)
      ..lineTo(size.width - cornerRadius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, cornerRadius)
      ..lineTo(size.width, size.height - cornerRadius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - cornerRadius,
        size.height,
      )
      ..lineTo(cornerRadius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - cornerRadius)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final DateTime? selectedDate;
  final int? dailyCalories;
  final String? goal;
  final Map<String, int>? mealConsumedCalories;
  final int? consumedWaterMl;
  final int? dailyWaterGoalMl;
  final ValueChanged<int>? onAddWaterTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.selectedDate,
    this.dailyCalories,
    this.goal,
    this.mealConsumedCalories,
    this.consumedWaterMl,
    this.dailyWaterGoalMl,
    this.onAddWaterTap,
  });

  Color _lighten(Color color, [double amount = 0.72]) {
    return Color.alphaBlend(Colors.white.withValues(alpha: amount), color);
  }

  Map<String, double> _mealDistributionForGoal(String? goalValue) {
    switch (goalValue) {
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

  String _mealCaloriesStatus(String mealType) {
    final totalCalories = dailyCalories ?? 0;
    if (totalCalories <= 0) return 'No goal yet';

    final distribution = _mealDistributionForGoal(goal);
    final ratio = distribution[mealType] ?? 0.25;
    final targetCalories = (totalCalories * ratio).round();
    final consumedCalories = (mealConsumedCalories?[mealType] ?? 0).clamp(
      0,
      999999,
    );
    final diff = targetCalories - consumedCalories;

    if (diff >= 0) {
      return '$diff kcal left';
    }
    return '${diff.abs()} kcal over';
  }

  bool _isMealCaloriesOver(String mealType) {
    final totalCalories = dailyCalories ?? 0;
    if (totalCalories <= 0) return false;

    final distribution = _mealDistributionForGoal(goal);
    final ratio = distribution[mealType] ?? 0.25;
    final targetCalories = (totalCalories * ratio).round();
    final consumedCalories = (mealConsumedCalories?[mealType] ?? 0).clamp(
      0,
      999999,
    );

    return consumedCalories > targetCalories;
  }

  int _mealTargetCalories(String mealType) {
    final totalCalories = dailyCalories ?? 0;
    if (totalCalories <= 0) return 0;

    final distribution = _mealDistributionForGoal(goal);
    final ratio = distribution[mealType] ?? 0.25;
    return (totalCalories * ratio).round();
  }

  int _mealConsumedCalories(String mealType) {
    return (mealConsumedCalories?[mealType] ?? 0).clamp(0, 999999);
  }

  static const List<NavItemData> items = [
    NavItemData(icon: Icons.home_rounded, label: "Home"),
    NavItemData(icon: Icons.storefront_rounded, label: "Store"),
    NavItemData(icon: Icons.add, label: "Add"),
    NavItemData(icon: Icons.menu_book_rounded, label: "Recipe"),
    NavItemData(icon: Icons.dynamic_feed_rounded, label: "Posts"),
  ];

  void _handleTap(BuildContext context, int index) {
    if (index == 2) {
      _showAddMealOptions(context);
      return;
    }

    if (index == currentIndex) return;

    Widget page;

    switch (index) {
      case 0:
        page = const HomeScreen();
        break;
      case 1:
        page = const HomeCooksScreen();
        break;
      case 3:
        page = const RecipesPage();
        break;
      case 4:
        page = const PostScreen();
        break;
      default:
        page = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: page),
      ),
    );
  }

  void _showAddMealOptions(BuildContext parentContext) {
    int currentWater = consumedWaterMl ?? 0;
    final int waterGoal = dailyWaterGoalMl ?? 0;
    int selectedWaterAddAmount = 250;

    final options = [
      _QuickAddOption(
        mealType: 'breakfast',
        label: 'Breakfast',
        imageAsset: 'assets/icons/breakfast.png',
        gradient: [
          _lighten(AppColors.breakfastGradientStart),
          _lighten(AppColors.breakfastGradientEnd),
        ],
        plusColor: AppColors.breakfastGradientEnd,
        calorieStatus: _mealCaloriesStatus('breakfast'),
        isOver: _isMealCaloriesOver('breakfast'),
        targetCalories: _mealTargetCalories('breakfast'),
        consumedCalories: _mealConsumedCalories('breakfast'),
      ),
      _QuickAddOption(
        mealType: 'lunch',
        label: 'Lunch',
        imageAsset: 'assets/icons/lunch.png',
        gradient: [
          _lighten(AppColors.lunchGradientStart),
          _lighten(AppColors.lunchGradientEnd),
        ],
        plusColor: AppColors.lunchGradientEnd,
        calorieStatus: _mealCaloriesStatus('lunch'),
        isOver: _isMealCaloriesOver('lunch'),
        targetCalories: _mealTargetCalories('lunch'),
        consumedCalories: _mealConsumedCalories('lunch'),
      ),
      _QuickAddOption(
        mealType: 'snack',
        label: 'Snack',
        imageAsset: 'assets/icons/snack.png',
        gradient: [
          _lighten(AppColors.snackGradientStart),
          _lighten(AppColors.snackGradientEnd),
        ],
        plusColor: AppColors.snackGradientEnd,
        calorieStatus: _mealCaloriesStatus('snack'),
        isOver: _isMealCaloriesOver('snack'),
        targetCalories: _mealTargetCalories('snack'),
        consumedCalories: _mealConsumedCalories('snack'),
      ),
      _QuickAddOption(
        mealType: 'dinner',
        label: 'Dinner',
        imageAsset: 'assets/icons/dinner.png',
        gradient: [
          _lighten(AppColors.dinnerGradientStart),
          _lighten(AppColors.dinnerGradientEnd),
        ],
        plusColor: AppColors.dinnerGradientEnd,
        calorieStatus: _mealCaloriesStatus('dinner'),
        isOver: _isMealCaloriesOver('dinner'),
        targetCalories: _mealTargetCalories('dinner'),
        consumedCalories: _mealConsumedCalories('dinner'),
      ),
    ];

    showModalBottomSheet<void>(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool showMealCards = true;
        int mealLottiePlayId = 0;
        int waterLottiePlayId = 0;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 26),
                    child: Transform.scale(
                      scale: 0.97 + (0.03 * value),
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepBlue.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.babyBlue,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7ECF1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.dark.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildAddTypeToggle(
                              title: 'Add Meal',
                              lottieAsset: 'assets/lottie/add meale.json',
                              lottiePlayId: mealLottiePlayId,
                              isActive: showMealCards,
                              onTap: () {
                                setSheetState(() {
                                  showMealCards = true;
                                  mealLottiePlayId++;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildAddTypeToggle(
                              title: 'Add Water',
                              lottieAsset: 'assets/lottie/add water.json',
                              lottiePlayId: waterLottiePlayId,
                              isActive: !showMealCards,
                              onTap: () {
                                setSheetState(() {
                                  showMealCards = false;
                                  waterLottiePlayId++;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (showMealCards)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: options.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.35,
                            ),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          return _buildQuickAddSquare(
                            label: option.label,
                            gradient: option.gradient,
                            plusColor: option.plusColor,
                            calorieStatus: option.calorieStatus,
                            isOver: option.isOver,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(parentContext).push(
                                MaterialPageRoute(
                                  builder: (_) => AddMealManualScreen(
                                    mealType: option.mealType,
                                    mealTitle: option.label,
                                    targetCalories: option.targetCalories,
                                    consumedCalories: option.consumedCalories,
                                    mealImageAsset: option.imageAsset,
                                    selectedDate: selectedDate,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      )
                    else
                      _buildAddWaterCard(
                        currentWaterMl: currentWater,
                        dailyGoalMl: waterGoal,
                        selectedAmount: selectedWaterAddAmount,
                        onAddWater: (amount) {
                          onAddWaterTap?.call(amount);
                          // Attempt to refresh provider-backed summary so Home reflects changes immediately.
                          try {
                            Provider.of<HomeProvider>(
                              parentContext,
                              listen: false,
                            ).fetchDailyMealSummary();
                          } catch (_) {}

                          setSheetState(() {
                            selectedWaterAddAmount = amount;
                            currentWater += amount;
                          });
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddTypeToggle({
    required String title,
    required String lottieAsset,
    required int lottiePlayId,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(14);

    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.lightBlue.withValues(alpha: 0.35)
              : AppColors.white.withValues(alpha: 0.75),
          borderRadius: radius,
          border: Border.all(
            color: isActive
                ? AppColors.navy.withValues(alpha: 0.30)
                : AppColors.dark.withValues(alpha: 0.06),
          ),
        ),
        child: _buildAddTypeToggleContent(
          title: title,
          lottieAsset: lottieAsset,
          lottiePlayId: lottiePlayId,
          isActive: isActive,
        ),
      ),
    );
  }

  Widget _buildAddTypeToggleContent({
    required String title,
    required String lottieAsset,
    required int lottiePlayId,
    required bool isActive,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Lottie.asset(
            lottieAsset,
            key: ValueKey('$lottieAsset-$lottiePlayId'),
            fit: BoxFit.contain,
            repeat: false,
            animate: lottiePlayId > 0,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isActive
                ? AppColors.navy
                : AppColors.dark.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildAddWaterCard({
    required int currentWaterMl,
    required int dailyGoalMl,
    required int selectedAmount,
    required ValueChanged<int> onAddWater,
  }) {
    final bool isOverDailyGoal =
        dailyGoalMl > 0 && currentWaterMl > dailyGoalMl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.babyBlueLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mediumBlue, width: 1.2),
      ),
      child: Column(
        children: [
          if (isOverDailyGoal)
            Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: Image.asset(
                      'assets/icons/bell pink.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.notifications_none_rounded,
                          size: 14,
                          color: Color(0xFFD05E7E),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Over your daily goal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD05E7E),
                    ),
                  ),
                ],
              ),
            ),
          if (isOverDailyGoal) const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
                child: Image.asset(
                  'assets/icons/water.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.local_drink_rounded,
                      color: AppColors.mediumBlue,
                      size: 20,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Water',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dailyGoalMl > 0
                          ? '$currentWaterMl ml of $dailyGoalMl ml'
                          : '$currentWaterMl ml consumed',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blueGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildWaterAmountButton(
                  label: '+50',
                  isSelected: selectedAmount == 50,
                  onTap: () => onAddWater(50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWaterAmountButton(
                  label: '+100',
                  isSelected: selectedAmount == 100,
                  onTap: () => onAddWater(100),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWaterAmountButton(
                  label: '+250',
                  isSelected: selectedAmount == 250,
                  onTap: () => onAddWater(250),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterAmountButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      scale: isSelected ? 1.04 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.lightBlue.withValues(alpha: 0.45)
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.mediumBlue
                  : AppColors.mediumBlue.withValues(alpha: 0.4),
              width: isSelected ? 1.3 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.mediumBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddSquare({
    required String label,
    required List<Color> gradient,
    required Color plusColor,
    required String calorieStatus,
    required bool isOver,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: plusColor, size: 22),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.deepBlue,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              calorieStatus,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isOver
                    ? Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.30),
                        AppColors.red,
                      )
                    : AppColors.blueGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLabel(String label) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Text(
        label,
        key: ValueKey<String>(label),
        textAlign: TextAlign.center,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }

  Widget _buildNormalItem(
    BuildContext context, {
    required int index,
    required NavItemData item,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleTap(context, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.babyBlueLight : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isActive ? AppColors.navy : AppColors.labelGray,
                ),
                const SizedBox(height: 4),
                if (isActive) _buildActiveLabel(item.label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddItem(BuildContext context, bool isActive) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleTap(context, 2),
        child: Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: isActive ? 50 : 46,
                height: isActive ? 50 : 46,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  color: AppColors.white,
                  size: isActive ? 28 : 26,
                ),
              ),
              const SizedBox(height: 4),
              if (isActive) _buildActiveLabel("Add"),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: PhysicalShape(
          clipper: const _BottomNavNotchClipper(),
          color: AppColors.white,
          shadowColor: AppColors.royalBlue.withOpacity(0.9),
          elevation: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isActive = index == currentIndex;

                if (index == 2) {
                  return _buildAddItem(context, isActive);
                }

                return _buildNormalItem(
                  context,
                  index: index,
                  item: item,
                  isActive: isActive,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class DummyNavScreen extends StatelessWidget {
  final String title;
  final int currentIndex;

  const DummyNavScreen({
    super.key,
    required this.title,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.babyBlueLight),
          ),
          child: Text(
            "$title page later",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(currentIndex: currentIndex),
    );
  }
}
