import 'package:arthava/models/category_model.dart';
import 'package:arthava/providers/category_provider.dart';
import 'package:arthava/screens/manage_category/manage_category_screen.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class FakeCategoryNotifier extends CategoryNotifier {
  FakeCategoryNotifier(this.initial);
  final CategoryState initial;
  final List<String> calls = [];

  @override
  CategoryState build() => initial;

  @override
  Future<void> fetchCategories({bool? isExpense}) async {
    calls.add('fetch:$isExpense');
    state = state.copyWith(isExpense: isExpense ?? state.isExpense, isLoading: false);
  }

  @override
  Future<void> addCategory(String name) async => calls.add('add:$name');

  @override
  Future<void> editCategory(int id, String newName) async => calls.add('edit:$id:$newName');

  @override
  Future<void> deleteCategory(int id) async => calls.add('delete:$id');
}

CategoryState _state() => CategoryState(
      isLoading: false,
      isExpense: true,
      categories: [
        CategoryModel(id: 1, name: 'Makan', isExpense: true, iconName: 'food'),
        CategoryModel(id: 5, name: 'Bensin', isExpense: true, iconName: 'tag', userId: 'u1'),
      ],
    );

Future<FakeCategoryNotifier> _pump(WidgetTester tester) async {
  final fake = FakeCategoryNotifier(_state());
  await pumpApp(tester, const ManageCategoryScreen(), overrides: [categoryProvider.overrideWith(() => fake)]);
  await tester.pump();
  return fake;
}

void main() {
  testWidgets('menampilkan kategori bawaan dan buatan user', (tester) async {
    await _pump(tester);
    expect(find.byType(AppPageScaffold), findsOneWidget);
    expect(find.text('Kelola Kategori'), findsOneWidget);
    expect(find.text('Makan'), findsOneWidget);
    expect(find.text('Bawaan Aplikasi'), findsOneWidget);
    expect(find.text('Bensin'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.pencilSimple), findsNothing);
    expect(find.byIcon(PhosphorIconsFill.trash), findsNothing);
  });

  testWidgets('segmented Pemasukan memanggil fetchCategories(isExpense: false)', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.text('Pemasukan'));
    await tester.pump();
    expect(fake.calls, contains('fetch:false'));
  });

  testWidgets('simpan nama kosong tidak memanggil provider', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Pengeluaran'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(fake.calls.where((c) => c.startsWith('add:')), isEmpty);
    expect(find.text('Tambah Pengeluaran'), findsOneWidget);
  });

  testWidgets('tambah kategori baru', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byType(AppNavAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Parkir');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('add:Parkir'));
    expect(find.text('Berhasil ditambah!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('hapus kategori lewat dialog konfirmasi', (tester) async {
    final fake = await _pump(tester);
    await tester.drag(find.text('Bensin'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Kategori?'), findsOneWidget);
    expect(find.text("Yakin mau hapus 'Bensin'?"), findsOneWidget);
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();
    expect(fake.calls, contains('delete:5'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('geser layar ke kiri memanggil fetchCategories(isExpense: false)', (tester) async {
    final fake = await _pump(tester);
    await tester.timedDrag(find.text('Kelola Kategori'), const Offset(-250, 0), const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('fetch:false'));
  });

  testWidgets('kategori bawaan tidak bisa digeser hapus; kategori user bisa diedit lewat geser', (tester) async {
    await _pump(tester);
    await tester.drag(find.text('Makan'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('Hapus'), findsNothing);
    await tester.drag(find.text('Bensin'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Kategori'), findsOneWidget);
  });
}
