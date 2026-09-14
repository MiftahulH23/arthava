import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/providers/budget_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetDetailScreen extends ConsumerStatefulWidget {
  final BudgetModel budget;

  const BudgetDetailScreen({super.key, required this.budget});

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _totalSpent = 0;

  // [NEW] Persiapan Data Dompet
  Map<int, String> _walletNames = {};
  Map<int, Color> _walletColors = {};

  @override
  void initState() {
    super.initState();
    _fetchWallets(); // Panggil dompet dulu
    _fetchTransactions();
  }

  // [NEW] Fungsi buat ngambil nama & warna dompet
  Future<void> _fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId);
      if (mounted) {
        setState(() {
          for (var w in res as List) {
            _walletNames[w['id']] = w['name'].toString();
            final colorHex = w['color']?.toString() ?? '#1E3A8A';
            _walletColors[w['id']] = Color(
              int.parse(colorHex.replaceFirst('#', '0xFF')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error wallets: $e");
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final startMonth = DateFormat(
        'yyyy-MM-01',
      ).format(DateTime(widget.budget.year, widget.budget.month));
      final nextMonth = DateFormat(
        'yyyy-MM-01',
      ).format(DateTime(widget.budget.year, widget.budget.month + 1));

      // [UPDATE] Tambahin wallet_id di select query
      final res = await _supabase
          .from('transactions')
          .select('id, amount, note, date, category_id, wallet_id')
          .eq('user_id', userId)
          .gte('date', startMonth)
          .lt('date', nextMonth)
          .order('date', ascending: false);

      double spent = 0;
      List<Map<String, dynamic>> filteredData = [];

      for (var item in res) {
        final catId = item['category_id'] as int;
        final noteStr = item['note']?.toString() ?? '';

        // [FIX] Celah gaib ditutup! Mutasi tabungan gak boleh masuk hitungan anggaran
        if (noteStr.contains('[SAVING_ID:')) continue;

        if (catId == widget.budget.categoryId) {
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

  // [UX UPGRADE] DIALOG EDIT BERUBAH JADI BOTTOM SHEET
  void _showEditSheet(BudgetModel currentBudget) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    final amountController = TextEditingController(
      text: currencyFormat.format(currentBudget.amount),
    );

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
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Edit Anggaran",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      "Ubah limit untuk kategori ${currentBudget.category?.name}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Batas Maksimal (Limit)",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.purple,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 15, right: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Rp",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                      ),
                      onChanged: (s) {
                        s = s.replaceAll(RegExp(r'[^0-9]'), '');
                        if (s.isNotEmpty) {
                          amountController.value = TextEditingValue(
                            text: currencyFormat.format(int.parse(s)),
                            selection: TextSelection.collapsed(
                              offset: currencyFormat
                                  .format(int.parse(s))
                                  .length,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          if (amountController.text.isEmpty) return;
                          final cleanAmount = double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );

                          try {
                            await ref
                                .read(budgetProvider.notifier)
                                .updateBudgetAmount(currentBudget.id, cleanAmount);
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              AppNotification.success(
                                context,
                                "Limit berhasil diperbarui!",
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppNotification.error(
                                context,
                                "Gagal update limit",
                              );
                            }
                          }
                        },
                        child: Text(
                          "Simpan Perubahan",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
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
  Widget build(BuildContext context) {
    // Anggaran ini juga ditampilkan di daftar BudgetScreen lewat
    // budgetProvider yang sama — cari versi terkini dari state supaya
    // perubahan `amount` lewat _showEditSheet langsung tercermin di sini
    // tanpa state lokal duplikat. Fallback ke widget.budget kalau item ini
    // sudah tidak ada di state (mis. dihapus dari layar lain).
    final budgetState = ref.watch(budgetProvider);
    final currentBudget = budgetState.budgets.firstWhere(
      (b) => b.id == widget.budget.id,
      orElse: () => widget.budget,
    );

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final progress = currentBudget.amount == 0
        ? 0.0
        : _totalSpent / currentBudget.amount;
    final isOver = progress > 1.0;
    final color = isOver
        ? Colors.redAccent
        : (progress > 0.8 ? Colors.orange : Colors.tealAccent);
    final sisa = currentBudget.amount - _totalSpent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          currentBudget.category?.name ?? "Detail Anggaran",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.pencilSimple,
              color: Colors.purple,
            ),
            onPressed: () => _showEditSheet(currentBudget),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // [UX UPGRADE] KARTU HEADER PREMIUM
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E35B1), Color(0xFF3949AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5E35B1).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Terpakai",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                currency.format(_totalSpent),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Limit Anggaran",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                currency.format(currentBudget.amount),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress > 1 ? 1 : progress,
                          color: color,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sisa >= 0 ? "Sisa Anggaran:" : "Over Budget:",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currency.format(sisa.abs()),
                              style: GoogleFonts.poppins(
                                color: sisa >= 0
                                    ? Colors.tealAccent
                                    : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 10, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Riwayat Pengeluaran",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIconsRegular.receipt,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Belum ada transaksi di kategori ini",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final trx = _transactions[index];
                            final rawNote = trx['note']?.toString() ?? '';
                            final cleanNote = rawNote.isNotEmpty
                                ? rawNote
                                : "Tanpa catatan";

                            // [NEW] Persiapan Wallet Badge
                            final wId = trx['wallet_id'];
                            final wName = _walletNames[wId] ?? 'Kas Utama';
                            final wColor = _walletColors[wId] ?? Colors.grey;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      PhosphorIconsFill.receipt,
                                      color: Colors.purple,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cleanNote,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              DateFormat('dd MMM yyyy').format(
                                                DateTime.parse(trx['date']),
                                              ),
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Badge Dompet
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: wColor.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                wName,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: wColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    currency.format(
                                      (trx['amount'] as num).toDouble(),
                                    ),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
