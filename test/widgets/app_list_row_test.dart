import 'package:arthava/core/colors.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('menampilkan judul, subjudul, value, chevron, dan memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: AppListRow(
      leading: const AppIconTile(icon: PhosphorIconsRegular.calendar, color: AppColors.primary),
      title: 'Bulan Laporan',
      subtitle: 'Pilih periode',
      value: 'September 2026',
      showChevron: true,
      onTap: () => taps++,
    )));
    expect(find.text('Bulan Laporan'), findsOneWidget);
    expect(find.text('Pilih periode'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.caretRight), findsOneWidget);
    await tester.tap(find.text('Bulan Laporan'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(AppListRow)).height, greaterThanOrEqualTo(56));
  });

  testWidgets('titleColor dipakai untuk judul (mis. Keluar merah)', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppListRow(title: 'Keluar', titleColor: AppColors.expense)));
    expect(tester.widget<Text>(find.text('Keluar')).style!.color, AppColors.expense);
  });

  testWidgets('AppIconTile tinted vs filled vs round', (tester) async {
    await pumpApp(tester, const Scaffold(body: Column(children: [
      AppIconTile(key: Key('t'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue),
      AppIconTile(key: Key('f'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue, filled: true),
      AppIconTile(key: Key('r'), icon: PhosphorIconsRegular.wallet, color: AppColors.tintBlue, round: true),
    ])));
    BoxDecoration deco(String k) => tester.widget<Container>(
      find.descendant(of: find.byKey(Key(k)), matching: find.byType(Container)).first,
    ).decoration! as BoxDecoration;
    expect(deco('t').color, isNot(AppColors.tintBlue));
    expect(deco('t').borderRadius, BorderRadius.circular(12));
    expect(deco('f').color, AppColors.tintBlue);
    expect(deco('r').shape, BoxShape.circle);
    final filledIcon = tester.widget<Icon>(find.descendant(of: find.byKey(const Key('f')), matching: find.byType(Icon)));
    expect(filledIcon.color, Colors.white);
  });

  testWidgets('value pendek menempel ke kanan (rata kanan seperti Settings iOS)', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppListRow(title: 'Tanggal Pinjam', value: '01 Agu')));
    final right = tester.getRect(find.text('01 Agu')).right;
    expect(right, closeTo(390 - 16, 0.5));
  });

  testWidgets('judul panjang tidak terpotong (turun baris), nilai tetap tampil', (tester) async {
    await pumpApp(tester, const Scaffold(body: AppListRow(
      leading: AppIconTile(icon: Icons.calendar_today, color: Colors.blue),
      title: 'Tanggal Pembayaran',
      value: '24 Sep 2026',
      showChevron: true,
    )));
    final title = tester.renderObject<RenderParagraph>(find.text('Tanggal Pembayaran'));
    expect(title.didExceedMaxLines, isFalse);
    expect(find.text('24 Sep 2026'), findsOneWidget);
  });

  testWidgets('valueColor mewarnai value; default warna subhead', (tester) async {
    await pumpApp(tester, const Scaffold(body: Column(children: [
      AppListRow(title: 'Dari', value: '1 Sep 2026', valueColor: AppColors.primary),
      AppListRow(title: 'Sampai', value: '10 Sep 2026'),
    ])));
    expect(tester.widget<Text>(find.text('1 Sep 2026')).style!.color, AppColors.primary);
    expect(tester.widget<Text>(find.text('10 Sep 2026')).style!.color, isNot(AppColors.primary));
  });

  testWidgets('judul pendek: value panjang tidak dipotong (tidak dikunci porsi 3:2)', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: AppListRow(
          leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.expense),
          title: 'Tanggal',
          value: 'Sab, 26 Sep 2026',
          showChevron: true,
          onTap: () {},
        ),
      ),
      size: const Size(600, 400),
    );
    final value = tester.renderObject<RenderParagraph>(find.text('Sab, 26 Sep 2026'));
    expect(value.didExceedMaxLines, isFalse);
  });

  testWidgets('trailing ikut dihitung: judul pendek tetap satu baris walau nilai panjang', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: AppListRow(
          leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: AppColors.primary),
          title: 'Dompet',
          value: 'Rp 9.300.000.000.000.000.000',
          trailing: Icon(PhosphorIconsBold.check, size: 20),
        ),
      ),
      size: const Size(600, 400),
    );
    final title = tester.renderObject<RenderParagraph>(find.text('Dompet'));
    // Satu baris: tinggi di bawah dua kali ukuran huruf.
    expect(title.size.height, lessThan(AppTextStyles.bodyStrong.fontSize! * 2));
  });

  testWidgets('judul diukur dengan gaya turunan (letterSpacing tema) → tidak patah di tengah kata', (tester) async {
    // Material 3 memberi letterSpacing lewat DefaultTextStyle; dulu judul diukur
    // tanpa itu sehingga "Kategori" patah jadi "Kategor / i".
    await pumpApp(
      tester,
      const Scaffold(
        body: DefaultTextStyle(
          style: TextStyle(letterSpacing: 1.5),
          child: AppListRow(
            leading: AppIconTile(icon: PhosphorIconsFill.tag, color: AppColors.primary),
            title: 'Kategori',
            value: 'Pilih Kategori Pengeluaran Yang Sangat Panjang Sekali',
            showChevron: true,
          ),
        ),
      ),
      size: const Size(600, 400),
    );
    final title = tester.renderObject<RenderParagraph>(find.text('Kategori'));
    expect(title.size.height, lessThan(AppTextStyles.bodyStrong.fontSize! * 2));
  });
}
