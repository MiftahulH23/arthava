import 'package:catat_uang_app/screens/lock/app_entry_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> _pumpGate(WidgetTester tester, {required Future<bool> Function() loadSetting, bool supported = true}) async {
  await pumpApp(
    tester,
    AppEntryGate(
      loadSetting: loadSetting,
      deviceSupported: () async => supported,
      lockBuilder: () => const Text('KUNCI'),
      homeBuilder: () => const Text('BERANDA'),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('setting mati → langsung Beranda', (tester) async {
    await _pumpGate(tester, loadSetting: () async => false);
    expect(find.text('BERANDA'), findsOneWidget);
    expect(find.text('KUNCI'), findsNothing);
  });

  testWidgets('setting aktif dan perangkat mendukung → layar Kunci', (tester) async {
    await _pumpGate(tester, loadSetting: () async => true);
    expect(find.text('KUNCI'), findsOneWidget);
  });

  testWidgets('setting aktif tapi perangkat tidak mendukung → Beranda', (tester) async {
    await _pumpGate(tester, loadSetting: () async => true, supported: false);
    expect(find.text('BERANDA'), findsOneWidget);
  });

  testWidgets('gagal membaca setting → Beranda (fail-open)', (tester) async {
    await _pumpGate(tester, loadSetting: () async => throw Exception('offline'));
    expect(find.text('BERANDA'), findsOneWidget);
  });
}
