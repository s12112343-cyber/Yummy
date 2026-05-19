import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_colors.dart';

class StreakGainPopupCard extends StatefulWidget {
  final int streakCount;

  const StreakGainPopupCard({super.key, required this.streakCount});

  @override
  State<StreakGainPopupCard> createState() => _StreakGainPopupCardState();
}

class _StreakGainPopupCardState extends State<StreakGainPopupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
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
            width: 228,
            height: 228,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.babyBlueLight, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Lottie.asset(
                    'assets/lottie/Fire animation.json',
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 4),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.08).animate(pulse),
                  child: const Text(
                    '+1',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.fatOrange,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Streak Increased',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Now ${widget.streakCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blueGray,
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
