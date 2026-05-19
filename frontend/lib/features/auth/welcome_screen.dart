import 'package:flutter/material.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/app_background.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      lottieAsset: 'assets/lottie/food calories tracker.json',
      title: 'Smart Calorie Tracking',
      subtitle:
          'Track your meals with AI-powered calorie estimation and clear daily insights.',
    ),
    _OnboardingItem(
      lottieAsset: 'assets/lottie/Food Choice.json',
      title: 'Ingredient-Based Suggestions',
      subtitle:
          'Not sure what to cook? Enter your ingredients and get practical meal ideas instantly.',
    ),
    _OnboardingItem(
      lottieAsset: 'assets/lottie/Cooking.json',
      title: 'Healthy Homemade Marketplace',
      subtitle:
          'Discover nutritious home-cooked meals prepared with care by trusted local cooks.',
    ),
    _OnboardingItem(
      lottieAsset: 'assets/lottie/diet.json',
      title: 'Your Healthy Journey Starts Here',
      subtitle:
          'Build better habits, stay consistent, and reach your goals with confidence.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: 40,
                        child: Transform.translate(
                          offset: const Offset(0, -55),
                          child: Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _items.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentIndex = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return Transform.translate(
                                      offset: const Offset(0, 22),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.translate(
                                            offset: const Offset(0, -4),
                                            child: SizedBox(
                                              height: 330,
                                              child: Lottie.asset(
                                                item.lottieAsset,
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        size: 80,
                                                        color:
                                                            AppColors.deepBlue,
                                                      );
                                                    },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 22),
                                          Text(
                                            item.title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            item.subtitle,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              height: 1.4,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.dark.withValues(
                                                alpha: 0.68,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_items.length, (
                                    index,
                                  ) {
                                    final isActive = index == _currentIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: isActive ? 24 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppColors.navy
                                            : AppColors.navy.withValues(
                                                alpha: 0.25,
                                              ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_currentIndex == _items.length - 1)
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _goToLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.navy,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Let's Start",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.navy,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_currentIndex != _items.length - 1)
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: TextButton(
                            onPressed: _goToLogin,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Skip'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String lottieAsset;
  final String title;
  final String subtitle;

  const _OnboardingItem({
    required this.lottieAsset,
    required this.title,
    required this.subtitle,
  });
}
