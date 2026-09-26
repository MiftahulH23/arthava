import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/providers/savings_provider.dart';
import 'package:catat_uang_app/screens/savings/savings_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeSavingsNotifier extends SavingsNotifier {
  _FakeSavingsNotifier(this._initial);
  final SavingsState _initial;
  final calls = <String>[];
  String? processResult;
  @override
  SavingsState build() => _initial;
  @override
  Future<String?> processSavingTransaction({
    required bool isDeposit,
    required String savingName,
    required double amount,
    required int walletId,
    String? location,
    String? notes,
  }) async {
    calls.add('process:$isDeposit:$savingName:$amount:$walletId:$location:$notes');
    return processResult;
  }

  @override
  Future<void> addEmptyGroup({required String name, required String location, required String notes}) async =>
      calls.add('empty:$name:$location:$notes');

  @override
  Future<void> deleteGroup(String groupName) async => calls.add('delete:$groupName');
}

SavingModel _saving(int id, String name, double amount, {String? location}) => SavingModel(
      id: id,
      userId: 'u1',
      name: name,
      amount: amount,
      location: location,
      createdAt: DateTime(2026, 9, 24, 9, 12),
    );

Future<_FakeSavingsNotifier> _pump(WidgetTester tester, SavingsState state) async {
  final fake = _FakeSavingsNotifier(state);
  await pumpApp(
    tester,
    const SavingsScreen(),
    overrides: [savingsProvider.overrideWith(() => fake)],
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  const longName = 'Tabungan Untuk Pernikahan Adik Bungsu Tahun Depan Di Gedung Serbaguna';

  SavingsState filled() => SavingsState(
        isLoading: false,
        totalSavings: 24500000,
        wallets: const [
          {'id': 1, 'name': 'BCA', 'balance': 9300000},
        ],
        groupedSavings: {
          'Dana Darurat': [_saving(1, 'Dana Darurat', 18000000, location: 'Bank BCA')],
          longName: [_saving(2, longName, 6500000)],
        },
      );

  testWidgets('menampilkan hero, kartu tabungan, tombol Setor/Tarik, dan +', (tester) async {
    await _pump(tester, filled());

    expect(find.text('Buku Tabungan'), findsWidgets);
    expect(find.text('Total Semua Tabungan'), findsOneWidget);
    expect(find.text('Dana Darurat'), findsOneWidget);
    expect(find.text('Bank BCA'), findsOneWidget);
    expect(find.text('Setor'), findsNWidgets(2));
    expect(find.text('Tarik'), findsNWidgets(2));
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('nama tabungan sangat panjang tidak overflow (Review Focus #3)', (tester) async {
    await _pump(tester, filled());
    expect(tester.takeException(), isNull);
    expect(find.text(longName), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, const SavingsState(isLoading: false));
    expect(find.text('Belum ada tabungan'), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet "Buat Tabungan" dengan field lengkap', (tester) async {
    await _pump(tester, filled());
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Buat Tabungan'), findsOneWidget);
    expect(find.text('Contoh: Dana Darurat'), findsOneWidget);
    expect(find.text('Contoh: Bank BCA'), findsOneWidget);
    expect(find.text('Tulis catatan singkat...'), findsOneWidget);
    expect(find.textContaining('BCA (Sisa:'), findsOneWidget);
    expect(find.text('Setoran Awal (Opsional)'), findsOneWidget);
    expect(find.text('Simpan Tabungan'), findsOneWidget);
  });

  testWidgets('Setor membuka sheet "Setor ke …"', (tester) async {
    await _pump(tester, filled());
    await tester.tap(find.text('Setor').first);
    await tester.pumpAndSettle();
    expect(find.text('Setor ke Dana Darurat'), findsOneWidget);
    expect(find.text('Konfirmasi Setoran'), findsOneWidget);
  });

  Future<void> settleToast(WidgetTester tester) => tester.pumpAndSettle(const Duration(seconds: 5));

  testWidgets('Buat Tabungan: nama kosong → toast, tidak menyimpan', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Tabungan'));
    await tester.tap(find.text('Simpan Tabungan'));
    await tester.pump();
    expect(find.text('Nama tabungan tidak boleh kosong!'), findsOneWidget);
    expect(fake.calls, isEmpty);
    await settleToast(tester);
  });

  testWidgets('Buat Tabungan tanpa setoran → addEmptyGroup + "Tabungan berhasil dibuat!"', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Dana Darurat'), '  Liburan ');
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: Bank BCA'), ' Jago ');
    await tester.ensureVisible(find.text('Simpan Tabungan'));
    await tester.tap(find.text('Simpan Tabungan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.calls, ['empty:Liburan:Jago:']);
    expect(find.text('Tabungan berhasil dibuat!'), findsOneWidget);
    await settleToast(tester);
    expect(find.text('Simpan Tabungan'), findsNothing);
  });

  testWidgets('Tarik: nominal kosong → "Isi nominal dengan benar!"; terisi → proses isDeposit=false', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.text('Tarik').first);
    await tester.pumpAndSettle();
    expect(find.text('Tarik dari Dana Darurat'), findsOneWidget);

    await tester.tap(find.text('Konfirmasi Penarikan'));
    await tester.pump();
    expect(find.text('Isi nominal dengan benar!'), findsOneWidget);
    expect(fake.calls, isEmpty);
    await settleToast(tester);

    await tester.enterText(find.byType(TextField), '100000');
    await tester.tap(find.text('Konfirmasi Penarikan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.calls, ['process:false:Dana Darurat:100000.0:1:null:null']);
    expect(find.text('Berhasil Dicairkan!'), findsOneWidget);
    await settleToast(tester);
  });

  testWidgets('hapus tabungan: dialog teks lama → deleteGroup + "Tabungan dihapus"', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.byIcon(PhosphorIconsRegular.trash).first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Tabungan?'), findsOneWidget);
    expect(find.textContaining("Anda yakin ingin menghapus 'Dana Darurat'?"), findsOneWidget);
    await tester.tap(find.text('Hapus').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.calls, ['delete:Dana Darurat']);
    expect(find.text('Tabungan dihapus'), findsOneWidget);
    await settleToast(tester);
  });
}
