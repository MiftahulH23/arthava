import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/login/auth_layout.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  testWidgets('setelah keluar dari layar auth, status bar kembali ikon gelap', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      builder: (context, child) => AppSystemUi(child: child!),
      home: AuthLayout(
        title: 'DompetKu',
        subtitle: 'x',
        leading: const AuthLogo(icon: PhosphorIconsFill.wallet),
        fields: const [],
        action: AppPrimaryButton(label: 'Aksi', onPressed: () {}),
        footer: const SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    nav.currentState!.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    expect(SystemChrome.latestStyle?.systemNavigationBarColor, AppColors.background);
    expect(SystemChrome.latestStyle?.systemNavigationBarIconBrightness, Brightness.dark);
  });
}
