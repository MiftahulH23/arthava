import 'package:arthava/core/colors.dart';
import 'package:arthava/screens/transaction_history/transaction_history_screen.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:arthava/widgets/app_swipe_tabs.dart';

/// Wrapper yang menggabungkan tab Pemasukan & Pengeluaran ke dalam satu
/// destinasi navigasi (dipakai oleh [HomeScreen] mobile & web), supaya
/// bottom nav / rail hanya punya 3 destinasi alih-alih 4.
///
/// Widget ini menaruh AppSegmentedControl di bawah judul TransactionHistoryScreen
/// dan mengganti `isExpense`-nya; geser layar ditangani [AppSwipeTabs].
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
      onChanged: _select,
    );

    // Satu instance untuk kedua tab: judul, switcher, dan filter tetap diam;
    // hanya isi di dalam AppSwipeTabBody (milik TransactionHistoryScreen) yang
    // tertarik jari dan meluncur saat tab berganti.
    return AppSwipeTabs(
      index: _tabIndex,
      count: 2,
      onChanged: _select,
      child: TransactionHistoryScreen(
        key: ValueKey('transaksi_${widget.refreshCounter}'),
        isExpense: _tabIndex == 1,
        typeSwitcher: switcher,
      ),
    );
  }

  void _select(int i) {
    if (i == _tabIndex) return;
    setState(() => _tabIndex = i);
    widget.onActiveTabChanged?.call(i == 1);
  }
}
