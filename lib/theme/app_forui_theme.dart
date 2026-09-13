import 'package:catat_uang_app/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Tema forui project ini, dipetakan dari [AppColors] yang sudah ada.
///
/// Semua widget di lib/widgets/ mengandalkan tema ini untuk warna —
/// jangan override warna per-widget kecuali benar-benar perlu varian
/// khusus, supaya satu perubahan di AppColors otomatis menyebar ke
/// semua komponen forui.
final FThemeData appForuiTheme = FThemes.zinc.light.copyWith(
  colors: FThemes.zinc.light.colors.copyWith(
    primary: AppColors.primary,
    primaryForeground: AppColors.white,
    background: AppColors.background,
    foreground: AppColors.textPrimary,
    secondary: AppColors.accent,
    secondaryForeground: AppColors.white,
    mutedForeground: AppColors.textSecondary,
    destructive: AppColors.expense,
  ),
  style: FThemes.zinc.light.style.copyWith(
    borderRadius: BorderRadius.circular(16),
  ),
);
