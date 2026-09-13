import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  // Regresi: sebelumnya appForuiTheme dibangun dengan
  // FThemes.zinc.light.copyWith(colors:, style:), yang TIDAK menurunkan
  // colors/style ke style per-widget. Akibatnya cardStyle tetap memakai
  // warna & radius preset zinc, bukan AppColors. Test ini membuktikan
  // pemetaan tema benar-benar sampai ke style widget.
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

  test('appForuiTheme memakai font Poppins, bukan Inter bawaan forui', () {
    expect(appForuiTheme.typography.defaultFontFamily, isNot(contains('Inter')));
    expect(
      appForuiTheme.cardStyle.contentStyle.titleTextStyle.fontFamily,
      appForuiTheme.typography.defaultFontFamily,
    );
  });

  testWidgets('AppCard menampilkan child-nya', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppCard(child: Text('Isi kartu')),
        ),
      ),
    );

    expect(find.text('Isi kartu'), findsOneWidget);
  });

  testWidgets('AppCard menampilkan title dan subtitle jika diberikan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppCard(
            title: Text('Judul'),
            subtitle: Text('Subjudul'),
            child: Text('Isi'),
          ),
        ),
      ),
    );

    expect(find.text('Judul'), findsOneWidget);
    expect(find.text('Subjudul'), findsOneWidget);
    expect(find.text('Isi'), findsOneWidget);
  });
}
