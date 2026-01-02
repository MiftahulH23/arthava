import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<BudgetModel> _budgets = [];
  Map<int, double> _spendingMap = {};
  List<CategoryModel> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (mounted) setState(() => _isLoading = true);
    await _fetchCategories();
    await _fetchBudgets();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final catRes = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', true)
          .or('user_id.eq.$userId,user_id.is.null');

      if (mounted) {
        setState(() {
          _availableCategories = (catRes as List)
              .map((e) => CategoryModel.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error Categories: $e");
    }
  }

  Future<void> _fetchBudgets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final startMonth = DateFormat('yyyy-MM-01').format(now);
      final nextMonth = DateFormat(
        'yyyy-MM-01',
      ).format(DateTime(now.year, now.month + 1, 1));

      // 1. QUERY BUDGET (Tabel 'budgets')
      final budgetRes = await _supabase
          .from('budgets') // Sudah kembali ke nama tabel asli
          .select('id, amount, category_id')
          .eq('user_id', userId);

      final List<BudgetModel> budgets = [];
      for (var item in (budgetRes as List)) {
        final catId = item['category_id'] as int;

        final category = _availableCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () => CategoryModel(
            id: catId,
            name: "Dihapus",
            isExpense: true,
            iconName: "warning",
            userId: userId,
          ),
        );

        budgets.add(
          BudgetModel(
            id: item['id'],
            categoryId: catId,
            amount: (item['amount'] as num).toDouble(),
            category: category,
          ),
        );
      }

      // 2. QUERY TRANSAKSI
      // Filter manual di bawah biar tidak kena PGRST108
      final trxRes = await _supabase
          .from('transactions')
          .select('amount, category_id')
          .eq('user_id', userId)
          .gte('date', startMonth)
          .lt('date', nextMonth);

      Map<int, double> spending = {};
      for (var item in trxRes) {
        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();

        // Cek manual apakah kategori ini adalah Pengeluaran
        final isExpenseCat = _availableCategories.any(
          (c) => c.id == catId && c.isExpense,
        );

        if (isExpenseCat) {
          spending[catId] = (spending[catId] ?? 0) + amount;
        }
      }

      if (mounted) {
        setState(() {
          _budgets = budgets;
          _spendingMap = spending;
        });
      }
    } catch (e) {
      debugPrint("Error Budgets: $e");
      if (mounted) AppNotification.error(context, "Gagal memuat anggaran: $e");
    }
  }

  Future<void> _addBudget(int categoryId, double amount) async {
    try {
      // Cek lokal dulu biar UI responsif
      final existing = _budgets.where((b) => b.categoryId == categoryId);

      if (existing.isNotEmpty) {
        // Update
        await _supabase
            .from('budgets')
            .update({'amount': amount})
            .eq('id', existing.first.id);
      } else {
        // Insert (Gunakan upsert biar lebih aman kalau constraint unique kena)
        await _supabase.from('budgets').upsert({
          'user_id': _supabase.auth.currentUser!.id,
          'category_id': categoryId,
          'amount': amount,
        }, onConflict: 'user_id, category_id');
      }

      if (mounted) {
        Navigator.pop(context);
        _initData();
        AppNotification.success(context, "Anggaran berhasil disimpan!");
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, "Error: $e");
    }
  }

  Future<void> _deleteBudget(int id) async {
    try {
      await _supabase.from('budgets').delete().eq('id', id);
      _initData();
      if (mounted) AppNotification.success(context, "Anggaran dihapus");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal hapus: $e");
    }
  }

  void _showAddDialog() {
    int? selectedCatId;
    final amountController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Buat Anggaran",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Kategori Pengeluaran",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedCatId,
                          hint: Text(
                            "Pilih Kategori",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.primary,
                          ),
                          items: _availableCategories.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text("Memuat kategori..."),
                                  ),
                                ]
                              : _availableCategories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat.id,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          PhosphorIconsFill.tag,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          cat.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          onChanged: _availableCategories.isEmpty
                              ? null
                              : (val) =>
                                    setDialogState(() => selectedCatId = val),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      "Limit Anggaran (Bulanan)",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(15),
                            child: Text(
                              "Rp",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          hintText: "0",
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                        onChanged: (string) {
                          string = string.replaceAll(RegExp(r'[^0-9]'), '');
                          if (string.isNotEmpty) {
                            final formatted = currencyFormat.format(
                              int.parse(string),
                            );
                            if (amountController.text != formatted) {
                              amountController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (selectedCatId == null ||
                          amountController.text.isEmpty)
                        return;
                      final cleanAmount = amountController.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      _addBudget(selectedCatId!, double.parse(cleanAmount));
                    },
                    child: Text(
                      "Simpan Anggaran",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Anggaran Bulanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      PhosphorIconsFill.chartDonut,
                      size: 80,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Belum ada anggaran",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 50,
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("Buat Baru"),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _budgets.length,
              itemBuilder: (context, index) {
                final budget = _budgets[index];
                final spent = _spendingMap[budget.categoryId] ?? 0;
                final progress = budget.amount == 0
                    ? 0.0
                    : spent / budget.amount;
                final isOverBudget = progress > 1.0;
                final color = isOverBudget
                    ? Colors.red
                    : (progress > 0.8 ? Colors.orange : AppColors.primary);

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  PhosphorIconsFill.tag,
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Text(
                                budget.category?.name ?? "Kategori",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  surfaceTintColor: Colors.transparent,
                                  title: const Text("Hapus Anggaran?"),
                                  content: const Text(
                                    "Anda yakin ingin menghapus anggaran ini?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Batal"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _deleteBudget(budget.id);
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
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Terpakai",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                currency.format(spent),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Limit",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                currency.format(budget.amount),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress > 1 ? 1 : progress,
                          backgroundColor: Colors.grey.shade100,
                          color: color,
                          minHeight: 12,
                        ),
                      ),

                      if (isOverBudget)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "Over Budget! Kurangi pengeluaran.",
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: _budgets.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
