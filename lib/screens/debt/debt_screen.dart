import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/screens/debt/debt_delete.dart';
import 'package:arthava/widgets/app_swipe_actions.dart';
import 'package:arthava/models/debt_model.dart';
import 'package:arthava/providers/debt_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'debt_detail_screen.dart';
import 'package:arthava/screens/debt/widgets/debt_card.dart';
import 'package:arthava/widgets/app_empty_state.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:arthava/screens/debt/debt_form_sheet.dart';
import 'package:arthava/widgets/app_swipe_tabs.dart';

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  bool _isMyDebt = true;

  @override
  Widget build(BuildContext context) {
    final debtState = ref.watch(debtProvider);
    final today = ref.watch(debtClockProvider)();
    final debts = _isMyDebt ? debtState.myDebts(today) : debtState.theirDebts(today);

    return AppSwipeTabs(
      index: _isMyDebt ? 0 : 1,
      count: 2,
      onChanged: (index) => setState(() => _isMyDebt = index == 0),
      child: AppPageScaffold(
        title: 'Utang & Piutang',
        backLabel: 'Beranda',
        actions: [
          AppNavAction.add(
            onPressed: () =>
                showDebtFormSheet(context, initialType: _isMyDebt ? DebtType.payable : DebtType.receivable),
          ),
        ],
        onRefresh: () => ref.read(debtProvider.notifier).fetchData(),
        children: [
          DebtTotalsRow(totalPayable: debtState.totalPayable, totalReceivable: debtState.totalReceivable),
          AppSegmentedControl(
            labels: const ['Utang Saya', 'Piutang'],
            selectedIndex: _isMyDebt ? 0 : 1,
            onChanged: (index) => setState(() => _isMyDebt = index == 0),
          ),
          AppSwipeTabBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                if (debtState.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (debts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: AppEmptyState(
                      icon: PhosphorIconsRegular.handCoins,
                      title: _isMyDebt
                          ? 'Belum ada utang yang dicatat.\nAlhamdulillah!'
                          : 'Belum ada orang yang ngutang ke kamu.',
                    ),
                  )
                else
                  for (final debt in debts)
                    AppSwipeActions(
                      key: ValueKey('debt-${debt.id}'),
                      borderRadius: BorderRadius.circular(24),
                      confirmDelete: false,
                      onEdit: () => showDebtFormSheet(context, debt: debt),
                      onDelete: () => _delete(debt),
                      child: DebtCard(debt: debt, today: today, onTap: () => _openDetail(debt)),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(DebtModel debt) async {
    try {
      final refund = await confirmAndDeleteDebt(context, ref, debt);
      if (refund == null || !mounted) return;
      AppNotification.success(context, refund ? 'Utang dihapus dan saldo dikembalikan!' : 'Data berhasil dihapus!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openDetail(DebtModel debt) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => DebtDetailScreen(debtId: debt.id)));
  }
}
