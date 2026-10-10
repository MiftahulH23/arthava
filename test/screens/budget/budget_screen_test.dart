import 'package:arthava/core/colors.dart';
import 'package:arthava/models/budget_model.dart';
import 'package:arthava/models/category_model.dart';
import 'package:arthava/providers/budget_provider.dart';
import 'package:arthava/screens/budget/budget_screen.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeBudgetNotifier extends BudgetNotifier {
  _FakeBudgetNotifier(this._initial);
  final BudgetState _initial;
  final deleted = <int>[];
  var copyResult = true;
  @override
  BudgetState build() => _initial;
  @override
  Future<void> deleteBudget(int id) async => deleted.add(id);
  @override
  Future<bool> copyFromLastMonth() async => copyResult;
}

final _food = CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'tag');
final _shop = CategoryModel(id: 2, name: 'Belanja', isExpense: true, iconName: 'tag');
final _fun = CategoryModel(id: 3, name: 'Hiburan', isExpense: true, iconName: 'tag');

BudgetState _filledState() => BudgetState(
      isLoading: false,
      selectedMonth: DateTime(2026, 9),
      budgets: [
        BudgetModel(id: 10, categoryId: 1, amount: 1500000, month: 9, year: 2026, category: _food),
        BudgetModel(id: 11, categoryId: 2, amount: 1500000, month: 9, year: 2026, category: _shop),
        BudgetModel(id: 12, categoryId: 3, amount: 1000000, month: 9, year: 2026, category: _fun),
      ],
      spendingMap: {1: 1230000, 2: 1690000, 3: 100000},
      allCategories: [_food, _shop, _fun],
      totalBudget: 4000000,
      totalSpent: 3020000,
    );

Future<_FakeBudgetNotifier> _pump(WidgetTester tester, BudgetState state) async {
  final fake = _FakeBudgetNotifier(state);
  await pumpApp(
    tester,
    const BudgetScreen(),
    overrides: [budgetProvider.overrideWith(() => fake)],
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('menampilkan judul besar, hero, pemilih bulan, dan baris anggaran', (tester) async {
    await _pump(tester, _filledState());

    expect(find.text('Anggaran'), findsWidgets);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Terpakai Bulan Ini'), findsOneWidget);
    expect(find.text('Total Anggaran'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Belanja'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(AppNavAction), findsOneWidget);
  });

  testWidgets('warna status mengikuti threshold 80% dan 100% (Review Focus #4)', (tester) async {
    await _pump(tester, _filledState());

    final colors = tester
        .widgetList<AppProgressBar>(find.byType(AppProgressBar))
        .map((bar) => bar.color)
        .toList();
    // hero (putih) + Makan 82% (oranye) + Belanja 113% (merah) + Hiburan 10% (primary)
    expect(colors, containsAll([AppColors.tintOrange, AppColors.expense, AppColors.primary]));
  });

  testWidgets('empty state tetap punya tombol + dan "Salin Bulan Lalu" (Review Focus #5)', (tester) async {
    await _pump(tester, BudgetState(isLoading: false, selectedMonth: DateTime(2026, 9)));

    expect(find.text('Belum ada anggaran'), findsOneWidget);
    expect(find.text('Salin Bulan Lalu'), findsOneWidget);
    expect(find.byType(AppNavAction), findsOneWidget);
  });

  testWidgets('tombol + membuka sheet "Buat Anggaran" dengan field lengkap', (tester) async {
    await _pump(tester, _filledState());

    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();

    expect(find.text('Buat Anggaran'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Periode Anggaran'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Pilih Kategori'), findsOneWidget);
    expect(find.text('Batas Maksimal (Limit)'), findsOneWidget);
    expect(find.text('Simpan Anggaran'), findsOneWidget);
  });

  testWidgets('geser baris → Hapus → dialog "Yakin hapus anggaran ini?" → deleteBudget(id)', (tester) async {
    final fake = await _pump(tester, _filledState());

    await tester.drag(find.text('Belanja'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus?'), findsOneWidget);
    expect(find.text('Yakin hapus anggaran ini?'), findsOneWidget);

    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(fake.deleted, [11]);
  });

  testWidgets('Salin Bulan Lalu tanpa data → toast "Tidak ada data anggaran bulan lalu."', (tester) async {
    final fake = await _pump(tester, BudgetState(isLoading: false, selectedMonth: DateTime(2026, 9)));
    fake.copyResult = false;

    await tester.tap(find.text('Salin Bulan Lalu'));
    await tester.pump();
    expect(find.text('Tidak ada data anggaran bulan lalu.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
