import 'package:catat_uang_app/core/transaction_tags.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data satu laporan PDF (argumen `PdfService.generateReport`).
class ExportReportData {
  const ExportReportData({
    required this.userName,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.totalInvestments,
    required this.mainCashBalance,
    required this.walletsInfo,
    required this.expensesByCategory,
    required this.incomeByCategory,
    required this.largestExpense,
    required this.largestIncome,
  });

  final String userName;
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final double totalInvestments;
  final double mainCashBalance;
  final List<Map<String, dynamic>> walletsInfo;
  final Map<String, double> expensesByCategory;
  final Map<String, double> incomeByCategory;
  final TransactionModel? largestExpense;
  final TransactionModel? largestIncome;
}

/// Mengumpulkan data laporan untuk periode [startDate]..[endDate]. Dipindah
/// dari `_ExportScreenState._generatePdf` tanpa mengubah query/aturan supaya
/// bisa diuji E2E. Mutasi tabungan & utang tidak dihitung.
Future<ExportReportData> loadExportReport(
  SupabaseClient db, {
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final userId = db.auth.currentUser!.id;

  final userResponse = await db.from('profiles').select('name').eq('id', userId).maybeSingle();
  final userName = (userResponse?['name'] ?? "User").toString();

  // Tarik data tabungan
  final savingsRes = await db.from('savings').select('id, name, amount').eq('user_id', userId);
  Map<String, String> savingNames = {};
  double totalSavings = 0;
  for (var row in savingsRes as List) {
    savingNames[row['id'].toString()] = row['name'].toString();
    totalSavings += (row['amount'] as num).toDouble();
  }

  // Data dompet untuk PDF
  final walletsRes = await db.from('wallets').select('id, name, balance').eq('user_id', userId);
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

  final response = await db
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

      // Info dompet disisipkan ke catatan supaya muncul di tabel PDF.
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
        if (largestExpense == null || trx.amount > largestExpense.amount) {
          largestExpense = trx;
        }
      } else {
        income += trx.amount;
        incomeByCategory[catName] = (incomeByCategory[catName] ?? 0) + trx.amount;
        if (largestIncome == null || trx.amount > largestIncome.amount) {
          largestIncome = trx;
        }
      }
    }
  }

  var sortedExpensesList = expensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  var sortedIncomesList = incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  // Tarik data investasi
  final invRes = await db.from('investments').select('current_value').eq('user_id', userId);
  double totalInvestments = 0;
  for (var row in invRes as List) {
    totalInvestments += (row['current_value'] as num).toDouble();
  }

  return ExportReportData(
    userName: userName,
    transactions: validTransactions,
    totalIncome: income,
    totalExpense: expense,
    totalSavings: totalSavings,
    totalInvestments: totalInvestments,
    mainCashBalance: totalWalletBalance,
    walletsInfo: walletsInfo,
    expensesByCategory: Map.fromEntries(sortedExpensesList),
    incomeByCategory: Map.fromEntries(sortedIncomesList),
    largestExpense: largestExpense,
    largestIncome: largestIncome,
  );
}
