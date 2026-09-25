import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Field putih radius 16 tanpa border (gaya iOS).
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.onTap,
    this.onChanged,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: obscure ? 1 : maxLines,
      onTap: onTap,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: readOnly ? AppColors.track : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
