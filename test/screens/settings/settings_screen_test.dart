import 'package:catat_uang_app/screens/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('Pengaturan menampilkan grup Umum dan Lainnya ala Settings iPhone', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('UMUM'), findsOneWidget);
    expect(find.text('LAINNYA'), findsOneWidget);
    expect(find.text('Profil Akun'), findsOneWidget);
    expect(find.text('Atur nama dan info akun'), findsOneWidget);
    expect(find.text('Tentang Aplikasi'), findsOneWidget);
    expect(find.text('Versi 1.0.0'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(find.text('Logout dari akun'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.signOut), findsOneWidget);
  });

  testWidgets('Tentang Aplikasi menampilkan snackbar versi', (tester) async {
    await pumpApp(tester, const SettingsScreen());

    await tester.tap(find.text('Tentang Aplikasi'));
    await tester.pump();

    expect(find.text('Aplikasi DompetKu v1.0 by Miftahul Huda'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
