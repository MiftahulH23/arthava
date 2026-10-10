import 'package:arthava/models/category_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryState {
  final List<CategoryModel> categories;
  final bool isExpense;
  final bool isLoading;

  const CategoryState({
    this.categories = const [],
    this.isExpense = true,
    this.isLoading = true,
  });

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isExpense,
    bool? isLoading,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isExpense: isExpense ?? this.isExpense,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CategoryNotifier extends AutoDisposeNotifier<CategoryState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  CategoryState build() {
    // Sama seperti WalletNotifier: jangan baca/tulis `state` secara sinkron
    // di sini, karena state baru diinisialisasi Riverpod SETELAH build()
    // return. Future.microtask menunda fetch pertama sampai build() selesai.
    Future.microtask(fetchCategories);
    return const CategoryState();
  }

  Future<void> fetchCategories({bool? isExpense}) async {
    final targetIsExpense = isExpense ?? state.isExpense;
    state = state.copyWith(isExpense: targetIsExpense, isLoading: true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', targetIsExpense)
          .or('user_id.is.null,user_id.eq.$userId')
          .order('id', ascending: true);

      final data = response as List<dynamic>;
      state = state.copyWith(
        categories: data.map((json) => CategoryModel.fromJson(json)).toList(),
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Error fetch categories: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addCategory(String name) async {
    await _supabase.from('categories').insert({
      'name': name,
      'is_expense': state.isExpense,
      'user_id': _supabase.auth.currentUser!.id,
      'icon_name': 'tag', // Beri default tag untuk kategori buatan user
    });
    await fetchCategories();
  }

  Future<void> editCategory(int id, String newName) async {
    await _supabase.from('categories').update({'name': newName}).eq('id', id);
    await fetchCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _supabase.from('categories').delete().eq('id', id);
    await fetchCategories();
  }
}

final categoryProvider =
    NotifierProvider.autoDispose<CategoryNotifier, CategoryState>(
      CategoryNotifier.new,
    );
