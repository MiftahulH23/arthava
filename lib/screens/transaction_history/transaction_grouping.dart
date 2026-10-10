import 'package:arthava/models/transaction_model.dart';

/// Mengelompokkan transaksi per hari kalender untuk tampilan list bergrup.
/// Urutan grup mengikuti kemunculan pertama di [transactions] (provider
/// sudah mengurutkan terbaru dulu), urutan item di dalam grup dipertahankan.
List<(DateTime, List<TransactionModel>)> groupTransactionsByDate(
  List<TransactionModel> transactions,
) {
  final groups = <DateTime, List<TransactionModel>>{};
  for (final trx in transactions) {
    final day = DateTime(trx.date.year, trx.date.month, trx.date.day);
    groups.putIfAbsent(day, () => []).add(trx);
  }
  return [for (final entry in groups.entries) (entry.key, entry.value)];
}
