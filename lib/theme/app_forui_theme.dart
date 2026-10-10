import 'package:arthava/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet forui aplikasi, dipetakan dari [AppColors] yang sudah ada.
final FColors _appColors = FThemes.zinc.light.colors.copyWith(
  primary: AppColors.primary,
  primaryForeground: AppColors.white,
  background: AppColors.background,
  foreground: AppColors.textPrimary,
  secondary: AppColors.accent,
  secondaryForeground: AppColors.white,
  mutedForeground: AppColors.textSecondary,
  destructive: AppColors.expense,
);

/// Tema forui project ini, dipetakan dari [AppColors] yang sudah ada.
///
/// Semua widget di lib/widgets/ mengandalkan tema ini untuk warna —
/// jangan override warna per-widget kecuali benar-benar perlu varian
/// khusus, supaya satu perubahan di AppColors otomatis menyebar ke
/// semua komponen forui.
///
/// PENTING: tema ini WAJIB dibangun lewat factory `FThemeData(...)`, bukan
/// `FThemes.zinc.light.copyWith(colors: ..., style: ...)`. `copyWith` hanya
/// mengganti field `colors`/`style` di objek tema, tapi TIDAK menurunkannya
/// ulang ke style per-widget (cardStyle, buttonStyles, tabsStyle, dst) yang
/// sudah terlanjur dihitung pada preset — jadi warna & radius di sini tidak
/// akan pernah sampai ke widget mana pun. Hanya factory `FThemeData(...)`
/// yang memanggil `.inherit(colors:, typography:, style:)` tiap style.
///
/// Catatan: tema ini light-only. Dukungan dark theme sengaja ditunda ke
/// fase berikutnya (screen yang memakainya memang sudah light-hardcoded
/// sebelum refactor, jadi bukan regresi).
final FThemeData appForuiTheme = FThemeData(
  colors: _appColors,
  // FTypography.copyWith TIDAK menerima `defaultFontFamily` (selalu
  // mempertahankan milik instance asal), jadi pakai `FTypography.inherit`
  // supaya seluruh skala teks benar-benar memakai Plus Jakarta Sans, bukan Inter
  // bawaan forui.
  typography: FTypography.inherit(
    colors: _appColors,
    defaultFontFamily: GoogleFonts.plusJakartaSans().fontFamily!,
  ),
  style: FThemes.zinc.light.style.copyWith(
    borderRadius: BorderRadius.circular(16),
  ),
);
