import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetDetailScreen extends StatefulWidget {
  final BudgetModel budget;

  const BudgetDetailScreen({super.key, required this.budget});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _totalSpent = 0;

  late BudgetModel _currentBudget;

  @override
  void initState() {
    super.initState();
    _currentBudget = widget.budget;
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final startMonth = DateFormat(
        'yyyy-MM-01',
      ).format(DateTime(_currentBudget.year, _currentBudget.month));
      final nextMonth = DateFormat(
        'yyyy-MM-01',
      ).format(DateTime(_currentBudget.year, _currentBudget.month + 1));

      final res = await _supabase
          .from('transactions')
          .select('id, amount, note, date, category_id')
          .eq('user_id', userId)
          .gte('date', startMonth)
          .lt('date', nextMonth)
          .order('date', ascending: false);

      double spent = 0;
      List<Map<String, dynamic>> filteredData = [];

      for (var item in res) {
        final catId = item['category_id'] as int;
        if (catId == _currentBudget.categoryId) {
          final amount = (item['amount'] as num).toDouble();
          spent += amount;
          filteredData.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _transactions = filteredData;
          _totalSpent = spent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // DIALOG EDIT 
  Future<void> _editBudget() async {
    final amountController = TextEditingController(
      text: NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        decimalDigits: 0,
      ).format(_currentBudget.amount),
    );
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
          ), // Lebar Full
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Edit Anggaran",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          content: SizedBox(
            width: MediaQuery.of(context).size.width, // Lebar Full
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ubah limit untuk ${_currentBudget.category?.name}",
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 15),

                // Input Nominal 
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(
                        "Rp",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
              ],
            ),
          ),

          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  if (amountController.text.isEmpty) return;
                  final cleanAmount = double.parse(
                    amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  );

                  try {
                    await _supabase
                        .from('budgets')
                        .update({'amount': cleanAmount})
                        .eq('id', _currentBudget.id);
                    setState(() {
                      _currentBudget = BudgetModel(
                        id: _currentBudget.id,
                        categoryId: _currentBudget.categoryId,
                        amount: cleanAmount,
                        month: _currentBudget.month,
                        year: _currentBudget.year,
                        category: _currentBudget.category,
                      );
                    });
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted)
                      AppNotification.success(context, "Berhasil diupdate!");
                  } catch (e) {
                    if (context.mounted)
                      AppNotification.error(context, "Gagal update: $e");
                  }
                },
                child: const Text(
                  "Simpan",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
    final progress = _currentBudget.amount == 0
        ? 0.0
        : _totalSpent / _currentBudget.amount;
    final isOver = progress > 1.0;
    final color = isOver
        ? Colors.red
        : (progress > 0.8 ? Colors.orange : AppColors.primary);
    final sisa = _currentBudget.amount - _totalSpent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _currentBudget.category?.name ?? "Detail",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.primary),
            onPressed: _editBudget,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Limit",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          Text(
                            currency.format(_currentBudget.amount),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Terpakai",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          Text(
                            currency.format(_totalSpent),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30, color: Colors.grey),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sisa >= 0 ? "Sisa Anggaran" : "Kelebihan",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currency.format(sisa.abs()),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: sisa >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      LinearProgressIndicator(
                        value: progress > 1 ? 1 : progress,
                        backgroundColor: Colors.grey.shade100,
                        color: color,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      if (isOver)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Over Budget! Hati-hati.",
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Riwayat Pengeluaran",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                size: 50,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Belum ada transaksi",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final trx = _transactions[index];
                            final trxNote = trx['note'] ?? "Pengeluaran";
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trxNote,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd MMM yyyy',
                                        ).format(DateTime.parse(trx['date'])),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    currency.format(trx['amount']),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
