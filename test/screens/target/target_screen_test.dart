import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/target_provider.dart';
import 'package:catat_uang_app/screens/target/target_screen.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeTargetNotifier extends TargetNotifier {
  _FakeTargetNotifier(this._initial);
  final TargetState _initial;
  String? depositResult;
  Duration delay = Duration.zero;
  final deposits = <(int, double, int)>[];
  final deleted = <int>[];
  @override
  TargetState build() => _initial;
  @override
  Future<String?> depositToTarget({required TargetModel target, required double rawAmount, required int walletId}) async {
    deposits.add((target.id, rawAmount, walletId));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return depositResult;
  }

  @override
  Future<void> deleteTarget(int id) async => deleted.add(id);
}

TargetState _state({DateTime? pastDeadline}) => TargetState(
      isLoading: false,
      totalSavings: 7300000,
      savingNames: const ['Dana Darurat'],
      wallets: const [
        {'id': 1, 'name': 'BCA', 'balance': 9300000},
      ],
      targets: [
        TargetModel(
          id: 1,
          name: 'Beli iPhone 15',
          targetAmount: 15000000,
          savedAmount: 6750000,
          deadline: pastDeadline ?? DateTime.now().add(const Duration(days: 30)),
          storageLocation: 'Dana Darurat',
        ),
        TargetModel(id: 2, name: 'Liburan Bali', targetAmount: 550000, savedAmount: 550000),
      ],
    );

Future<_FakeTargetNotifier> _pump(WidgetTester tester, TargetState state) async {
  final fake = _FakeTargetNotifier(state);
  await pumpApp(
    tester,
    const TargetScreen(),
    overrides: [targetProvider.overrideWith(() => fake)],
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('menampilkan ringkasan, kartu target, rekomendasi, dan tombol +', (tester) async {
    await _pump(tester, _state());

    expect(find.text('Target Keuangan'), findsWidgets);
    expect(find.text('Total Semua Target'), findsOneWidget);
    expect(find.text('Beli iPhone 15'), findsOneWidget);
    expect(find.text('Dana Darurat'), findsOneWidget);
    expect(find.textContaining('/ hari agar tercapai.'), findsOneWidget);
    expect(find.text('45%'), findsOneWidget);
    expect(find.text('Tercapai!'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tombol Nabung nonaktif untuk target yang sudah tercapai', (tester) async {
    await _pump(tester, _state());

    final buttons = tester.widgetList<AppPillButton>(
      find.byWidgetPredicate((w) => w is AppPillButton && w.label == 'Nabung'),
    ).toList();
    expect(buttons, hasLength(2));
    expect(buttons.where((b) => b.onPressed == null), hasLength(1));
  });

  testWidgets('tombol + membuka sheet "Target Baru"', (tester) async {
    await _pump(tester, _state());
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Target Baru'), findsOneWidget);
    expect(find.text('Misal: Beli iPhone 15'), findsOneWidget);
    expect(find.text('Pilih / Ketik Nama Tabungan'), findsOneWidget);
    expect(find.text('Tenggat Waktu (Opsional)'), findsOneWidget);
    expect(find.text('Simpan Target'), findsOneWidget);
  });

  testWidgets('Edit Target dengan deadline lewat tidak crash saat buka date picker (Review Focus #1)', (tester) async {
    await _pump(tester, _state(pastDeadline: DateTime.now().subtract(const Duration(days: 10))));

    await tester.tap(find.byIcon(PhosphorIconsRegular.pencilSimple).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Target'), findsOneWidget);

    await tester.tap(find.text('Tenggat Waktu'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Pemilih tanggal bersama (Plan B3b), bukan DatePickerDialog Material.
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Pilih Tanggal'), findsOneWidget);
  });

  testWidgets('Nabung membuka sheet dengan info lokasi dan dompet default', (tester) async {
    await _pump(tester, _state());
    await tester.tap(find.byWidgetPredicate((w) => w is AppPillButton && w.label == 'Nabung' && w.onPressed != null));
    await tester.pumpAndSettle();

    expect(find.text('Nabung: Beli iPhone 15'), findsOneWidget);
    expect(find.text('Disimpan di: Dana Darurat'), findsOneWidget);
    // Baris menampilkan nama dompet; "BCA (Sisa: …)" ada di sheet pemilih.
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Setor Tabungan'), findsOneWidget);
  });

  Future<void> openDeposit(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is AppPillButton && w.label == 'Nabung' && w.onPressed != null));
    await tester.pumpAndSettle();
  }

  testWidgets('Setor Tabungan: pesan error provider → toast, sheet tetap terbuka', (tester) async {
    final fake = await _pump(tester, _state());
    fake.depositResult = 'Saldo dompet tidak cukup!';
    await openDeposit(tester);

    await tester.enterText(find.byType(TextField), '50000');
    await tester.tap(find.text('Setor Tabungan'));
    await tester.pump();
    expect(fake.deposits, [(1, 50000.0, 1)]);
    expect(find.text('Saldo dompet tidak cukup!'), findsOneWidget);
    expect(find.text('Nabung: Beli iPhone 15'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Setor Tabungan sukses → sheet tertutup + toast "Berhasil nabung Rp …!"', (tester) async {
    final fake = await _pump(tester, _state());
    await openDeposit(tester);

    await tester.enterText(find.byType(TextField), '50000');
    await tester.tap(find.text('Setor Tabungan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.deposits, hasLength(1));
    expect(find.text('Berhasil nabung Rp 50.000!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('Nabung: Beli iPhone 15'), findsNothing);
  });

  testWidgets('hapus target: dialog konfirmasi teks lama → deleteTarget(id) + toast', (tester) async {
    final fake = await _pump(tester, _state());
    await tester.tap(find.byIcon(PhosphorIconsRegular.trash).first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Target?'), findsOneWidget);
    expect(find.textContaining("Anda yakin ingin menghapus target 'Beli iPhone 15'?"), findsOneWidget);

    await tester.tap(find.text('Hapus').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.deleted, [1]);
    expect(find.text('Target dihapus'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('ketuk ganda Setor Tabungan → nabung diproses sekali', (tester) async {
    final fake = await _pump(tester, _state());
    fake.delay = const Duration(milliseconds: 500);
    await openDeposit(tester);
    await tester.enterText(find.byType(TextField), '50000');
    final button = find.text('Setor Tabungan');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(fake.deposits, hasLength(1));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('sheet Nabung ikut memuat dompet yang datang setelah sheet dibuka', (tester) async {
    final empty = _state();
    final fake = await _pump(
      tester,
      TargetState(isLoading: false, targets: empty.targets, savingNames: empty.savingNames, totalSavings: empty.totalSavings),
    );
    await openDeposit(tester);
    expect(find.text('Buat Dompet'), findsOneWidget);

    fake.state = fake.state.copyWith(wallets: const [
      {'id': 1, 'name': 'BCA', 'balance': 9300000},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('BCA'), findsOneWidget);
  });
}
