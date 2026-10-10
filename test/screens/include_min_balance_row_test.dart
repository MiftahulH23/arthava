import 'package:arthava/providers/user_settings_provider.dart';
import 'package:arthava/screens/settings/include_min_balance_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class FakeUserSettingsNotifier extends UserSettingsNotifier {
  bool? lastSet;

  @override
  UserSettingsState build() => const UserSettingsState(includeMinBalance: true, isLoading: false);

  @override
  Future<void> setIncludeMinBalance(bool value) async {
    lastSet = value;
    state = state.copyWith(includeMinBalance: value);
  }
}

void main() {
  testWidgets('menampilkan judul dan menulis pengaturan saat switch diubah', (tester) async {
    final fake = FakeUserSettingsNotifier();
    await pumpApp(
      tester,
      const Scaffold(body: IncludeMinBalanceRow()),
      overrides: [userSettingsProvider.overrideWith(() => fake)],
    );
    expect(find.text('Hitung saldo minimal di total saldo'), findsOneWidget);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isTrue);

    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(fake.lastSet, isFalse);
    expect(tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value, isFalse);
    expect(find.text('Total saldo dikurangi saldo minimal'), findsOneWidget);
  });
}
