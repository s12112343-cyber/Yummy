import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlassTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextAlign textAlign;
  final bool obscureText;
  final String? Function(String?)? validator;
  final IconData prefixIcon;
  final Widget? suffix;
  final AlignmentGeometry labelAlignment;

  const GlassTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.prefixIcon,
    this.textAlign = TextAlign.start,
    this.obscureText = false,
    this.validator,
    this.suffix,
    this.labelAlignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);

    return FormField<String>(
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.trim().isNotEmpty) ...[
              Align(
                alignment: labelAlignment,
                child: Text(
                  label,
                  textAlign: textAlign,
                  style: const TextStyle(
                    color: AppColors.labelGray, // رمادي فاتح
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                // ✅ زجاجي أقوى
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: radius,

                    // ✅ شفافية + تدرج خفيف (Glass)
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.42),
                        Colors.white.withOpacity(0.16),
                      ],
                    ),

                    // ✅ إذا غلط: إطار أحمر فقط بدون نص
                    border: Border.all(
                      color: hasError
                          ? Colors.red.withOpacity(0.85)
                          : Colors.white.withOpacity(0.65),
                      width: hasError ? 1.6 : 1.2,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    obscureText: obscureText,
                    textAlign: textAlign,

                    // مهم: يخلي الـ FormField يعرف التغيير ويعمل validate
                    onChanged: (v) => state.didChange(v),

                    style: const TextStyle(
                      color: AppColors.darkBlue,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                    decoration: InputDecoration(
                      hintText: hint, // ✅ المثال داخل الحقل
                      hintStyle: TextStyle(
                        color: AppColors.dark.withOpacity(0.40),
                        fontWeight: FontWeight.w700,
                      ),
                      prefixIcon: Icon(
                        prefixIcon,
                        color: AppColors.darkBlue.withOpacity(0.55),
                        size: 20,
                      ),
                      suffixIcon: suffix == null
                          ? null
                          : IconTheme(
                              data: IconThemeData(
                                color: AppColors.darkBlue.withOpacity(0.50),
                              ),
                              child: suffix!,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
