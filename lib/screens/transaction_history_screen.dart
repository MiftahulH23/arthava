import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/screens/input_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final bool isExpense; // True = Pengeluaran, False = Pemasukan

  const TransactionHistoryScreen({super.key, required this.isExpense});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<TransactionModel> _transactions = [];

  // DATA KATEGORI
  List<CategoryModel> _categoryList = [];

  // FILTER STATE
  int? _selectedCategoryId; // Null = Semua Kategori
  String _filterType = 'Bulanan';
  DateTime _selectedDate = DateTime.now();

  // TOTAL SUMMARY
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchTransactions();
  }

  // 1. AMBIL DAFTAR KATEGORI
  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', widget.isExpense)
          .or('user_id.is.null,user_id.eq.$userId')
          .order('name', ascending: true);

      final data = response as List<dynamic>;
      if (mounted) {
        setState(() {
          _categoryList = data
              .map((json) => CategoryModel.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error categories: $e");
    }
  }

  // 2. AMBIL TRANSAKSI
  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      var query = _supabase
          .from('transactions')
          .select('*, categories!inner(*)')
          .eq('user_id', userId)
          .eq('categories.is_expense', widget.isExpense);

      // Filter Kategori (Jika bukan NULL)
      if (_selectedCategoryId != null) {
        query = query.eq('category_id', _selectedCategoryId!);
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Logika Filter Waktu
      if (_filterType == 'Harian') {
        query = query.eq('date', dateStr);
      } else if (_filterType == 'Bulanan') {
        final startMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final nextMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          1,
        );
        query = query
            .gte('date', DateFormat('yyyy-MM-dd').format(startMonth))
            .lt('date', DateFormat('yyyy-MM-dd').format(nextMonth));
      } else if (_filterType == 'Tahunan') {
        final startYear = DateTime(_selectedDate.year, 1, 1);
        final nextYear = DateTime(_selectedDate.year + 1, 1, 1);
        query = query
            .gte('date', DateFormat('yyyy-MM-dd').format(startYear))
            .lt('date', DateFormat('yyyy-MM-dd').format(nextYear));
      }

      final response = await query.order('date', ascending: false);
      final List<dynamic> data = response;

      double tempTotal = 0;
      List<TransactionModel> loadedTrx = [];

      for (var item in data) {
        final trx = TransactionModel.fromJson(item);
        loadedTrx.add(trx);

        final note = trx.note ?? '';
        final catName = trx.category?.name.toLowerCase() ?? '';
        final hasSavingMarker = note.contains('[SAVING_ID:');
        final isSystemCat =
            catName.contains('tabung') || catName.contains('cair');

        // Hanya hitung ke Total Real jika BUKAN mutasi murni
        if (!(hasSavingMarker && isSystemCat)) {
          tempTotal += trx.amount;
        }
      }

      if (mounted) {
        setState(() {
          _transactions = loadedTrx;
          _totalAmount = tempTotal;
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
      if (mounted) AppNotification.success(context, "Transaksi dihapus!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal hapus: $e");
    }
  }

  Future<void> _pickSmartDate() async {
    if (_filterType == 'Harian') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('id', 'ID'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
        _fetchTransactions();
      }
    } else if (_filterType == 'Tahunan') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text("Pilih Tahun"),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              selectedDate: _selectedDate,
              onChanged: (dt) {
                setState(() => _selectedDate = dt);
                Navigator.pop(ctx);
                _fetchTransactions();
              },
            ),
          ),
        ),
      );
    } else {
      final months = [
        "Januari",
        "Februari",
        "Maret",
        "April",
        "Mei",
        "Juni",
        "Juli",
        "Agustus",
        "September",
        "Oktober",
        "November",
        "Desember",
      ];
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text("Pilih Bulan (${_selectedDate.year})"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: months.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (ctx, index) {
                return InkWell(
                  onTap: () {
                    setState(
                      () => _selectedDate = DateTime(
                        _selectedDate.year,
                        index + 1,
                        1,
                      ),
                    );
                    Navigator.pop(ctx);
                    _fetchTransactions();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedDate.month == (index + 1)
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      months[index],
                      style: TextStyle(
                        color: _selectedDate.month == (index + 1)
                            ? Colors.white
                            : Colors.black,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    title: const Text("Ganti Tahun"),
                    content: SizedBox(
                      width: 300,
                      height: 300,
                      child: YearPicker(
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        selectedDate: _selectedDate,
                        onChanged: (dt) {
                          setState(
                            () => _selectedDate = DateTime(
                              dt.year,
                              _selectedDate.month,
                              1,
                            ),
                          );
                          Navigator.pop(context);
                          _fetchTransactions();
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Text("Ganti Tahun (${_selectedDate.year})"),
            ),
          ],
        ),
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
    final String pageTitle = widget.isExpense ? "Pengeluaran" : "Pemasukan";
    final Color themeColor = widget.isExpense
        ? AppColors.expense
        : AppColors.income;

    String dateLabel = "";
    if (_filterType == 'Harian')
      dateLabel = DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate);
    else if (_filterType == 'Bulanan')
      dateLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    else
      dateLabel = DateFormat('yyyy', 'id_ID').format(_selectedDate);

    // LOGIC NAMA KATEGORI
    String selectedCategoryName = "Semua Kategori";
    if (_selectedCategoryId != null && _categoryList.isNotEmpty) {
      try {
        selectedCategoryName = _categoryList
            .firstWhere((e) => e.id == _selectedCategoryId)
            .name;
      } catch (e) {
        selectedCategoryName = "Kategori Terhapus";
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER FILTER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Riwayat $pageTitle",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BARIS 1: Waktu & Tanggal
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildDropdownFilter(
                          icon: PhosphorIconsFill.faders,
                          label: _filterType,
                          items: ["Harian", "Bulanan", "Tahunan"],
                          onSelected: (val) {
                            setState(() {
                              _filterType = val;
                              _fetchTransactions();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: _pickSmartDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.calendarBlank,
                                  size: 18,
                                  color: themeColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // BARIS 2: Kategori
                  _buildCategoryFilter(selectedCategoryName),
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
                        "Belum ada data $pageTitle",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // CARD TOTAL (Tidak termasuk tabungan)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: themeColor.withOpacity(0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      widget.isExpense
                                          ? PhosphorIconsFill.trendDown
                                          : PhosphorIconsFill.trendUp,
                                      color: themeColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Total Real", // Ditambahkan kata "Real" agar user ngerti ini tidak termasuk tabungan
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  currencyFormat.format(_totalAmount),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: themeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final trx = _transactions[index];
                              String noteText = "Tidak ada catatan";
                              final bool isSavingTrx =
                                  trx.note != null &&
                                  trx.note!.contains('[SAVING_ID:');

                              if (trx.note != null && trx.note!.isNotEmpty) {
                                noteText = trx.note!.replaceAll(
                                  RegExp(r'\s*\[SAVING_ID:\d+\]'),
                                  '',
                                );
                              }

                              // [UPDATE TAMPILAN] Bedakan visual kalau dia transaksi tabungan
                              final Color noteColor = isSavingTrx
                                  ? const Color(
                                      0xFF009688,
                                    ) // Warna teal khusus kalau dia dari tabungan
                                  : (trx.note != null && trx.note!.isNotEmpty)
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400;

                              return Dismissible(
                                key: Key(trx.id.toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (d) async {
                                  if (isSavingTrx) {
                                    // Tampilkan Alert Blockir
                                    await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        surfaceTintColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            const Icon(
                                              PhosphorIconsFill.warningCircle,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Tidak Bisa Dihapus",
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          "Ini adalah catatan otomatis (Mutasi Tabungan). Untuk menghapusnya, silakan hapus data aslinya melalui menu Tabungan di Beranda.",
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: Text(
                                              "Mengerti",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    return false; // Mengagalkan aksi swipe
                                  }

                                  // Tampilkan Alert Konfirmasi Normal
                                  return await showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      surfaceTintColor: Colors.transparent,
                                      title: const Text("Hapus?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Batal"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            "Hapus",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (d) => _deleteTransaction(trx.id),
                                child: GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            InputTransactionScreen(
                                              transactionToEdit: trx,
                                            ),
                                      ),
                                    );
                                    if (result == true) _fetchTransactions();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      // [UPDATE TAMPILAN] Kasih border khusus kalau dari tabungan
                                      border: isSavingTrx
                                          ? Border.all(
                                              color: const Color(
                                                0xFF009688,
                                              ).withOpacity(0.3),
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            // [UPDATE TAMPILAN] Warna icon beda kalau dari tabungan
                                            color: isSavingTrx
                                                ? const Color(
                                                    0xFF009688,
                                                  ).withOpacity(0.1)
                                                : themeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            isSavingTrx
                                                ? PhosphorIconsFill.bank
                                                : (widget.isExpense
                                                      ? PhosphorIcons.arrowUp()
                                                      : PhosphorIcons.arrowDown()),
                                            color: isSavingTrx
                                                ? const Color(0xFF009688)
                                                : themeColor,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    trx.category?.name ??
                                                        "Umum",
                                                    style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  // [UPDATE TAMPILAN] Badge "MUTASI"
                                                  if (isSavingTrx) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF009688,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        "Mutasi",
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  const Color(
                                                                    0xFF009688,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                noteText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: noteColor,
                                                  fontSize: 12,
                                                  fontStyle:
                                                      (trx.note == null ||
                                                          trx.note!.isEmpty)
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              currencyFormat.format(trx.amount),
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                // [UPDATE TAMPILAN] Warna abu-abu kalau mutasi tabungan
                                                color: isSavingTrx
                                                    ? Colors.grey.shade600
                                                    : themeColor,
                                                fontSize: 14,
                                                decoration: isSavingTrx
                                                    ? TextDecoration.lineThrough
                                                    : null, // Coret angka biar tau ga masuk hitungan total
                                                decorationColor:
                                                    Colors.grey.shade400,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat(
                                                'd MMM yyyy',
                                                'id_ID',
                                              ).format(trx.date),
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required IconData icon,
    required String label,
    required List<String> items,
    required Function(String) onSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: PopupMenuButton<String>(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        onSelected: onSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        itemBuilder: (context) => items
            .map(
              (item) => PopupMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontWeight: item == label
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(String label) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: PopupMenuButton<int>(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        onSelected: (val) {
          setState(() {
            if (val == -1) {
              _selectedCategoryId = null;
            } else {
              _selectedCategoryId = val;
            }
            _fetchTransactions();
          });
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        itemBuilder: (context) {
          List<PopupMenuEntry<int>> items = [
            PopupMenuItem(
              value: -1,
              child: Text(
                "Semua Kategori",
                style: GoogleFonts.poppins(
                  fontWeight: _selectedCategoryId == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            const PopupMenuDivider(),
          ];
          items.addAll(
            _categoryList.map(
              (cat) => PopupMenuItem(
                value: cat.id,
                child: Text(
                  cat.name,
                  style: GoogleFonts.poppins(
                    fontWeight: _selectedCategoryId == cat.id
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
          return items;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(
                PhosphorIconsFill.tag,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
