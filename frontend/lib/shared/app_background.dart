import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.royalBlue.withOpacity(0.15),
            AppColors.lightBlue.withOpacity(0.12),
            AppColors.babyBlueLight.withOpacity(0.08),
            AppColors.background,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: child,
    );
  }
}
