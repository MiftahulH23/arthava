import 'package:catat_uang_app/screens/transaction_history/transaction_history_screen.dart';
import 'package:catat_uang_app/widgets/app_tab_selector.dart';
import 'package:flutter/material.dart';

/// Wrapper yang menggabungkan tab Pemasukan & Pengeluaran ke dalam satu
/// destinasi navigasi (dipakai oleh [HomeScreen] mobile & web), supaya
/// bottom nav / rail hanya punya 3 destinasi alih-alih 4.
///
/// Tidak mengubah [TransactionHistoryScreen] sama sekali — widget ini
/// hanya menaruh [AppTabSelector] di atas dan menukar child mana yang
/// ditampilkan lewat kondisi sederhana (bukan IndexedStack/TabBarView,
/// mengikuti pola sederhana yang sudah dipakai di codebase ini).
class TransactionsTabScreen extends StatefulWidget {
  final int refreshCounter;
  final bool initialIsExpense;
  final ValueChanged<bool>? onActiveTabChanged;

  const TransactionsTabScreen({
    super.key,
    required this.refreshCounter,
    this.initialIsExpense = false,
    this.onActiveTabChanged,
  });

  @override
  State<TransactionsTabScreen> createState() => _TransactionsTabScreenState();
}

class _TransactionsTabScreenState extends State<TransactionsTabScreen> {
  late int _tabIndex = widget.initialIsExpense ? 1 : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onActiveTabChanged?.call(widget.initialIsExpense);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: AppTabSelector(
              labels: const ['Pemasukan', 'Pengeluaran'],
              initialIndex: _tabIndex,
              onChanged: (i) {
                setState(() => _tabIndex = i);
                widget.onActiveTabChanged?.call(i == 1);
              },
            ),
          ),
          Expanded(
            child: _tabIndex == 0
                ? TransactionHistoryScreen(
                    key: ValueKey('pemasukan_${widget.refreshCounter}'),
                    isExpense: false,
                  )
                : TransactionHistoryScreen(
                    key: ValueKey('pengeluaran_${widget.refreshCounter}'),
                    isExpense: true,
                  ),
          ),
        ],
      ),
    );
  }
}
