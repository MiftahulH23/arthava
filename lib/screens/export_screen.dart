import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/services/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isCustomRange = false;
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _selectedDateRange;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  Future<void> _pickMonth() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(11, (i) => (currentYear - 5) + i);

    await showDialog(
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
                    "Pilih Periode",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
                        value: _selectedMonth.year,
                        dropdownColor: Colors.white,
                        isDense: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                        items: years.map((year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              "$year",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(
                              () => _selectedMonth = DateTime(
                                val,
                                _selectedMonth.month,
                              ),
                            );
                            setState(
                              () => _selectedMonth = DateTime(
                                val,
                                _selectedMonth.month,
                              ),
                            );
                          }
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
                              _selectedMonth.month == monthIndex;

                          return InkWell(
                            onTap: () {
                              setState(
                                () => _selectedMonth = DateTime(
                                  _selectedMonth.year,
                                  monthIndex,
                                ),
                              );
                              Navigator.pop(context);
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

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

 Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      DateTime startDate;
      DateTime endDate;
      String reportTitle;

      if (_isCustomRange && _selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        reportTitle = 'Laporan_${DateFormat('ddMMMyy').format(startDate)}_sd_${DateFormat('ddMMMyy').format(endDate)}';
      } else {
        startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
        reportTitle = 'Laporan_Keuangan_${DateFormat('MMMM_yyyy', 'id_ID').format(_selectedMonth)}';
      }

      final userResponse = await _supabase.from('profiles').select('name').eq('id', userId).maybeSingle();
      final userName = userResponse != null ? userResponse['name'] : "User";

      // Tarik data tabungan
      final savingsRes = await _supabase.from('savings').select('id, name, amount').eq('user_id', userId);
      Map<String, String> savingNames = {};
      double totalSavings = 0;
      for (var row in savingsRes as List) {
        savingNames[row['id'].toString()] = row['name'].toString();
        totalSavings += (row['amount'] as num).toDouble();
      }

      // [NEW] Tarik data Dompet buat dimasukin ke PDF
      final walletsRes = await _supabase.from('wallets').select('id, name, balance').eq('user_id', userId);
      Map<String, String> walletNames = {};
      double totalWalletBalance = 0;
      List<Map<String, dynamic>> walletsInfo = [];
      for (var w in walletsRes as List) {
        walletNames[w['id'].toString()] = w['name'].toString();
        double bal = (w['balance'] as num).toDouble();
        totalWalletBalance += bal;
        walletsInfo.add({
          'name': w['name'].toString(),
          'balance': bal,
        });
      }

      final response = await _supabase
          .from('transactions')
          .select('*, categories!inner(*)')
          .eq('user_id', userId)
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(endDate))
          .order('date', ascending: true);

      final List<TransactionModel> validTransactions = [];
      double income = 0;
      double expense = 0;
      
      Map<String, double> expensesByCategory = {};
      Map<String, double> incomeByCategory = {};
      TransactionModel? largestExpense;
      TransactionModel? largestIncome;

      for (var item in response as List) {
        Map<String, dynamic> itemData = Map<String, dynamic>.from(item);

        String noteStr = itemData['note']?.toString() ?? '';
        final catStr = itemData['categories']?['name']?.toString().toLowerCase() ?? '';
        final isSystemCat = catStr.contains('tabung') || catStr.contains('cair');
        final isPureMutation = noteStr.contains('[SAVING_ID:') && isSystemCat;

        if (!isPureMutation) {
          final match = RegExp(r'\[SAVING_ID:(\d+)\]').firstMatch(noteStr);
          if (match != null) {
            String savingId = match.group(1)!;
            String savingName = savingNames[savingId] ?? 'Tabungan'; 
            noteStr = noteStr.replaceAll(match.group(0)!, '(Sumber: $savingName)').trim();
          }

          // [NEW] Sisipin info Dompet ke dalam Catatan biar muncul di tabel PDF!
          String wId = itemData['wallet_id']?.toString() ?? '';
          if (wId.isNotEmpty && walletNames.containsKey(wId)) {
             String wName = walletNames[wId]!;
             noteStr = noteStr.isEmpty ? "[Dompet: $wName]" : "$noteStr\n[Dompet: $wName]";
          }
          itemData['note'] = noteStr;

          final trx = TransactionModel.fromJson(itemData);
          validTransactions.add(trx);
          
          final catName = trx.category?.name ?? 'Umum';
          
          if (trx.category?.isExpense == true) {
            expense += trx.amount;
            expensesByCategory[catName] = (expensesByCategory[catName] ?? 0) + trx.amount;
            if (largestExpense == null || trx.amount > largestExpense!.amount) {
              largestExpense = trx;
            }
          } else {
            income += trx.amount;
            incomeByCategory[catName] = (incomeByCategory[catName] ?? 0) + trx.amount;
            if (largestIncome == null || trx.amount > largestIncome!.amount) {
              largestIncome = trx;
            }
          }
        }
      }

      if (validTransactions.isEmpty) {
        if (mounted) AppNotification.error(context, "Tidak ada transaksi di periode ini.");
        setState(() => _isGenerating = false);
        return;
      }

      var sortedExpensesList = expensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      Map<String, double> sortedExpensesByCategory = Map.fromEntries(sortedExpensesList);
      
      var sortedIncomesList = incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      Map<String, double> sortedIncomeByCategory = Map.fromEntries(sortedIncomesList);

      final pdfBytes = await PdfService().generateReport(
        month: _isCustomRange ? startDate : _selectedMonth, 
        transactions: validTransactions,
        userName: userName,
        totalIncome: income,
        totalExpense: expense,
        totalSavings: totalSavings, 
        mainCashBalance: totalWalletBalance, 
        isCustomRange: _isCustomRange,
        endDate: endDate,
        walletsInfo: walletsInfo,
        expensesByCategory: sortedExpensesByCategory,
        incomeByCategory: sortedIncomeByCategory,
        largestExpense: largestExpense,
        largestIncome: largestIncome,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: reportTitle,
      );
      
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal membuat PDF: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // ... KODINGAN BUILD UI SAMA PERSIS KAYA SEBELUMNYA ...
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Export Laporan",
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
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
                  const Icon(
                    PhosphorIconsFill.filePdf,
                    size: 50,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Cetak Laporan Keuangan",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Pilih mode periode laporan di bawah ini",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isCustomRange = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isCustomRange
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Satu Bulan",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: !_isCustomRange
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isCustomRange = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isCustomRange
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Pilih Tanggal",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: _isCustomRange
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _isCustomRange
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: InkWell(
                      onTap: _pickMonth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  PhosphorIconsFill.calendarBlank,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bulan Laporan",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMMM yyyy',
                                        'id_ID',
                                      ).format(_selectedMonth),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    secondChild: InkWell(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsFill.calendarPlus,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Rentang Tanggal",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _selectedDateRange != null
                                              ? "${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.end)}"
                                              : "Pilih rentang",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generatePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  shadowColor: AppColors.textPrimary.withOpacity(0.5),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            PhosphorIconsFill.printer,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Cetak Laporan PDF",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
}
