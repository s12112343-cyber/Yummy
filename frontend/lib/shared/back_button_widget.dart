import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final bool showBorder;

  const AppBackButton({
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
    this.backgroundColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap ?? () => Navigator.pop(context),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: showBorder
              ? Border.all(color: AppColors.dark.withOpacity(0.08))
              : null,
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.navy,
        ),
      ),
    );
  }
}