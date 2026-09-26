import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/providers/recurring_provider.dart';
import 'package:catat_uang_app/screens/recurring/recurring_screen.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeRecurringNotifier extends RecurringNotifier {
  _FakeRecurringNotifier(this._initial);
  final RecurringState _initial;
  final calls = <String>[];
  @override
  RecurringState build() => _initial;
  @override
  Future<void> toggleActive(RecurringTransactionModel item, bool value) async => calls.add('toggle:${item.id}:$value');
  @override
  Future<void> deleteItem(int id) async => calls.add('delete:$id');
  @override
  Future<void> addRecurring(Map<String, dynamic> data) async => calls.add('add');
}

RecurringTransactionModel _item({
  required int id,
  required String category,
  required bool isExpense,
  required double amount,
  required bool active,
  int? walletId,
  String? note,
}) =>
    RecurringTransactionModel(
      id: id,
      userId: 'u1',
      categoryId: id,
      amount: amount,
      note: note,
      frequency: 'Bulanan',
      startDate: DateTime(2026, 9, 1),
      nextRunDate: DateTime(2026, 10, 1),
      isActive: active,
      category: {'id': id, 'name': category, 'is_expense': isExpense},
      walletId: walletId,
    );

Future<_FakeRecurringNotifier> _pump(WidgetTester tester, RecurringState state) async {
  final fake = _FakeRecurringNotifier(state);
  await pumpApp(
    tester,
    const RecurringScreen(),
    overrides: [recurringProvider.overrideWith(() => fake)],
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  RecurringState filled() => RecurringState(
        isLoading: false,
        wallets: const [
          {'id': 1, 'name': 'BCA'},
        ],
        categories: const [
          {'id': 1, 'name': 'Kos', 'is_expense': true},
          {'id': 2, 'name': 'Gaji', 'is_expense': false},
        ],
        recurringList: [
          _item(id: 1, category: 'Kos', isExpense: true, amount: 1500000, active: true, walletId: 1, note: 'Bayar kos bulanan'),
          _item(id: 2, category: 'Gaji', isExpense: false, amount: 8000000, active: true, walletId: 1),
          _item(id: 3, category: 'Hiburan', isExpense: true, amount: 186000, active: false, walletId: 99),
        ],
      );

  testWidgets('menampilkan kartu jadwal dengan chip, nominal bertanda, switch, dan tanggal lanjut', (tester) async {
    await _pump(tester, filled());

    expect(find.text('Tagihan & Pemasukan Rutin'), findsWidgets);
    expect(find.text('Kos'), findsOneWidget);
    expect(find.text('Bayar kos bulanan'), findsOneWidget);
    expect(find.text('Per Bulanan'), findsNWidgets(3));
    expect(find.text('BCA'), findsNWidgets(2));
    expect(find.text('Dompet Dihapus'), findsOneWidget);
    expect(find.text('-Rp 1.500.000'), findsOneWidget);
    expect(find.text('+Rp 8.000.000'), findsOneWidget);
    expect(find.byType(AppSwitch), findsNWidgets(3));
    expect(find.textContaining('Lanjut:'), findsNWidgets(3));
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('jadwal nonaktif diredupkan', (tester) async {
    await _pump(tester, filled());
    expect(find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.55), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, const RecurringState(isLoading: false));
    expect(find.text('Belum ada jadwal otomatis'), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet "Buat Jadwal Tagihan"', (tester) async {
    await _pump(tester, filled());
    await tester.tap(find.byWidgetPredicate((w) => w is AppNavAction).first);
    await tester.pumpAndSettle();

    expect(find.text('Buat Jadwal Tagihan'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Potong Dari Dompet Mana?'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Diulang Setiap'), findsOneWidget);
    expect(find.text('Mulai Tanggal (Jatuh Tempo Pertama)'), findsOneWidget);
    expect(find.text('Simpan Jadwal'), findsOneWidget);

    await tester.tap(find.text('Pemasukan'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Ke Dompet Mana?'), findsOneWidget);
  });

  testWidgets('switch memanggil toggleActive(item, nilai baru)', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pumpAndSettle();
    expect(fake.calls, hasLength(1));
    expect(fake.calls.single, startsWith('toggle:'));
  });

  testWidgets('hapus jadwal: dialog teks lama → deleteItem + "Jadwal otomatis dihapus"', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.byIcon(PhosphorIconsRegular.trash).first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Jadwal?'), findsOneWidget);
    expect(find.text('Jadwal otomatis ini akan dihentikan dan dihapus dari daftar.'), findsOneWidget);
    await tester.tap(find.text('Hapus').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.calls.single, startsWith('delete:'));
    expect(find.text('Jadwal otomatis dihapus'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Simpan Jadwal tanpa nominal/kategori → toast validasi, tidak menyimpan', (tester) async {
    final fake = await _pump(tester, filled());
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Jadwal'));
    await tester.tap(find.text('Simpan Jadwal'));
    await tester.pump();
    expect(find.text('Nominal, Kategori, dan Dompet wajib diisi!'), findsOneWidget);
    expect(fake.calls, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
