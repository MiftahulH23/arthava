import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('Toast error memakai warna AppColors dan font tema', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppNotification.error(context, 'Nama tidak boleh kosong'),
            child: const Text('tes'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tes'));
    await tester.pump();

    final text = tester.widget<Text>(find.text('Nama tidak boleh kosong'));
    expect(text.style?.color, AppColors.textPrimary);
    expect(text.style?.fontFamily, isNot(contains('Poppins')));

    final icons = tester.widgetList<Icon>(find.byType(Icon)).where((i) => i.color == AppColors.expense);
    expect(icons, isNotEmpty);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('pesan sama diketuk berulang: toast yang tampil dipakai ulang, tidak dianimasikan ulang', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          // Di tengah: ketukan kedua tidak boleh mengenai toast (ketuk toast = tutup).
          body: Center(
            child: TextButton(
              onPressed: () => AppNotification.info(context, 'Belum tersedia.'),
              child: const Text('tes'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tes'));
    await tester.pump(const Duration(milliseconds: 300));
    final first = find.text('Belum tersedia.').evaluate().single;
    await tester.tap(find.text('tes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Belum tersedia.'), findsOneWidget);
    expect(identical(find.text('Belum tersedia.').evaluate().single, first), isTrue);
    // Timer tetap diperpanjang: 2,9 detik setelah ketukan kedua toast masih ada.
    await tester.pump(const Duration(milliseconds: 2600));
    expect(find.text('Belum tersedia.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Belum tersedia.'), findsNothing);
  });

  testWidgets('Toast info memakai ikon info biru di lingkaran primarySoft', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AppNotification.info(context, 'Login Google belum tersedia.'),
            child: const Text('tes'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tes'));
    await tester.pump();

    expect(find.text('Login Google belum tersedia.'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(PhosphorIcons.info(PhosphorIconsStyle.bold)));
    expect(icon.color, AppColors.primary);
    final circle = tester.widget<Container>(
      find.ancestor(of: find.byWidget(icon), matching: find.byType(Container)).first,
    );
    expect((circle.decoration! as BoxDecoration).color, AppColors.primarySoft);
    await tester.pump(const Duration(seconds: 4));
  });
}
