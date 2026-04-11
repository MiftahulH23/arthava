import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/budget_model.dart';
import 'package:catat_uang_app/models/category_model.dart';
import 'package:catat_uang_app/screens/budget_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
    _fetchBudgets();
  }

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
                      setState(() => _selectedMonth = DateTime(tempYear, tempMonth));
                      Navigator.pop(context);
                      _fetchBudgets();
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

  Future<void> _copyFromLastMonth() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final prevDate = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      final prevBudgetsRes = await _supabase.from('budgets').select().eq('user_id', userId).eq('month', prevDate.month).eq('year', prevDate.year);
      final prevBudgets = prevBudgetsRes as List;

      if (prevBudgets.isEmpty) {
        if (mounted) AppNotification.error(context, "Tidak ada data anggaran bulan lalu.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      List<Map<String, dynamic>> newBudgets = [];
      for (var item in prevBudgets) {
        newBudgets.add({
          'user_id': userId, 'category_id': item['category_id'], 'amount': item['amount'],
          'month': _selectedMonth.month, 'year': _selectedMonth.year,
        });
      }
      await _supabase.from('budgets').upsert(newBudgets, onConflict: 'user_id, category_id, month, year');
      await _fetchBudgets();
      if (mounted) AppNotification.success(context, "Berhasil menyalin anggaran!");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menyalin: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final catRes = await _supabase.from('categories').select().eq('is_expense', true).or('user_id.eq.$userId,user_id.is.null');
      if (mounted) setState(() => _allCategories = (catRes as List).map((e) => CategoryModel.fromJson(e)).toList());
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> _fetchBudgets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final startMonth = DateFormat('yyyy-MM-01').format(_selectedMonth);
      final nextMonth = DateFormat('yyyy-MM-01').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));

      final budgetRes = await _supabase.from('budgets').select('id, amount, category_id, month, year').eq('user_id', userId).eq('month', _selectedMonth.month).eq('year', _selectedMonth.year);

      double tempTotalBudget = 0;
      final List<BudgetModel> budgets = [];

      for (var item in (budgetRes as List)) {
        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();
        tempTotalBudget += amount;
        final category = _allCategories.firstWhere(
          (c) => c.id == catId,
          orElse: () => CategoryModel(id: catId, name: "Dihapus", isExpense: true, iconName: "warning", userId: userId),
        );
        budgets.add(BudgetModel(id: item['id'], categoryId: catId, amount: amount, month: item['month'], year: item['year'], category: category));
      }

      // [UPDATE LOGIKA] Tambahin 'note' biar kita bisa filter mutasi tabungan
      final trxRes = await _supabase.from('transactions').select('amount, category_id, note').eq('user_id', userId).gte('date', startMonth).lt('date', nextMonth);
      Map<int, double> spending = {};
      double tempTotalSpent = 0;

      for (var item in trxRes) {
        final noteStr = item['note']?.toString() ?? '';
        // [FIX] Celah gaib ditutup. Tabungan nggak akan ngurangin budget lu!
        if (noteStr.contains('[SAVING_ID:')) continue; 

        final catId = item['category_id'] as int;
        final amount = (item['amount'] as num).toDouble();
        if (_allCategories.any((c) => c.id == catId && c.isExpense)) {
          spending[catId] = (spending[catId] ?? 0) + amount;
          if (budgets.any((b) => b.categoryId == catId)) tempTotalSpent += amount;
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

  // [UX UPGRADE] DIALOG TAMBAH BERUBAH JADI BOTTOM SHEET
  void _showFormSheet() {
    int? selectedCatId;
    int selectedMonth = _selectedMonth.month;
    int selectedYear = _selectedMonth.year;

    final amountController = TextEditingController();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    List<CategoryModel> dropdownOptions = _allCategories;
    final years = List.generate(11, (i) => (DateTime.now().year - 5) + i);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
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
                                value: selectedMonth, isExpanded: true, dropdownColor: Colors.white,
                                items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2024, index + 1)), style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))),
                                onChanged: (val) => setSheetState(() => selectedMonth = val!),
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
                                value: selectedYear, isExpanded: true, dropdownColor: Colors.white,
                                items: years.map((y) => DropdownMenuItem(value: y, child: Text("$y", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)))).toList(),
                                onChanged: (val) => setSheetState(() => selectedYear = val!),
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
                            final userId = _supabase.auth.currentUser!.id;
                            final check = await _supabase.from('budgets').select('id').eq('user_id', userId).eq('category_id', selectedCatId!).eq('month', selectedMonth).eq('year', selectedYear).maybeSingle();
                            if (check != null) throw "Anggaran kategori ini sudah ada!";

                            await _supabase.from('budgets').insert({
                              'user_id': userId, 'category_id': selectedCatId!, 'month': selectedMonth, 'year': selectedYear,
                              'amount': double.parse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')),
                            });
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted && selectedMonth == _selectedMonth.month && selectedYear == _selectedMonth.year) _fetchBudgets();
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
    double totalProgress = _totalBudget == 0 ? 0 : _totalSpent / _totalBudget;

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
                    IconButton(icon: const Icon(PhosphorIconsBold.caretLeft, color: Colors.grey), onPressed: () => _changeMonth(-1)),
                    GestureDetector(
                      onTap: _showMonthYearPicker,
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
                    IconButton(icon: const Icon(PhosphorIconsBold.caretRight, color: Colors.grey), onPressed: () => _changeMonth(1)),
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
                              Text(currency.format(_totalSpent), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Total Anggaran", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                              Text(currency.format(_totalBudget), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: totalProgress > 1 ? 1 : totalProgress,
                          color: _totalSpent > _totalBudget ? Colors.redAccent : Colors.tealAccent,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _budgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsFill.chartDonut, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("Belum ada anggaran", style: GoogleFonts.poppins(color: Colors.grey)),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _copyFromLastMonth, icon: const Icon(PhosphorIconsBold.copy), label: Text("Salin Bulan Lalu", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.purple, side: const BorderSide(color: Colors.purple), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20), physics: const BouncingScrollPhysics(),
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final budget = _budgets[index];
                      final spent = _spendingMap[budget.categoryId] ?? 0;
                      final progress = budget.amount == 0 ? 0.0 : spent / budget.amount;
                      final color = progress > 1 ? Colors.red : (progress > 0.8 ? Colors.orange : Colors.purple);

                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetDetailScreen(budget: budget)));
                          _fetchBudgets();
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
                                            TextButton(onPressed: () { Navigator.pop(ctx); _deleteBudget(budget.id); }, child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
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
      floatingActionButton: _budgets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showFormSheet,
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text("Anggaran", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
    );
  }
}