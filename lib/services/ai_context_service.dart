import 'package:arthava/core/transaction_tags.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Kertas contekan" keuangan user untuk asisten AI (Tanya AI): saldo dompet,
/// tabungan, dan rekap 6 bulan terakhir tanpa mutasi tabungan/utang.
/// Dipindah dari `_AiAdvisorScreenState._fetchFinancialContext` tanpa mengubah
/// query/format supaya bisa diuji E2E.
Future<String> buildFinancialContext(SupabaseClient db) async {
  final userId = db.auth.currentUser!.id;
  
  final res = await db
      .from('transactions')
      .select('amount, date, note, categories(name, is_expense)') 
      .eq('user_id', userId)
      .order('date', ascending: false);

  final savingsRes = await db
      .from('savings')
      .select('name, amount')
      .eq('user_id', userId);

  // [NEW] Ambil Data Dompet Asli User
  final walletsRes = await db
      .from('wallets')
      .select('name, balance')
      .eq('user_id', userId);

  double totalSavings = 0; 
  Map<String, double> savingsBreakdown = {};

  for (var row in savingsRes as List) {
    final amount = (row['amount'] as num).toDouble();
    final name = row['name']?.toString() ?? 'Tabungan Umum';
    
    totalSavings += amount;
    savingsBreakdown[name] = (savingsBreakdown[name] ?? 0) + amount;
  }

  // [NEW] Hitung Rincian Dompet
  double totalWalletBalance = 0;
  Map<String, double> walletBreakdown = {};
  for (var row in walletsRes as List) {
    final amount = (row['balance'] as num).toDouble();
    final name = row['name']?.toString() ?? 'Dompet Tak Bernama';
    totalWalletBalance += amount;
    walletBreakdown[name] = amount;
  }

  Map<String, Map<String, dynamic>> monthlyStats = {};

  for (var item in res) {
    final date = DateTime.parse(item['date']);
    final monthKey = DateFormat('MMMM yyyy', 'id_ID').format(date);
    
    if (!monthlyStats.containsKey(monthKey)) {
      monthlyStats[monthKey] = {
        'realIncome': 0.0,
        'realExpense': 0.0,
        'expenseByCategory': <String, double>{},
        'incomeByCategory': <String, double>{},
      };
    }

    final amount = (item['amount'] as num).toDouble();
    final isExpense = item['categories']['is_expense'] as bool;
    final catName = item['categories']['name'].toString();
    final note = item['note']?.toString() ?? '';

    final isPureMutation = isInternalMutation(note, catName);

    if (!isPureMutation) {
      if (isExpense) {
        monthlyStats[monthKey]!['realExpense'] += amount;
        monthlyStats[monthKey]!['expenseByCategory'][catName] = 
            (monthlyStats[monthKey]!['expenseByCategory'][catName] ?? 0) + amount;
      } else {
        monthlyStats[monthKey]!['realIncome'] += amount;
        monthlyStats[monthKey]!['incomeByCategory'][catName] = 
            (monthlyStats[monthKey]!['incomeByCategory'][catName] ?? 0) + amount;
      }
    }
  }

  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  
  String contextStr = "=== INFORMASI KEKAYAAN SAAT INI ===\n";
  // [NEW] Kasih tau AI saldo berdasarkan Dompet Fisik/Digital
  contextStr += "- Total Kekayaan (Semua Dompet): ${currency.format(totalWalletBalance)}\n";
  if (walletBreakdown.isNotEmpty) {
    contextStr += "- Rincian Posisi Uang (Dompet):\n";
    for (var wallet in walletBreakdown.entries) {
      contextStr += "  * ${wallet.key}: ${currency.format(wallet.value)}\n";
    }
  } else {
    contextStr += "  (Belum ada dompet yang dibuat)\n";
  }
  contextStr += "\n";
  
  contextStr += "=== RINCIAN TABUNGAN (TUJUAN KEUANGAN) ===\n";
  contextStr += "- Total Keseluruhan Tabungan: ${currency.format(totalSavings)}\n";
  
  var sortedSavings = savingsBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (sortedSavings.isEmpty || totalSavings <= 0) {
    contextStr += "  (Belum ada tabungan yang aktif)\n";
  } else {
    contextStr += "- Daftar Tujuan Tabungan:\n";
    for (var saving in sortedSavings) {
      if (saving.value > 0) { 
        contextStr += "  * ${saving.key}: ${currency.format(saving.value)}\n";
      }
    }
  }
  contextStr += "\n";
  
  contextStr += "=== REKAPAN KEUANGAN PER BULAN ===\n";
  
  int monthCount = 0;
  for (var entry in monthlyStats.entries) {
    if (monthCount >= 6) break;
    
    final monthName = entry.key;
    final stats = entry.value;
    
    contextStr += "[Bulan: $monthName]\n";
    contextStr += "- Total Pemasukan: ${currency.format(stats['realIncome'])}\n";
    contextStr += "- Total Pengeluaran: ${currency.format(stats['realExpense'])}\n";
    
    var sortedExpense = (stats['expenseByCategory'] as Map<String, double>).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sortedExpense.isNotEmpty) {
      contextStr += "  * Rincian Pengeluaran:\n";
      for (var cat in sortedExpense) {
        contextStr += "    - ${cat.key}: ${currency.format(cat.value)}\n";
      }
    }
    
    var sortedIncome = (stats['incomeByCategory'] as Map<String, double>).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sortedIncome.isNotEmpty) {
      contextStr += "  * Rincian Pemasukan:\n";
      for (var cat in sortedIncome) {
        contextStr += "    - ${cat.key}: ${currency.format(cat.value)}\n";
      }
    }
    contextStr += "\n";
    monthCount++;
  }

  return contextStr;
}
