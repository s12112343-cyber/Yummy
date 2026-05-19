import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_colors.dart';

class StreakLostPopupCard extends StatefulWidget {
  const StreakLostPopupCard({super.key});

  @override
  State<StreakLostPopupCard> createState() => _StreakLostPopupCardState();
}

class _StreakLostPopupCardState extends State<StreakLostPopupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Container(
            width: 212,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.babyBlueLight, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Lottie.asset(
                    'assets/lottie/Sandy Loading.json',
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 6),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.06).animate(pulse),
                  child: const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepBlue,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Streak Lost',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A full day passed without reaching your goal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blueGray,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.babyBlueLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.deepBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
