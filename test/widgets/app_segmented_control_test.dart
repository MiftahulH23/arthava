import 'package:arthava/core/colors.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('memanggil onChanged dengan index yang ditap, bukan untuk segmen aktif', (tester) async {
    final calls = <int>[];
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: 0,
      onChanged: calls.add,
    )));
    await tester.tap(find.text('Pengeluaran'));
    await tester.tap(find.text('Pemasukan'));
    expect(calls, [1]);
  });

  testWidgets('warna teks terpilih mengikuti selectedLabelColors', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: 1,
      selectedLabelColors: const [AppColors.income, AppColors.expense],
      onChanged: (_) {},
    )));
    expect(tester.widget<Text>(find.text('Pengeluaran')).style!.color, AppColors.expense);
    expect(tester.widget<Text>(find.text('Pemasukan')).style!.color, AppColors.textSecondary);
  });

  testWidgets('segmen diumumkan pembaca layar sebagai grup pilihan tunggal', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['Masuk', 'Daftar'], selectedIndex: 0, onChanged: (_) {},
    )));
    final segments = tester
        .widgetList<Semantics>(find.descendant(of: find.byType(AppSegmentedControl), matching: find.byType(Semantics)))
        .where((s) => s.properties.button == true)
        .toList();
    expect(segments.length, 2);
    expect(segments.every((s) => s.properties.inMutuallyExclusiveGroup == true), isTrue);
  });

  testWidgets('tinggi 36', (tester) async {
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['A', 'B', 'C'], selectedIndex: 2, onChanged: (_) {},
    )));
    expect(tester.getSize(find.byType(AppSegmentedControl)).height, 36);
  });

  testWidgets('jalur dan penanda berbentuk kapsul, penanda di segmen terpilih', (tester) async {
    await pumpApp(tester, Scaffold(body: Center(child: SizedBox(width: 300, child: AppSegmentedControl(
      labels: const ['Masuk', 'Daftar'], selectedIndex: 1, onChanged: (_) {},
    )))));
    await tester.pumpAndSettle();
    final track = tester.widget<Container>(find.descendant(
      of: find.byType(AppSegmentedControl), matching: find.byType(Container)).first);
    expect((track.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(999));
    final thumb = find.byKey(const ValueKey('segmented-thumb'));
    final thumbBox = tester.getRect(find.descendant(of: thumb, matching: find.byType(DecoratedBox)).first);
    expect(thumbBox.center.dx, greaterThan(tester.getCenter(find.byType(AppSegmentedControl)).dx));
    expect(tester.widget<Text>(find.text('Daftar')).style!.fontWeight, FontWeight.w700);
  });

  testWidgets('position pecahan menggeser penanda di antara segmen', (tester) async {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    await pumpApp(tester, Scaffold(body: Center(child: SizedBox(width: 300, child: AppSegmentedControl(
      labels: const ['A', 'B'], selectedIndex: 0, onChanged: (_) {}, position: position,
    )))));
    await tester.pumpAndSettle();
    final thumb = find.descendant(of: find.byKey(const ValueKey('segmented-thumb')), matching: find.byType(DecoratedBox)).first;
    final x0 = tester.getRect(thumb).left;
    position.value = 0.5;
    await tester.pumpAndSettle();
    final xHalf = tester.getRect(thumb).left;
    position.value = 1;
    await tester.pumpAndSettle();
    final x1 = tester.getRect(thumb).left;
    expect(xHalf, greaterThan(x0));
    expect(x1, greaterThan(xHalf));
    expect((xHalf - (x0 + x1) / 2).abs(), lessThan(1));
  });

  testWidgets('penanda mengikuti posisi pecahan langsung tanpa animasi', (tester) async {
    final pos = ValueNotifier<double>(0);
    await pumpApp(tester, Scaffold(body: AppSegmentedControl(
      labels: const ['A', 'B'], selectedIndex: 0, position: pos, onChanged: (_) {},
    )));
    final thumb = find.descendant(of: find.byKey(const ValueKey('segmented-thumb')), matching: find.byType(DecoratedBox)).first;
    final x0 = tester.getRect(thumb).left;
    pos.value = 0.5;
    await tester.pump();
    expect(tester.getRect(thumb).left, greaterThan(x0));
  });
}
