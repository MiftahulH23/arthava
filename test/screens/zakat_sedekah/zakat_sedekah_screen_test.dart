import 'package:arthava/screens/zakat_sedekah/zakat_sedekah_screen.dart';
import 'package:arthava/widgets/app_amount_display.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

// Supabase tidak diinisialisasi di test: _fetchWallets gagal di dalam
// try/catch-nya sendiri (seam: _supabase adalah getter), jadi daftar
// dompet kosong — cukup untuk menguji kalkulasi & validasi di layar.
void main() {
  testWidgets('zakat 2.5% dihitung dari total harta', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();

    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Zakat & Sedekah'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(AppAmountField), matching: find.byType(EditableText)),
      '100000000',
    );
    await tester.pump();

    expect(find.text('Zakat yang Harus Dibayar'), findsOneWidget);
    expect(find.text('Rp 2.500.000'), findsOneWidget);
  });

  testWidgets('pindah ke tab Sedekah mengganti isi dan tombol', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();

    await tester.tap(find.text('Sedekah'));
    await tester.pump();

    expect(find.text('Nominal Sedekah (Rp)'), findsOneWidget);
    expect(find.text('Misal: Sedekah Jumat, Untuk Masjid, dll'), findsOneWidget);
    expect(find.text('Bayar Sedekah'), findsOneWidget);
    expect(find.text('Zakat yang Harus Dibayar'), findsNothing);
  });

  testWidgets('bayar zakat tanpa dompet menampilkan pesan', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();

    expect(find.text('Buat Dompet'), findsOneWidget);
    await tester.tap(find.text('Bayar Zakat'));
    await tester.pump();

    expect(find.text('Anda belum membuat dompet.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('geser layar ke kiri pindah ke Sedekah', (tester) async {
    await pumpApp(tester, const ZakatSedekahScreen());
    await tester.pump();
    await tester.timedDrag(find.text('Zakat & Sedekah'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Bayar Sedekah'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
