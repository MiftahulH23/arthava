import 'package:arthava/theme/app_forui_theme.dart';
import 'package:arthava/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import '../helpers/pump_app.dart';

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

  testWidgets('membuka sheet melepas fokus isian; setelah ditutup keyboard tidak naik lagi', (tester) async {
    final controller = TextEditingController();
    final node = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(node.dispose);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            TextField(controller: controller, focusNode: node),
            TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 200, child: Text('isi sheet')),
              ),
              child: const Text('buka'),
            ),
          ]),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('isi sheet'), findsOneWidget);
    expect(node.hasFocus, isFalse);

    Navigator.of(tester.element(find.text('isi sheet'))).pop();
    await tester.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
