import 'package:catat_uang_app/models/wallet_model.dart';
import 'package:catat_uang_app/providers/user_settings_provider.dart';
import 'package:catat_uang_app/providers/wallet_provider.dart';
import 'package:catat_uang_app/screens/wallet/wallet_screen.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../helpers/pump_app.dart';

class FakeWalletNotifier extends WalletNotifier {
  FakeWalletNotifier(this.initial);
  final List<WalletModel> initial;
  int? favoriteId;
  bool? favoriteValue;

  @override
  WalletState build() => WalletState(wallets: initial, isLoading: false);

  @override
  Future<void> setFavorite(int id, bool isFavorite) async {
    favoriteId = id;
    favoriteValue = isFavorite;
  }
}

class FakeUserSettingsNotifier extends UserSettingsNotifier {
  FakeUserSettingsNotifier(this.include);
  final bool include;

  @override
  UserSettingsState build() => UserSettingsState(includeMinBalance: include, isLoading: false);
}

List<WalletModel> sample() => [
      WalletModel(id: 1, userId: 'u', name: 'BCA', balance: 9300000, color: '#1E3A8A', isFavorite: true, minBalance: 50000),
      WalletModel(id: 2, userId: 'u', name: 'GoPay', balance: 1850000, color: '#E65100'),
      WalletModel(id: 3, userId: 'u', name: 'Tunai', balance: 1300000, color: '#00796B'),
    ];

Future<FakeWalletNotifier> pumpWallet(
  WidgetTester tester,
  List<WalletModel> wallets, {
  bool include = true,
  Size size = const Size(390, 1200),
}) async {
  final fake = FakeWalletNotifier(wallets);
  await pumpApp(
    tester,
    const WalletScreen(),
    overrides: [
      walletProvider.overrideWith(() => fake),
      userSettingsProvider.overrideWith(() => FakeUserSettingsNotifier(include)),
    ],
    size: size,
  );
  return fake;
}

void main() {
  testWidgets('kartu bertumpuk menampilkan nama huruf besar, saldo, bintang favorit, dan pill', (tester) async {
    await pumpWallet(tester, sample());
    expect(find.text('Dompet Saya'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('GOPAY'), findsOneWidget);
    expect(find.text('Rp 9.300.000'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.star), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(find.textContaining('Bisa dipakai'), findsNothing); // pengaturan aktif
  });

  testWidgets('pengaturan nonaktif: kartu menampilkan Bisa dipakai', (tester) async {
    await pumpWallet(tester, sample(), include: false);
    expect(find.text('Bisa dipakai Rp 9.250.000'), findsOneWidget);
  });

  testWidgets('ketuk kartu membuka sheet aksi; Jadikan Favorit memanggil setFavorite', (tester) async {
    final fake = await pumpWallet(tester, sample());
    await tester.tap(find.text('GOPAY'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Jadikan Favorit'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    await tester.tap(find.text('Jadikan Favorit'));
    await tester.pumpAndSettle();
    expect(fake.favoriteId, 2);
    expect(fake.favoriteValue, isTrue);
  });

  testWidgets('kosong: empty state dan pill hanya Tambah', (tester) async {
    await pumpWallet(tester, []);
    expect(find.text('Belum ada dompet'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing);
  });

  testWidgets('satu dompet: Transfer tetap tampil (menawarkan dompet kedua)', (tester) async {
    await pumpWallet(tester, [sample().first]);
    expect(find.text('Transfer'), findsOneWidget);
  });

  testWidgets('sheet Tambah Dompet punya isian Saldo Minimal (Opsional)', (tester) async {
    await pumpWallet(tester, sample());
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Dompet'), findsOneWidget);
    expect(find.text('Saldo Minimal (Opsional)'), findsOneWidget);
    expect(find.text('Pilih Warna'), findsOneWidget);
  });

  Rect cardRect(WidgetTester tester, String name) =>
      tester.getRect(find.ancestor(of: find.text(name), matching: find.byType(Positioned)).first);

  testWidgets('TOTAL SALDO di atas saldo di tiap kartu (mockup), tidak tertutup kartu berikutnya', (tester) async {
    await pumpWallet(tester, sample());
    expect(find.text('TOTAL SALDO'), findsNWidgets(3));
    final firstLabel = tester.getRect(find.text('TOTAL SALDO').first);
    final firstAmount = tester.getRect(find.text('Rp 9.300.000'));
    expect(firstLabel.bottom, lessThanOrEqualTo(firstAmount.top));
    expect(firstAmount.bottom, lessThanOrEqualTo(cardRect(tester, 'GOPAY').top));
  });

  testWidgets('pengaturan nonaktif: Bisa dipakai di kartu bertumpuk tidak tertutup kartu berikutnya', (tester) async {
    await pumpWallet(tester, sample(), include: false);
    final text = tester.getRect(find.text('Bisa dipakai Rp 9.250.000'));
    expect(text.bottom, lessThanOrEqualTo(cardRect(tester, 'GOPAY').top));
  });

  testWidgets('pill Transfer · Tambah memakai tombol besar dengan jarak lega, tidak selebar layar', (tester) async {
    // Lebar 600: font test (Ahem) jauh lebih lebar dari font asli.
    await pumpWallet(tester, sample(), size: const Size(600, 1200));
    final transfer = tester.getRect(find.widgetWithText(AppPillButton, 'Transfer'));
    final tambah = tester.getRect(find.widgetWithText(AppPillButton, 'Tambah'));
    expect(transfer.height, 44);
    expect(tambah.height, 44);
    expect(tambah.left - transfer.right, 10);
    expect(tambah.right - transfer.left, lessThan(600 - 64));
  });

  testWidgets('teks sistem diperbesar: pill tidak meluap', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpWallet(tester, sample());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppPillButton, 'Tambah'), findsOneWidget);
  });
}
