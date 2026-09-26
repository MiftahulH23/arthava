import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/screens/transaction_history/transaction_history_screen.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';

/// Wrapper yang menggabungkan tab Pemasukan & Pengeluaran ke dalam satu
/// destinasi navigasi (dipakai oleh [HomeScreen] mobile & web), supaya
/// bottom nav / rail hanya punya 3 destinasi alih-alih 4.
///
/// Tidak mengubah [TransactionHistoryScreen] sama sekali — widget ini
/// hanya menaruh AppSegmentedControl di bawah judul TransactionHistoryScreen dan menukar child mana yang
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
    final switcher = AppSegmentedControl(
      labels: const ['Pemasukan', 'Pengeluaran'],
      selectedIndex: _tabIndex,
      selectedLabelColors: const [AppColors.income, AppColors.expense],
      onChanged: (i) {
        if (i == _tabIndex) return;
        setState(() => _tabIndex = i);
        widget.onActiveTabChanged?.call(i == 1);
      },
    );

    return _tabIndex == 0
        ? TransactionHistoryScreen(
            key: ValueKey('pemasukan_${widget.refreshCounter}'),
            isExpense: false,
            typeSwitcher: switcher,
          )
        : TransactionHistoryScreen(
            key: ValueKey('pengeluaran_${widget.refreshCounter}'),
            isExpense: true,
            typeSwitcher: switcher,
          );
  }
}
