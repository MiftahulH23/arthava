import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/services/pdf_service.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:catat_uang_app/core/transaction_tags.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;

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
    final picked = await showAppMonthPicker(
      context: context,
      title: 'Pilih Periode',
      initialMonth: _selectedMonth,
      firstYear: currentYear - 5,
      lastYear: currentYear + 5,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedMonth = picked);
  }

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      initialRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDateRange = picked);
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
        final isPureMutation = isInternalMutation(noteStr, catStr);

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

      // Tarik data investasi
      final invRes = await _supabase.from('investments').select('current_value').eq('user_id', userId);
      double totalInvestments = 0;
      for (var row in invRes as List) {
        totalInvestments += (row['current_value'] as num).toDouble();
      }

      final pdfBytes = await PdfService().generateReport(
        month: _isCustomRange ? startDate : _selectedMonth, 
        transactions: validTransactions,
        userName: userName,
        totalIncome: income,
        totalExpense: expense,
        totalSavings: totalSavings, 
        totalInvestments: totalInvestments,
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
    final String rangeLabel = _selectedDateRange != null
        ? "${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.end)}"
        : "Pilih rentang";

    return AppPageScaffold(
      title: 'Export Laporan',
      backLabel: 'Beranda',
      bottomBar: AppPrimaryButton(
        label: 'Cetak Laporan PDF',
        icon: PhosphorIconsFill.printer,
        loading: _isGenerating,
        onPressed: _isGenerating ? null : _generatePdf,
      ),
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              const AppIconTile(icon: PhosphorIconsFill.filePdf, color: AppColors.primary, size: 72),
              const SizedBox(height: 12),
              Text('Cetak Laporan Keuangan', style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'Pilih mode periode laporan di bawah ini',
                style: AppTextStyles.subhead,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        AppSegmentedControl(
          labels: const ['Satu Bulan', 'Pilih Tanggal'],
          selectedIndex: _isCustomRange ? 1 : 0,
          onChanged: (index) => setState(() => _isCustomRange = index == 1),
        ),
        AppGroupedSection(
          children: [
            if (!_isCustomRange)
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.primary),
                title: 'Bulan Laporan',
                value: DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                showChevron: true,
                onTap: _pickMonth,
              )
            else
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.calendarPlus, color: AppColors.primary),
                title: 'Rentang Tanggal',
                value: rangeLabel,
                showChevron: true,
                onTap: _pickDateRange,
              ),
          ],
        ),
      ],
    );
  }
}
