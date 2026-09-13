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

  testWidgets(
    'AppTabSelector memindahkan seleksi visual sendiri setelah di-tap '
    '(tanpa parent mengirim balik index baru)',
    (tester) async {
      // Regresi: sebelumnya widget ini memakai FTabControl.lifted, yang membuat
      // index dikontrol penuh oleh parent. onChanged tetap terpanggil, tapi tab
      // yang di-tap TIDAK pernah terlihat terpilih karena parent di sini tidak
      // pernah mengirim index baru. Parent di test ini sengaja statis.
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

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.controller!.index, 0);

      await tester.tap(find.text('Tahunan'));
      await tester.pumpAndSettle();

      // Controller internal TabBar yang menentukan indikator/label terpilih.
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
    },
  );

  testWidgets(
    'AppTabSelector memakai activeColor sebagai warna indikator & label terpilih saat diberikan',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
          home: Scaffold(
            body: AppTabSelector(
              labels: const ['Harian', 'Bulanan', 'Tahunan'],
              initialIndex: 0,
              onChanged: (_) {},
              activeColor: Colors.red,
            ),
          ),
        ),
      );

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      final indicator = bar.indicator as BoxDecoration;
      expect(indicator.color, Colors.red);
      expect(bar.labelStyle!.color, Colors.white);
    },
  );
}
