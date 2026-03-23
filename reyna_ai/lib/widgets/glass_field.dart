// lib/widgets/glass_field.dart
// Glassmorphic translucent input field — shared across auth screens
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const GlassField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: AppColors.primary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          cursorColor: AppColors.primary,
          style: const TextStyle(
              fontFamily: 'Space Grotesk',
              color: AppColors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5),
          decoration: InputDecoration(
            filled: true,
            // Glassmorphic: translucent indigo tint
            fillColor: AppColors.primary.withOpacity(0.08),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.25), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.25), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primaryContainer, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle: const TextStyle(
                fontFamily: 'Space Grotesk',
                color: AppColors.error,
                fontSize: 10,
                letterSpacing: 1),
            hintStyle: TextStyle(
                fontFamily: 'Space Grotesk',
                color: AppColors.outlineVariant,
                fontSize: 13,
                letterSpacing: 1),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
