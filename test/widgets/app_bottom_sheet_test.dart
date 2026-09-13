import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('showAppBottomSheet menampilkan konten builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAppBottomSheet(
                context: context,
                builder: (context) => const Text('Isi bottom sheet'),
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.text('Isi bottom sheet'), findsOneWidget);
  });

  testWidgets('showAppBottomSheet menyediakan Material ancestor untuk widget Material biasa', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAppBottomSheet(
                context: context,
                builder: (context) => const TextField(key: Key('sheet-text-field')),
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    // No "No Material widget found" exception should have been thrown.
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sheet-text-field')), findsOneWidget);

    // Prove the TextField is genuinely interactive within a working
    // Material ancestor, not just that it built without throwing.
    await tester.enterText(find.byKey(const Key('sheet-text-field')), 'halo dompet');
    await tester.pump();

    expect(find.text('halo dompet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
