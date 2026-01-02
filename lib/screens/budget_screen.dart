import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/screens/budget_detail_screen.dart';
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
  DateTime _selectedMonth = DateTime.now();

  List<BudgetModel> _budgets = [];
  Map<int, double> _spendingMap = {};
  List<CategoryModel> _allCategories = [];

  double _totalBudget = 0;
  double _totalSpent = 0;

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

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _fetchBudgets();
  }

  // --- POPUP FILTER PERIODE (Fixed Background White) ---
  void _showMonthYearPicker() {
    int tempMonth = _selectedMonth.month;
    int tempYear = _selectedMonth.year;
    final currentYear = DateTime.now().year;
    final years = List.generate(11, (i) => (currentYear - 5) + i);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pilih Periode",
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
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Dropdown Bulan
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: tempMonth,
                            isExpanded: true,
                            dropdownColor: Colors.white, // <--- FIX WARNA PUTIH
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: List.generate(
                              12,
                              (index) => DropdownMenuItem(
                                value: index + 1,
                                child: Text(
                                  DateFormat(
                                    'MMMM',
                                    'id_ID',
                                  ).format(DateTime(2024, index + 1)),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            onChanged: (val) =>
                                setDialogState(() => tempMonth = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Dropdown Tahun
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: tempYear,
                            dropdownColor: Colors.white, // <--- FIX WARNA PUTIH
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: years
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(
                                      "$y",
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => tempYear = val!),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(
                        () => _selectedMonth = DateTime(tempYear, tempMonth),
                      );
                      Navigator.pop(context);
                      _fetchBudgets();
                    },
                    child: const Text("Tampilkan"),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- LOGIC LAINNYA TETAP SAMA ---
  Future<void> _copyFromLastMonth() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final prevDate = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      final prevBudgetsRes = await _supabase
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .eq('month', prevDate.month)
          .eq('year', prevDate.year);
      final prevBudgets = prevBudgetsRes as List;

      if (prevBudgets.isEmpty) {
        if (mounted)
          AppNotification.error(context, "Tidak ada data anggaran bulan lalu.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      List<Map<String, dynamic>> newBudgets = [];
      for (var item in prevBudgets) {
        newBudgets.add({
          'user_id': userId,
          'category_id': item['category_id'],
          'amount': item['amount'],
          'month': _selectedMonth.month,
          'year': _selectedMonth.year,
        });
      }
      await _supabase
          .from('budgets')
          .upsert(newBudgets, onConflict: 'user_id, category_id, month, year');
      await _fetchBudgets();
      if (mounted)
        AppNotification.success(context, "Berhasil menyalin anggaran!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menyalin: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final catRes = await _supabase
          .from('categories')
          .select()
          .eq('is_expense', true)
          .or('user_id.eq.$userId,user_id.is.null');
      if (mounted)
        setState(
          () => _allCategories = (catRes as List)
              .map((e) => CategoryModel.fromJson(e))
              .toList(),
        );
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> _fetchBudgets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final startMonth = DateFormat('yyyy-MM-01').format(_selectedMonth);
      final nextMonth = DateFormat(
        'yyyy-MM-01',
      ).format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));

      final budgetRes = await _supabase
          .from('budgets')
          .select('id, amount, category_id, month, year')
          .eq('user_id', userId)
          .eq('month', _selectedMonth.month)
          .eq('year', _selectedMonth.year);

      double tempTotalBudget = 0;
      final List<BudgetModel> budgets = [];

      for (var item in (budgetRes as List)) {
        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();
        tempTotalBudget += amount;
        final category = _allCategories.firstWhere(
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
            amount: amount,
            month: item['month'],
            year: item['year'],
            category: category,
          ),
        );
      }

      final trxRes = await _supabase
          .from('transactions')
          .select('amount, category_id')
          .eq('user_id', userId)
          .gte('date', startMonth)
          .lt('date', nextMonth);
      Map<int, double> spending = {};
      double tempTotalSpent = 0;

      for (var item in trxRes) {
        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();
        if (_allCategories.any((c) => c.id == catId && c.isExpense)) {
          spending[catId] = (spending[catId] ?? 0) + amount;
          if (budgets.any((b) => b.categoryId == catId))
            tempTotalSpent += amount;
        }
      }

      if (mounted) {
        setState(() {
          _budgets = budgets;
          _spendingMap = spending;
          _totalBudget = tempTotalBudget;
          _totalSpent = tempTotalSpent;
        });
      }
    } catch (e) {
      debugPrint("Error Budgets: $e");
    }
  }

  Future<void> _deleteBudget(int id) async {
    await _supabase.from('budgets').delete().eq('id', id);
    _fetchBudgets();
  }

  // DIALOG TAMBAH (Fixed Background White & Rp Always Visible)
  void _showFormDialog() {
    int? selectedCatId;
    int selectedMonth = _selectedMonth.month;
    int selectedYear = _selectedMonth.year;

    final amountController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    List<CategoryModel> dropdownOptions = _allCategories;
    final years = List.generate(11, (i) => (DateTime.now().year - 5) + i);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Buat Anggaran",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              value: selectedMonth,
                              isExpanded: true,
                              dropdownColor:
                                  Colors.white, // <--- FIX WARNA PUTIH
                              items: List.generate(
                                12,
                                (index) => DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(
                                    DateFormat(
                                      'MMMM',
                                      'id_ID',
                                    ).format(DateTime(2024, index + 1)),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              onChanged: (val) =>
                                  setDialogState(() => selectedMonth = val!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: selectedYear,
                              dropdownColor:
                                  Colors.white, // <--- FIX WARNA PUTIH
                              items: years
                                  .map(
                                    (y) => DropdownMenuItem(
                                      value: y,
                                      child: Text("$y"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedYear = val!),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<int>(
                        hint: const Text("Pilih Kategori"),
                        value: selectedCatId,
                        dropdownColor: Colors.white, // <--- FIX WARNA PUTIH
                        items: dropdownOptions
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedCatId = val),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // UPDATE DI SINI: Pakai prefixIcon agar "Rp" selalu tampil
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                        onChanged: (s) {
                          s = s.replaceAll(RegExp(r'[^0-9]'), '');
                          if (s.isNotEmpty)
                            amountController.value = TextEditingValue(
                              text: currencyFormat.format(int.parse(s)),
                              selection: TextSelection.collapsed(
                                offset: currencyFormat
                                    .format(int.parse(s))
                                    .length,
                              ),
                            );
                        },
                      ),
                    ],
                  ),
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
                      if (selectedCatId == null ||
                          amountController.text.isEmpty)
                        return;
                      try {
                        final userId = _supabase.auth.currentUser!.id;
                        final check = await _supabase
                            .from('budgets')
                            .select('id')
                            .eq('user_id', userId)
                            .eq('category_id', selectedCatId!)
                            .eq('month', selectedMonth)
                            .eq('year', selectedYear)
                            .maybeSingle();
                        if (check != null)
                          throw "Anggaran kategori ini sudah ada!";

                        await _supabase.from('budgets').insert({
                          'user_id': userId,
                          'category_id': selectedCatId!,
                          'amount': double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          ),
                          'month': selectedMonth,
                          'year': selectedYear,
                        });
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted &&
                            selectedMonth == _selectedMonth.month &&
                            selectedYear == _selectedMonth.year)
                          _fetchBudgets();
                        if (context.mounted)
                          AppNotification.success(context, "Berhasil!");
                      } catch (e) {
                        if (context.mounted)
                          AppNotification.error(context, e.toString());
                      }
                    },
                    child: const Text(
                      "Simpan",
                      style: TextStyle(
                        fontSize: 16,
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
    // ... UI UTAMA TIDAK BERUBAH ...
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
    double totalProgress = _totalBudget == 0 ? 0 : _totalSpent / _totalBudget;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Anggaran"),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                    ),
                    GestureDetector(
                      onTap: _showMonthYearPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              monthLabel,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.arrow_drop_down, size: 20),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Terpakai",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currency.format(_totalSpent),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _totalSpent > _totalBudget
                                ? Colors.red
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey.shade300,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Limit",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currency.format(_totalBudget),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: totalProgress > 1 ? 1 : totalProgress,
                  color: _totalSpent > _totalBudget
                      ? Colors.red
                      : AppColors.primary,
                  backgroundColor: Colors.grey.shade100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _budgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsFill.chartDonut,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Belum ada anggaran",
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _copyFromLastMonth,
                          icon: const Icon(Icons.copy),
                          label: const Text("Salin Bulan Lalu"),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _showFormDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text("Buat Baru"),
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
                      final color = progress > 1
                          ? Colors.red
                          : (progress > 0.8
                                ? Colors.orange
                                : AppColors.primary);

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BudgetDetailScreen(budget: budget),
                            ),
                          );
                          _fetchBudgets();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          PhosphorIconsFill.tag,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        budget.category?.name ?? "-",
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
                                          title: const Text("Hapus?"),
                                          content: const Text(
                                            "Yakin hapus anggaran ini?",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text("Batal"),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _deleteBudget(budget.id);
                                              },
                                              child: const Text(
                                                "Hapus",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    currency.format(spent),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    " / ${currency.format(budget.amount)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                value: progress > 1 ? 1 : progress,
                                color: color,
                                backgroundColor: Colors.grey.shade100,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(5),
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
      floatingActionButton: _budgets.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showFormDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
