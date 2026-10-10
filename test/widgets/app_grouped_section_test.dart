import 'package:arthava/core/colors.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('header di-uppercase, aksi header bisa ditap, separator di antara baris', (tester) async {
    var tapped = 0;
    await pumpApp(tester, Scaffold(body: AppGroupedSection(
      header: 'Dompet',
      headerAction: 'Kelola',
      onHeaderAction: () => tapped++,
      children: const [SizedBox(height: 56), SizedBox(height: 56), SizedBox(height: 56)],
    )));
    expect(find.text('DOMPET'), findsOneWidget);
    await tester.tap(find.text('Kelola'));
    expect(tapped, 1);
    expect(find.byKey(const ValueKey('grouped-separator-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('grouped-separator-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('grouped-separator-3')), findsNothing);
  });

  testWidgets('separator inset 68 atau 16', (tester) async {
    Future<double> insetOf(bool inset) async {
      await pumpApp(tester, Scaffold(body: AppGroupedSection(
        insetSeparators: inset,
        children: const [SizedBox(height: 56), SizedBox(height: 56)],
      )));
      final sep = find.byKey(const ValueKey('grouped-separator-1'));
      return tester.getTopLeft(sep).dx - tester.getTopLeft(find.byType(AppGroupedSection)).dx;
    }
    expect(await insetOf(true), 68);
    expect(await insetOf(false), 16);
    final box = tester.widget<Container>(find.byKey(const ValueKey('grouped-separator-1')));
    expect((box.color), AppColors.separator);
  });

  testWidgets('aksi header (Kelola) minimal 44 tinggi dan berupa tombol', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppGroupedSection(
      header: 'Dompet', headerAction: 'Kelola', onHeaderAction: () => taps++,
      children: const [SizedBox(height: 56)],
    )));
    final action = find.ancestor(of: find.text('Kelola'), matching: find.byType(Semantics)).first;
    expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
    expect(tester.getSemantics(find.text('Kelola')), containsSemantics(isButton: true));
    await tester.tap(find.text('Kelola'));
    expect(taps, 1);
  });
}
