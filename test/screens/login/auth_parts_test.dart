import 'package:catat_uang_app/screens/login/auth_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('AuthGoogleButton menampilkan logo G dan label, lalu memanggil onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, Scaffold(body: Center(child: AuthGoogleButton(label: 'Lanjut dengan Google', onTap: () => taps++))));
    expect(find.text('Lanjut dengan Google'), findsOneWidget);
    expect(find.byType(GoogleLogo), findsOneWidget);
    await tester.tap(find.text('Lanjut dengan Google'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(AuthGoogleButton)).height, 48);
  });

  testWidgets('AuthDivider menampilkan teks di antara dua garis', (tester) async {
    await pumpApp(tester, const Scaffold(body: AuthDivider(label: 'atau masuk dengan')));
    final text = tester.getRect(find.text('atau masuk dengan'));
    expect(text.left, greaterThan(40));
    expect(text.right, lessThan(390 - 40));
  });

  testWidgets('AuthLogo 44x44 dengan ikon', (tester) async {
    await pumpApp(tester, const Scaffold(body: Center(child: AuthLogo(icon: PhosphorIconsFill.wallet))));
    expect(tester.getSize(find.byType(AuthLogo)), const Size(44, 44));
    expect(find.byIcon(PhosphorIconsFill.wallet), findsOneWidget);
  });
}
