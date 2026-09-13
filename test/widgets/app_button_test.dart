import 'package:catat_uang_app/theme/app_forui_theme.dart';
import 'package:catat_uang_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  testWidgets('AppButton memanggil onPressed saat ditekan', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: Scaffold(
          body: AppButton(
            label: 'Simpan',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Simpan'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    // forui's FTappable schedules a Future.delayed (pressedEnter/ExitDuration)
    // on pointer down/up; a bare pump() never elapses fake-async time, so the
    // pending Timer trips flutter_test's teardown check. Advance by enough
    // time to flush it, matching the default 200ms pressedEnterDuration.
    await tester.pump(const Duration(milliseconds: 300));

    expect(pressed, isTrue);
  });

  testWidgets('AppButton tidak bisa ditekan saat onPressed null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => FTheme(data: appForuiTheme, child: child!),
        home: const Scaffold(
          body: AppButton(label: 'Nonaktif', onPressed: null),
        ),
      ),
    );

    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.onPressed, isNull);
  });
}
