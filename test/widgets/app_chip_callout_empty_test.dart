import 'package:arthava/core/colors.dart';
import 'package:arthava/widgets/app_callout.dart';
import 'package:arthava/widgets/app_chip.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('AppChip memakai warna untuk teks dan latar lembut', (tester) async {
    await pumpApp(tester, const Scaffold(body: Row(children: [
      AppChip(label: 'Terlambat 2 hari', color: AppColors.expense),
      AppChip(label: 'BCA', icon: PhosphorIconsRegular.wallet),
    ])));
    expect(tester.widget<Text>(find.text('Terlambat 2 hari')).style!.color, AppColors.expense);
    expect(tester.widget<Text>(find.text('BCA')).style!.color, AppColors.textSecondary);
    expect(find.byIcon(PhosphorIconsRegular.wallet), findsOneWidget);
  });

  testWidgets('AppCountBadge tersembunyi untuk 0', (tester) async {
    await pumpApp(tester, const Scaffold(body: Row(children: [AppCountBadge(0), AppCountBadge(2)])));
    expect(find.text('0'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('AppCallout tone menentukan latar', (tester) async {
    await pumpApp(tester, const Scaffold(body: Column(children: [
      AppCallout(key: Key('i'), icon: PhosphorIconsRegular.info, child: Text('info')),
      AppCallout(key: Key('a'), icon: PhosphorIconsRegular.lightbulb, tone: AppCalloutTone.accent, child: Text('saran')),
    ])));
    Color bg(String k) => (tester.widget<Container>(find.descendant(
      of: find.byKey(Key(k)), matching: find.byType(Container)).first).decoration! as BoxDecoration).color!;
    expect(bg('i'), AppColors.primarySoft);
    expect(bg('a'), AppColors.accentSoft);
  });

  testWidgets('AppEmptyState menampilkan judul, subjudul, aksi', (tester) async {
    await pumpApp(tester, Scaffold(body: AppEmptyState(
      icon: PhosphorIconsRegular.receipt,
      title: 'Tidak ada transaksi',
      subtitle: 'Coba ganti periode',
      action: TextButton(onPressed: () {}, child: const Text('Tambah')),
    )));
    expect(find.text('Tidak ada transaksi'), findsOneWidget);
    expect(find.text('Coba ganti periode'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
  });
}
