@Tags(['screenshot'])
library;

import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/screens/debt/debt_screen.dart';
import 'package:arthava/screens/login/login_screen.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/debt/debt_test_utils.dart';
import 'screenshot_harness.dart';

void main() {
  final skip = !screenshotFontsAvailable;

  testWidgets('01 tab kapsul (Masuk/Daftar)', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(tester, const LoginScreen());
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'ts_01_capsule_tabs');
  }, skip: skip);

  testWidgets('02 geser hapus utang', (tester) async {
    await loadRealFonts(tester);
    await pumpScreen(
      tester,
      const DebtScreen(),
      overrides: debtOverrides(FakeDebtNotifier(DebtState(
        isLoading: false,
        debts: [
          sampleDebt(id: 1, dueDate: DateTime(2026, 9, 22), notes: 'Modal usaha'),
          sampleDebt(id: 2, name: 'Rina', amount: 750000, remaining: 750000, dueDate: DateTime(2026, 11, 15)),
        ],
      ))),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Rina'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'ts_02_swipe_delete_debt');
  }, skip: skip);

  testWidgets('03 isian catatan fokus di kartu', (tester) async {
    await loadRealFonts(tester);
    final c = TextEditingController(text: 'Beli Nasi Padang');
    addTearDown(c.dispose);
    await pumpScreen(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AppGroupedSection(header: 'Catatan (Opsional)', children: [AppTextField(controller: c, hint: 'x')]),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'ts_03_note_focus');
  }, skip: skip);
}
