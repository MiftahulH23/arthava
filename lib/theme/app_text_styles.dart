import 'package:arthava/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Skala teks Phase B (spec §5). Semua screen memakai ini, bukan GoogleFonts langsung.
abstract final class AppTextStyles {
  static final TextStyle largeTitle = GoogleFonts.plusJakartaSans(
    fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15,
    color: AppColors.textPrimary,
  );
  static final TextStyle title = GoogleFonts.plusJakartaSans(
    fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static final TextStyle headline = GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static final TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
  );
  static final TextStyle bodyStrong = GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static final TextStyle subhead = GoogleFonts.plusJakartaSans(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
  static final TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
  static final TextStyle groupLabel = GoogleFonts.plusJakartaSans(
    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textSecondary,
  );
  static final TextStyle navLabel = GoogleFonts.plusJakartaSans(
    fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.primary,
  );
  static final TextStyle amountHero = GoogleFonts.plusJakartaSans(
    fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Colors.white,
    fontFeatures: _tabular,
  );
  static final TextStyle amountLarge = GoogleFonts.plusJakartaSans(
    fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );
  static final TextStyle amountRow = GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );
  static final TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
  );
}
