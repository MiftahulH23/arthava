import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'debt_detail_screen.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/screens/debt/debt_form_sheet.dart';

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

    return AppPageScaffold(
      title: 'Utang & Piutang',
      backLabel: 'Beranda',
      actions: [
        AppNavAction.add(
          onPressed: () => showDebtFormSheet(
            context,
            initialType: _isMyDebt ? DebtType.payable : DebtType.receivable,
          ),
        ),
      ],
      onRefresh: () => ref.read(debtProvider.notifier).fetchData(),
      children: [
        DebtTotalsRow(
          totalPayable: debtState.totalPayable,
          totalReceivable: debtState.totalReceivable,
        ),
        AppSegmentedControl(
          labels: const ['Utang Saya', 'Piutang'],
          selectedIndex: _isMyDebt ? 0 : 1,
          onChanged: (index) => setState(() => _isMyDebt = index == 0),
        ),
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
            DebtCard(
              key: ValueKey('debt-${debt.id}'),
              debt: debt,
              today: today,
              onTap: () => _openDetail(debt),
            ),
      ],
    );
  }

  Future<void> _openDetail(DebtModel debt) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DebtDetailScreen(debtId: debt.id)),
    );
  }
}
