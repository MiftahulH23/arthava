import 'package:catat_uang_app/core/app_notification.dart'; // [NEW] Tambah import notifikasi
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:catat_uang_app/widgets/app_tab_selector.dart';
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
  List<int> _selectedCategoryIds = [];
  List<int> _selectedWalletIds = [];

  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  Map<int, String> _walletNames = {};
  Map<int, Color> _walletColors = {};

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    _fetchCategories();
    _fetchWallets();
    _fetchTransactions();
  }

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
      } else if (_filterType == 'Periode' && _selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
        );
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

      if (_selectedCategoryIds.isNotEmpty) {
        query = query.inFilter('category_id', _selectedCategoryIds);
      }

      if (_selectedWalletIds.isNotEmpty) {
        query = query.inFilter('wallet_id', _selectedWalletIds);
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

 // ==============================================================
  // [BUG FIX] FUNGSI DELETE SEKARANG NGEMBALIIN SALDO DOMPET
  // ==============================================================
  Future<void> _deleteTransaction(TransactionModel trx) async {
    try {
      // [FIX] Tampung di variabel lokal biar Dart nggak rewel soal Null Safety
      final walletId = trx.walletId; 

      // 1. Cek apakah transaksi ini pakai dompet
      if (walletId != null) {
        // Ambil saldo dompet saat ini
        final walletRes = await _supabase.from('wallets').select('balance').eq('id', walletId).single();
        double currentBal = (walletRes['balance'] as num).toDouble();
        
        // Logika Revert (Kembalikan Saldo)
        // Kalau Pengeluaran (Expense): Saldo dompet harus ditambahin karena transaksinya batal
        // Kalau Pemasukan (!Expense): Saldo dompet harus dikurangin karena transaksinya batal
        double newBalance = widget.isExpense 
            ? currentBal + trx.amount 
            : currentBal - trx.amount;
            
        // Update saldo dompet di database
        await _supabase.from('wallets').update({'balance': newBalance}).eq('id', walletId);
      }

      // 2. Hapus transaksinya dari database
      await _supabase.from('transactions').delete().eq('id', trx.id);
      
      // 3. Refresh Data
      _fetchWallets();
      _fetchTransactions();
      
      if (mounted) {
        AppNotification.success(context, "Data dihapus & saldo dompet disesuaikan!");
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      if (mounted) {
        AppNotification.error(context, "Gagal menghapus transaksi.");
      }
    }
  }

  void _pickDate() async {
    if (_filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
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
            surfaceTintColor: Colors.transparent,
            title: Text(
              "Pilih Tahun",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
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
    } else if (_filterType == 'Periode') {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: _selectedDateRange,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        setState(() => _selectedDateRange = picked);
        _fetchTransactions();
      }
    } else {
      final currentYear = DateTime.now().year;
      final years = List.generate(11, (i) => (currentYear - 5) + i);
      int tempYear = _selectedDate.year;

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pilih Bulan",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempYear,
                          dropdownColor: Colors.white,
                          isDense: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.primary,
                          ),
                          items: years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    "$year",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => tempYear = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 300,
                  height: 300,
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final int monthIndex = index + 1;
                            final bool isSelected =
                                _selectedDate.month == monthIndex &&
                                _selectedDate.year == tempYear;
                            return InkWell(
                              onTap: () {
                                setState(
                                  () => _selectedDate = DateTime(
                                    tempYear,
                                    monthIndex,
                                  ),
                                );
                                Navigator.pop(context);
                                _fetchTransactions();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  DateFormat(
                                    'MMM',
                                    'id_ID',
                                  ).format(DateTime(2024, monthIndex)),
                                  style: GoogleFonts.poppins(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                        "Filter Transaksi",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            _selectedCategoryIds.clear();
                            _selectedWalletIds.clear();
                          });
                          setState(() {});
                        },
                        child: Text(
                          "Reset",
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Kategori",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((c) {
                              final id = c['id'] as int;
                              final isSelected = _selectedCategoryIds.contains(id);
                              final color = widget.isExpense ? AppColors.expense : AppColors.income;
                              return FilterChip(
                                label: Text(c['name']),
                                selected: isSelected,
                                onSelected: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      _selectedCategoryIds.add(id);
                                    } else {
                                      _selectedCategoryIds.remove(id);
                                    }
                                  });
                                  setState(() {});
                                },
                                selectedColor: color.withOpacity(0.2),
                                checkmarkColor: color,
                                labelStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isSelected ? color : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                backgroundColor: Colors.grey.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected ? color : Colors.grey.shade200,
                                  ),
                                ),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Dompet",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _walletNames.entries.map((e) {
                              final id = e.key;
                              final isSelected = _selectedWalletIds.contains(id);
                              final color = widget.isExpense ? AppColors.expense : AppColors.income;
                              return FilterChip(
                                label: Text(e.value),
                                selected: isSelected,
                                onSelected: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      _selectedWalletIds.add(id);
                                    } else {
                                      _selectedWalletIds.remove(id);
                                    }
                                  });
                                  setState(() {});
                                },
                                selectedColor: color.withOpacity(0.2),
                                checkmarkColor: color,
                                labelStyle: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isSelected ? color : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                backgroundColor: Colors.grey.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected ? color : Colors.grey.shade200,
                                  ),
                                ),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isExpense ? AppColors.expense : AppColors.income,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _fetchTransactions();
                      },
                      child: Text(
                        "Terapkan Filter",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final color = widget.isExpense ? AppColors.expense : AppColors.income;

    String dateLabel = '';
    if (_filterType == 'Harian') {
      dateLabel = DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Tahunan') {
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);
    } else if (_filterType == 'Periode') {
      dateLabel = _selectedDateRange != null
          ? "${DateFormat('dd MMM', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.end)}"
          : "Pilih Periode";
    } else {
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    }

    return SafeArea(
      child: Column(
        children: [
          // HEADER & FILTER SECTION
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
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
                const SizedBox(height: 15),

                // TABS FILTER TIPE
                AppTabSelector(
                  labels: const ['Harian', 'Bulanan', 'Tahunan', 'Periode'],
                  initialIndex: ['Harian', 'Bulanan', 'Tahunan', 'Periode']
                      .indexOf(_filterType),
                  activeColor: color,
                  onChanged: (index) {
                    final type = ['Harian', 'Bulanan', 'Tahunan', 'Periode'][index];
                    if (_filterType != type) {
                      setState(() => _filterType = type);
                      _fetchTransactions();
                    }
                  },
                ),
                const SizedBox(height: 15),

                // ROW TANGGAL & KATEGORI
                Row(
                  children: [
                    // Tombol Tanggal
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIconsRegular.calendarBlank,
                                size: 16,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dateLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tombol Filter
                    Expanded(
                      child: GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          height: 45,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIconsRegular.funnel,
                                size: 16,
                                color: (_selectedCategoryIds.isNotEmpty || _selectedWalletIds.isNotEmpty) ? color : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Filter",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (_selectedCategoryIds.isNotEmpty || _selectedWalletIds.isNotEmpty) ? color : Colors.black87,
                                ),
                              ),
                              if (_selectedCategoryIds.isNotEmpty || _selectedWalletIds.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_selectedCategoryIds.length + _selectedWalletIds.length}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // BOX TOTAL
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.1),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isExpense
                              ? PhosphorIconsBold.trendDown
                              : PhosphorIconsBold.trendUp,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Real",
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              currencyFormat.format(_totalAmount),
                              style: GoogleFonts.poppins(
                                color: color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // LIST TRANSAKSI
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

                      final walletId = trx.walletId;
                      final walletName = _walletNames[walletId];
                      final walletColor =
                          _walletColors[walletId] ?? Colors.grey;

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
                          if (result == true) {
                            _fetchWallets();
                            _fetchTransactions();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isPureMutation
                                ? Colors.grey.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isPureMutation
                                ? Border.all(
                                    color: Colors.teal.shade200,
                                    width: 1.2,
                                  )
                                : Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              if (!isPureMutation)
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
                                  color: isPureMutation
                                      ? Colors.teal.withOpacity(0.1)
                                      : color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isPureMutation
                                      ? PhosphorIconsFill.bank
                                      : (widget.isExpense
                                            ? PhosphorIcons.arrowUp()
                                            : PhosphorIcons.arrowDown()),
                                  color: isPureMutation ? Colors.teal : color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            trx.category?.name ?? "Umum",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isPureMutation
                                                  ? Colors.grey.shade600
                                                  : Colors.black,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (walletName != null &&
                                            !isPureMutation)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: walletColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: walletColor.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  PhosphorIconsFill.wallet,
                                                  size: 10,
                                                  color: walletColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  walletName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: walletColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (trx.note != null &&
                                        trx.note!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
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
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    if (isPureMutation)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
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
                                      fontSize: 14,
                                      color: isPureMutation
                                          ? Colors.grey
                                          : color,
                                      decoration: isPureMutation
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
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

                      if (isPureMutation) return transactionCard;

                      return Dismissible(
                        key: ValueKey(trx.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                        // [BUG FIX] SEKARANG NGE-PASS SELURUH OBJEK TRANSAKSI, BUKAN CUMA ID
                        onDismissed: (direction) => _deleteTransaction(trx),
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
