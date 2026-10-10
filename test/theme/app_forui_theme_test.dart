import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_forui_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regresi: sebelumnya appForuiTheme dibangun dengan
  // FThemes.zinc.light.copyWith(colors:, style:), yang TIDAK menurunkan
  // colors/style ke style per-widget. Test ini membuktikan pemetaan tema
  // benar-benar sampai ke style widget.
  test('appForuiTheme menurunkan AppColors & radius ke cardStyle', () {
    expect(appForuiTheme.cardStyle.decoration.borderRadius, BorderRadius.circular(16));
    expect(appForuiTheme.cardStyle.decoration.color, AppColors.background);
    expect(
      appForuiTheme.cardStyle.contentStyle.titleTextStyle.color,
      AppColors.textPrimary,
    );
    expect(
      appForuiTheme.cardStyle.contentStyle.subtitleTextStyle.color,
      AppColors.textSecondary,
    );
  });

  test('appForuiTheme memakai Plus Jakarta Sans, bukan Inter bawaan forui', () {
    expect(appForuiTheme.typography.defaultFontFamily, isNot(contains('Inter')));
    expect(appForuiTheme.typography.defaultFontFamily, contains('PlusJakartaSans'));
    expect(
      appForuiTheme.cardStyle.contentStyle.titleTextStyle.fontFamily,
      appForuiTheme.typography.defaultFontFamily,
    );
  });
}
