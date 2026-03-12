import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final bool isExpense;
  const TransactionHistoryScreen({super.key, required this.isExpense});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];
  double _totalAmount = 0;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchTransactions();
  }

  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', widget.isExpense)
          .or('user_id.is.null,user_id.eq.$userId');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Error categories: $e");
    }
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      DateTime startDate;
      DateTime endDate;

      if (_filterType == 'Harian') {
        startDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
          59,
        );
      } else if (_filterType == 'Tahunan') {
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
      } else {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
          23,
          59,
          59,
        );
      }

      var query = _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .eq('categories.is_expense', widget.isExpense)
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(endDate));

      if (_selectedCategoryId != null) {
        query = query.eq('category_id', _selectedCategoryId!);
      }

      final response = await query
          .order('date', ascending: false)
          .order('id', ascending: false);

      double total = 0;
      List<TransactionModel> loaded = [];

      for (var item in response as List) {
        if (item['categories'] == null) continue;

        final trx = TransactionModel.fromJson(item);
        final note = trx.note?.toString() ?? '';
        final catName = trx.category?.name.toLowerCase() ?? '';
        final isPureMutation =
            note.contains('[SAVING_ID:') &&
            (catName.contains('tabung') || catName.contains('cair'));

        loaded.add(trx);

        if (!isPureMutation) {
          total += trx.amount;
        }
      }

      if (mounted) {
        setState(() {
          _transactions = loaded;
          _totalAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction(int id) async {
    try {
      await _supabase.from('transactions').delete().eq('id', id);
      _fetchTransactions();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void _pickDate() async {
    if (_filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _fetchTransactions();
      }
    } else if (_filterType == 'Tahunan') {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text("Pilih Tahun"),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectedDate: _selectedDate,
                onChanged: (DateTime val) {
                  setState(() => _selectedDate = val);
                  Navigator.pop(context);
                  _fetchTransactions();
                },
              ),
            ),
          );
        },
      );
    } else {
      DateTime tempDate = _selectedDate;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: 300,
            child: Column(
              children: [
                Text(
                  "Pilih Bulan",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: YearPicker(
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    selectedDate: tempDate,
                    onChanged: (DateTime dateTime) {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              return InkWell(
                                onTap: () {
                                  setState(
                                    () => _selectedDate = DateTime(
                                      dateTime.year,
                                      index + 1,
                                    ),
                                  );
                                  Navigator.pop(context);
                                  _fetchTransactions();
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'MMM',
                                    ).format(DateTime(2024, index + 1)),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final color = widget.isExpense ? AppColors.expense : AppColors.income;

    String dateLabel = '';
    if (_filterType == 'Harian') {
      dateLabel = DateFormat('dd MMM yy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Tahunan') {
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);
    } else {
      dateLabel = DateFormat('MMM yyyy', 'id_ID').format(_selectedDate);
    }

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isExpense
                      ? "Riwayat Pengeluaran"
                      : "Riwayat Pemasukan",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _filterType,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                  ),
                                  items: ['Harian', 'Bulanan', 'Tahunan'].map((
                                    e,
                                  ) {
                                    return DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        e,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _filterType = v;
                                        _selectedDate = DateTime.now();
                                      });
                                      _fetchTransactions();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.calendarBlank,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsFill.tag,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCategoryId,
                            isExpanded: true,
                            hint: Text(
                              "Semua Kategori",
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  "Semua Kategori",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ..._categories.map((e) {
                                return DropdownMenuItem<int?>(
                                  value: e['id'] as int,
                                  child: Text(
                                    e['name'],
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCategoryId = val);
                              _fetchTransactions();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isExpense
                            ? PhosphorIconsBold.trendDown
                            : PhosphorIconsBold.trendUp,
                        color: color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Total Real",
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        currencyFormat.format(_totalAmount),
                        style: GoogleFonts.poppins(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? Center(
                    child: Text(
                      "Tidak ada transaksi",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final trx = _transactions[index];
                      final noteStr = trx.note?.toString() ?? '';
                      final catStr = trx.category?.name.toLowerCase() ?? '';
                      final isSystemCat =
                          catStr.contains('tabung') || catStr.contains('cair');
                      final isPureMutation =
                          noteStr.contains('[SAVING_ID:') && isSystemCat;

                      // WIDGET CARD TRANSAKSI UTAMA
                      Widget transactionCard = GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InputTransactionScreen(
                                initialIsExpense: widget.isExpense,
                                transactionToEdit: trx,
                              ),
                            ),
                          );
                          if (result == true) _fetchTransactions();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPureMutation
                                ? Colors.grey.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isPureMutation
                                ? Border.all(
                                    color: Colors.teal.shade200,
                                    width: 1.5,
                                  )
                                : Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              if (!isPureMutation)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPureMutation
                                      ? Colors.teal.withOpacity(0.1)
                                      : color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isPureMutation
                                      ? PhosphorIconsFill.bank
                                      : (widget.isExpense
                                            ? PhosphorIcons.arrowDown()
                                            : PhosphorIcons.arrowUp()),
                                  color: isPureMutation ? Colors.teal : color,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trx.category?.name ?? "Umum",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isPureMutation
                                            ? Colors.grey.shade600
                                            : Colors.black,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (trx.note != null &&
                                        trx.note!.isNotEmpty)
                                      Text(
                                        trx.note!
                                            .replaceAll(
                                              RegExp(r'\[SAVING_ID:\d+\]'),
                                              '',
                                            )
                                            .trim(),
                                        style: GoogleFonts.poppins(
                                          color: isPureMutation
                                              ? Colors.teal
                                              : Colors.grey,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (isPureMutation)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          "Mutasi Internal",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.teal,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(trx.amount),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isPureMutation
                                          ? Colors.grey
                                          : color,
                                      decoration: isPureMutation
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                      'id_ID',
                                    ).format(trx.date),
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );

                      // JIKA MUTASI TABUNGAN -> Tampilkan biasa (Gak bisa di slide)
                      if (isPureMutation) {
                        return transactionCard;
                      }

                      // JIKA TRANSAKSI BIASA -> Bungkus dengan Dismissible (Bisa di slide hapus)
                      return Dismissible(
                        key: ValueKey(trx.id),
                        direction: DismissDirection
                            .endToStart, // Slide dari Kanan ke Kiri
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: Text(
                                "Hapus Transaksi?",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                "Data ini akan dihapus permanen.",
                                style: GoogleFonts.poppins(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    "Batal",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    "Hapus",
                                    style: GoogleFonts.poppins(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          _deleteTransaction(trx.id);
                        },
                        child: transactionCard,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
