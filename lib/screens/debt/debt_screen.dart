import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'debt_detail_screen.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/widgets/app_empty_state.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';

class DebtScreen extends ConsumerStatefulWidget {
  const DebtScreen({super.key});

  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen> {
  bool _isMyDebt = true;

  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final inputFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  void _showAddDebtSheet(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate;
    String debtType = _isMyDebt ? 'payable' : 'receivable';
    bool affectWallet = false;
    int? selectedWalletId;

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final wallets = ref.read(debtProvider).wallets;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Catat Utang / Piutang",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(PhosphorIconsRegular.x),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => debtType = 'payable'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: debtType == 'payable' ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: debtType == 'payable' ? [
                                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Utang",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: debtType == 'payable' ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => debtType = 'receivable'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: debtType == 'receivable' ? Colors.green : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: debtType == 'receivable' ? [
                                    BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Piutang",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: debtType == 'receivable' ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Nama Peminjam / Pemberi Pinjaman",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: debtType == 'payable'
                            ? "Contoh: Budi, Bank, dll"
                            : "Contoh: Andi, Teman, dll",
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Jumlah Uang",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            "Rp",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        final s = val.replaceAll(RegExp(r'[^0-9]'), '');
                        if (s.isNotEmpty) {
                          final formatted = inputFormat.format(int.parse(s)).trim();
                          amountController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        } else {
                          amountController.value = const TextEditingValue(text: '');
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Jatuh Tempo (Opsional)",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setSheetState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.calendarBlank,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              selectedDate == null
                                  ? "Pilih Tanggal Jatuh Tempo"
                                  : DateFormat('dd MMM yyyy')
                                      .format(selectedDate!),
                              style: GoogleFonts.poppins(
                                color: selectedDate == null
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Opsi Sinkron Dompet
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "Catat transaksi ini ke Dompet?",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Switch(
                                value: affectWallet,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setSheetState(() => affectWallet = val);
                                },
                              ),
                            ],
                          ),
                          if (affectWallet) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              value: selectedWalletId,
                              hint: Text(
                                "Pilih Dompet",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                              ),
                              items: wallets.map((w) {
                                return DropdownMenuItem<int>(
                                  value: w.id,
                                  child: Text(
                                    w.name,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setSheetState(() => selectedWalletId = val);
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              debtType == 'payable'
                                  ? "Info: Saldo dompet akan BERTAMBAH karena Anda menerima uang pinjaman."
                                  : "Info: Saldo dompet akan BERKURANG karena Anda meminjamkan uang.",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) {
                            AppNotification.error(
                              context,
                              "Nama tidak boleh kosong!",
                            );
                            return;
                          }
                          if (amountController.text.isEmpty) {
                            AppNotification.error(
                              context,
                              "Jumlah tidak boleh kosong!",
                            );
                            return;
                          }
                          if (affectWallet && selectedWalletId == null) {
                            AppNotification.error(
                              context,
                              "Silakan pilih dompet!",
                            );
                            return;
                          }

                          final rawAmount = double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );

                          try {
                            await ref.read(debtProvider.notifier).createDebt(
                                  name: nameController.text.trim(),
                                  type: debtType == 'payable' ? DebtType.payable : DebtType.receivable,
                                  amount: rawAmount,
                                  loanDate: DateTime.now(),
                                  dueDate: selectedDate,
                                  walletId: affectWallet ? selectedWalletId : null,
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.success(
                                context,
                                "Utang/Piutang berhasil dicatat!",
                              );
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                            if (context.mounted) {
                              AppNotification.error(
                                context,
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            }
                          }
                        },
                        child: Text(
                          "Simpan",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final debtState = ref.watch(debtProvider);
    final today = ref.watch(debtClockProvider)();
    final debts = _isMyDebt ? debtState.myDebts(today) : debtState.theirDebts(today);

    return AppPageScaffold(
      title: 'Utang & Piutang',
      backLabel: 'Beranda',
      actions: [
        AppNavAction.add(onPressed: () => _showAddDebtSheet(context)),
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
