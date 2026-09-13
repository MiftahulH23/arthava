import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_tab_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('AppTabSelector menampilkan semua label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppTabSelector(
            labels: const ['Harian', 'Bulanan', 'Tahunan'],
            initialIndex: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Harian'), findsOneWidget);
    expect(find.text('Bulanan'), findsOneWidget);
    expect(find.text('Tahunan'), findsOneWidget);
  });

  testWidgets('AppTabSelector memanggil onChanged dengan index yang benar', (tester) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppTabSelector(
            labels: const ['Harian', 'Bulanan'],
            initialIndex: 0,
            onChanged: (index) => selected = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });
}
