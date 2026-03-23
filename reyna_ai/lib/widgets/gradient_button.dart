// lib/widgets/gradient_button.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  
  const GradientButton({
    super.key, 
    required this.label, 
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: onTap != null && !isLoading
              ? [AppColors.primary, AppColors.secondary]
              : [AppColors.outline, AppColors.outlineVariant],
          ),
          boxShadow: onTap != null && !isLoading
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        ),
        child: TextButton(
          onPressed: onTap != null && !isLoading ? onTap : null,
          child: isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: AppColors.onPrimary,
                ),
              ),
        ),
      ),
    );
  }
}
