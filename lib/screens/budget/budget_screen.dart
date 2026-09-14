import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/screens/budget/budget_detail_screen.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  void _changeMonth(WidgetRef ref, int offset) {
    ref.read(budgetProvider.notifier).changeMonth(offset);
  }

  void _showMonthYearPicker(BuildContext context, WidgetRef ref, DateTime selectedMonth) {
    int tempMonth = selectedMonth.month;
    int tempYear = selectedMonth.year;
    final currentYear = DateTime.now().year;
    final years = List.generate(11, (i) => (currentYear - 5) + i);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Pilih Periode", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: tempMonth, isExpanded: true, dropdownColor: Colors.white,
                            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2024, index + 1)), style: GoogleFonts.poppins(fontSize: 14), overflow: TextOverflow.ellipsis))),
                            onChanged: (val) => setDialogState(() => tempMonth = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: tempYear, dropdownColor: Colors.white,
                            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                            items: years.map((y) => DropdownMenuItem(value: y, child: Text("$y", style: GoogleFonts.poppins(fontSize: 14)))).toList(),
                            onChanged: (val) => setDialogState(() => tempYear = val!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      ref.read(budgetProvider.notifier).setMonth(DateTime(tempYear, tempMonth));
                      Navigator.pop(context);
                    },
                    child: Text("Tampilkan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _copyFromLastMonth(BuildContext context, WidgetRef ref) async {
    try {
      final copied = await ref.read(budgetProvider.notifier).copyFromLastMonth();
      if (!copied) {
        if (context.mounted) AppNotification.error(context, "Tidak ada data anggaran bulan lalu.");
        return;
      }
      if (context.mounted) AppNotification.success(context, "Berhasil menyalin anggaran!");
    } catch (e) {
      if (context.mounted) AppNotification.error(context, "Gagal menyalin: $e");
    }
  }

  Future<void> _deleteBudget(WidgetRef ref, int id) async {
    await ref.read(budgetProvider.notifier).deleteBudget(id);
  }

  // [UX UPGRADE] DIALOG TAMBAH BERUBAH JADI BOTTOM SHEET
  void _showFormSheet(BuildContext context, WidgetRef ref, DateTime selectedMonth, List<CategoryModel> allCategories) {
    int? selectedCatId;
    int selectedMonthVal = selectedMonth.month;
    int selectedYearVal = selectedMonth.year;

    final amountController = TextEditingController();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    List<CategoryModel> dropdownOptions = allCategories;
    final years = List.generate(11, (i) => (DateTime.now().year - 5) + i);

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Buat Anggaran", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Text("Periode Anggaran", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedMonthVal, isExpanded: true, dropdownColor: Colors.white,
                                items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2024, index + 1)), style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))),
                                onChanged: (val) => setSheetState(() => selectedMonthVal = val!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedYearVal, isExpanded: true, dropdownColor: Colors.white,
                                items: years.map((y) => DropdownMenuItem(value: y, child: Text("$y", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))).toList(),
                                onChanged: (val) => setSheetState(() => selectedYearVal = val!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Text("Pilih Kategori", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          hint: Text("Pilih Kategori Pengeluaran", style: GoogleFonts.poppins(color: Colors.grey)),
                          value: selectedCatId, isExpanded: true, dropdownColor: Colors.white,
                          items: dropdownOptions.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))).toList(),
                          onChanged: (val) => setSheetState(() => selectedCatId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Text("Batas Maksimal (Limit)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.purple),
                      decoration: InputDecoration(
                        filled: true, fillColor: Colors.grey.shade50,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Text("Rp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 18)),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.purple)),
                      ),
                      onChanged: (s) {
                        s = s.replaceAll(RegExp(r'[^0-9]'), '');
                        if (s.isNotEmpty) {
                          amountController.value = TextEditingValue(text: currencyFormat.format(int.parse(s)), selection: TextSelection.collapsed(offset: currencyFormat.format(int.parse(s)).length));
                        }
                      },
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          if (selectedCatId == null || amountController.text.isEmpty) return;
                          try {
                            await ref.read(budgetProvider.notifier).addBudget(
                                  categoryId: selectedCatId!,
                                  month: selectedMonthVal,
                                  year: selectedYearVal,
                                  amount: double.parse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')),
                                );
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) AppNotification.success(context, "Berhasil ditambahkan!");
                          } catch (e) {
                            if (context.mounted) AppNotification.error(context, e.toString());
                          }
                        },
                        child: Text("Simpan Anggaran", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetProvider);
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(state.selectedMonth);
    double totalProgress = state.totalBudget == 0 ? 0 : state.totalSpent / state.totalBudget;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Anggaran", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // [UX UPGRADE] KARTU HEADER PREMIUM
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              children: [
                // Selector Bulan (Pill shape)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(PhosphorIconsBold.caretLeft, color: Colors.grey), onPressed: () => _changeMonth(ref, -1)),
                    GestureDetector(
                      onTap: () => _showMonthYearPicker(context, ref, state.selectedMonth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purple.shade100)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(PhosphorIconsFill.calendarBlank, size: 16, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text(monthLabel, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple.shade700)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.purple),
                          ],
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(PhosphorIconsBold.caretRight, color: Colors.grey), onPressed: () => _changeMonth(ref, 1)),
                  ],
                ),
                const SizedBox(height: 15),

                // Kartu Gradien
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF5E35B1), Color(0xFF3949AB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF5E35B1).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Terpakai Bulan Ini", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                              Text(currency.format(state.totalSpent), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Total Anggaran", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                              Text(currency.format(state.totalBudget), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: totalProgress > 1 ? 1 : totalProgress,
                          color: state.totalSpent > state.totalBudget ? Colors.redAccent : Colors.tealAccent,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.budgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsFill.chartDonut, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("Belum ada anggaran", style: GoogleFonts.poppins(color: Colors.grey)),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => _copyFromLastMonth(context, ref), icon: const Icon(PhosphorIconsBold.copy), label: Text("Salin Bulan Lalu", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20), physics: const BouncingScrollPhysics(),
                    itemCount: state.budgets.length,
                    itemBuilder: (context, index) {
                      final budget = state.budgets[index];
                      final spent = state.spendingMap[budget.categoryId] ?? 0;
                      final progress = budget.amount == 0 ? 0.0 : spent / budget.amount;
                      final color = progress > 1 ? Colors.red : (progress > 0.8 ? Colors.orange : Colors.purple);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget)));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                        child: Icon(PhosphorIconsFill.tag, color: color, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(budget.category?.name ?? "-", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: Colors.white, title: Text("Hapus?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)), content: Text("Yakin hapus anggaran ini?", style: GoogleFonts.poppins()),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                                            TextButton(onPressed: () { Navigator.pop(ctx); _deleteBudget(ref, budget.id); }, child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(currency.format(spent), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                                  Text(" / ${currency.format(budget.amount)}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: progress > 1 ? 1 : progress, color: color, backgroundColor: Colors.grey.shade100, minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: state.budgets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showFormSheet(context, ref, state.selectedMonth, state.allCategories),
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text("Anggaran", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
    );
  }
}
