import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ManageCategoryScreen extends ConsumerWidget {
  const ManageCategoryScreen({super.key});

  // [UPDATE: Fungsi pintar untuk membaca icon_name atau menebak dari namanya]
  IconData _getCategoryIcon(String categoryName, String? iconName) {
    final name = categoryName.toLowerCase();

    // 1. Prioritaskan jika iconName dari database cocok dengan string
    if (iconName == 'food' || name.contains('makan'))
      return PhosphorIcons.bowlFood(PhosphorIconsStyle.fill);
    if (iconName == 'drink' ||
        name.contains('minum') ||
        name.contains('kopi') ||
        name.contains('cafe'))
      return PhosphorIcons.coffee(PhosphorIconsStyle.fill);
    if (iconName == 'transport' ||
        name.contains('transport') ||
        name.contains('bensin'))
      return PhosphorIcons.bus(PhosphorIconsStyle.fill);
    if (iconName == 'shopping' ||
        name.contains('belanja') ||
        name.contains('mart'))
      return PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill);
    if (iconName == 'entertainment' ||
        name.contains('hiburan') ||
        name.contains('nonton'))
      return PhosphorIcons.gameController(PhosphorIconsStyle.fill);
    if (iconName == 'health' ||
        name.contains('kesehatan') ||
        name.contains('obat'))
      return PhosphorIcons.firstAid(PhosphorIconsStyle.fill);
    if (iconName == 'bill' ||
        name.contains('tagihan') ||
        name.contains('listrik'))
      return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
    if (iconName == 'salary' || name.contains('gaji'))
      return PhosphorIcons.money(PhosphorIconsStyle.fill);
    if (iconName == 'gift' || name.contains('bonus'))
      return PhosphorIcons.gift(PhosphorIconsStyle.fill);
    if (iconName == 'bank' || name.contains('tabung'))
      return PhosphorIcons.bank(PhosphorIconsStyle.fill);

    // Default Icon
    return PhosphorIcons.tag(PhosphorIconsStyle.fill);
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(categoryProvider.notifier).deleteCategory(id);
      if (context.mounted)
        AppNotification.success(context, "Kategori berhasil dihapus!");
    } catch (e) {
      if (context.mounted)
        AppNotification.error(
          context,
          "Gagal hapus. Kategori sedang digunakan.",
        );
    }
  }

  void _showInputDialog(
    BuildContext context,
    WidgetRef ref, {
    CategoryModel? categoryToEdit,
  }) {
    final isEditing = categoryToEdit != null;
    final isExpense = ref.read(categoryProvider).isExpense;
    final controller = TextEditingController(
      text: isEditing ? categoryToEdit.name : '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: Center(
                child: Text(
                  isEditing
                      ? "Edit Kategori"
                      : (isExpense
                            ? "Tambah Pengeluaran"
                            : "Tambah Pemasukan"),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              content: SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "Nama Kategori (Contoh: Bensin)",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  enabled: !isSaving,
                ),
              ),

              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Batal",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (controller.text.trim().isEmpty) return;
                                setDialogState(() => isSaving = true);
                                try {
                                  if (isEditing) {
                                    await ref
                                        .read(categoryProvider.notifier)
                                        .editCategory(
                                          categoryToEdit.id,
                                          controller.text.trim(),
                                        );
                                  } else {
                                    await ref
                                        .read(categoryProvider.notifier)
                                        .addCategory(controller.text.trim());
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    AppNotification.success(
                                      context,
                                      isEditing
                                          ? "Berhasil diubah!"
                                          : "Berhasil ditambah!",
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSaving = false);
                                  if (context.mounted)
                                    AppNotification.error(context, "Error: $e");
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Simpan",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoryProvider);
    final isExpense = state.isExpense;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Kelola Kategori",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _buildToggleBtn(ref, "Pengeluaran", true, isExpense),
                  _buildToggleBtn(ref, "Pemasukan", false, isExpense),
                ],
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.categories.isEmpty
                ? Center(
                    child: Text(
                      "Belum ada kategori",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: state.categories.length,
                    itemBuilder: (context, index) {
                      final cat = state.categories[index];
                      final isSystem = cat.userId == null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? AppColors.expense.withOpacity(0.1)
                                    : AppColors.income.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // [UPDATE: Panggil fungsi getCategoryIcon di sini]
                              child: Icon(
                                _getCategoryIcon(cat.name, cat.iconName),
                                color: isExpense
                                    ? AppColors.expense
                                    : AppColors.income,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (isSystem)
                                    Text(
                                      "Bawaan Aplikasi",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!isSystem) ...[
                              IconButton(
                                icon: const Icon(
                                  PhosphorIconsFill.pencilSimple,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () => _showInputDialog(
                                  context,
                                  ref,
                                  categoryToEdit: cat,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  PhosphorIconsFill.trash,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      surfaceTintColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      title: const Text("Hapus Kategori?"),
                                      content: Text(
                                        "Yakin mau hapus '${cat.name}'?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Batal"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteCategory(context, ref, cat.id);
                                          },
                                          child: const Text(
                                            "Hapus",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInputDialog(context, ref),
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildToggleBtn(
    WidgetRef ref,
    String title,
    bool isExpenseBtn,
    bool currentIsExpense,
  ) {
    final bool isSelected = currentIsExpense == isExpenseBtn;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (currentIsExpense != isExpenseBtn) {
            ref.read(categoryProvider.notifier).fetchCategories(
                  isExpense: isExpenseBtn,
                );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isExpenseBtn ? AppColors.expense : AppColors.income)
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
