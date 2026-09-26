import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/models/debt_model.dart';
import 'package:catat_uang_app/models/debt_payment_model.dart';
import 'package:catat_uang_app/providers/debt_provider.dart';
import 'package:catat_uang_app/screens/debt/debt_wallet_picker.dart';
import 'package:catat_uang_app/screens/debt/widgets/debt_card.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_surface_card.dart';
import 'package:catat_uang_app/widgets/app_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

String _amountText(double value) => formatRupiah(value).replaceFirst('Rp ', '');

String? validateDebtPayment({
  required String amountText,
  required double maxAmount,
  required bool affectWallet,
  required int? walletId,
}) {
  final amount = parseRupiah(amountText);
  if (amount <= 0) return 'Nominal harus lebih dari 0.';
  if (amount > maxAmount) return 'Jumlah bayar tidak boleh melebihi sisa utang!';
  if (affectWallet && walletId == null) return 'Silakan pilih dompet!';
  return null;
}

String deletePaymentConfirmMessage(DebtPaymentModel payment) {
  final base = 'Sisa tagihan bertambah ${formatRupiah(payment.amount)}';
  if (payment.affectsWallet) {
    return '$base dan saldo ${payment.walletName ?? 'dompet'} dikembalikan.';
  }
  if (payment.walletId != null) {
    return '$base. Cicilan lama ini tidak terhubung ke transaksi dompet, jadi saldo dompet tidak berubah.';
  }
  return '$base.';
}

Future<void> showDebtPaymentSheet(
  BuildContext context, {
  required DebtModel debt,
  DebtPaymentModel? payment,
}) async {
  if (payment == null && debt.remainingAmount <= 0) {
    AppNotification.success(context, 'Utang ini sudah lunas!');
    return;
  }
  final title = payment != null
      ? 'Edit Cicilan'
      : (debt.isPayable ? 'Bayar Cicilan Utang' : 'Terima Pembayaran');
  await showAppFormSheet<void>(
    context: context,
    title: title,
    builder: (sheetContext) => _DebtPaymentForm(debt: debt, payment: payment),
  );
}

class _DebtPaymentForm extends ConsumerStatefulWidget {
  const _DebtPaymentForm({required this.debt, this.payment});

  final DebtModel debt;
  final DebtPaymentModel? payment;

  @override
  ConsumerState<_DebtPaymentForm> createState() => _DebtPaymentFormState();
}

class _DebtPaymentFormState extends ConsumerState<_DebtPaymentForm> {
  late final TextEditingController _amountController;
  late DateTime _date;
  bool _affectWallet = false;
  int? _walletId;
  bool _submitting = false;

  bool get _isEdit => widget.payment != null;

  double get _maxAmount => widget.debt.remainingAmount + (widget.payment?.amount ?? 0);

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _amountController = TextEditingController(text: p == null ? '' : _amountText(p.amount));
    _date = p?.date ?? DateUtils.dateOnly(ref.read(debtClockProvider)());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(ref.read(debtClockProvider)());
    final first = widget.debt.loanDate.isAfter(today) ? today : widget.debt.loanDate;
    DateTime initial = _date;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(today)) initial = today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    // Dua tap yang mendarat sebelum rebuild memanggil ini dua kali.
    if (_submitting) return;
    final error = validateDebtPayment(
      amountText: _amountController.text,
      maxAmount: _maxAmount,
      affectWallet: !_isEdit && _affectWallet,
      walletId: _walletId,
    );
    if (error != null) {
      AppNotification.error(context, error);
      return;
    }
    setState(() => _submitting = true);
    final notifier = ref.read(debtProvider.notifier);
    final amount = parseRupiah(_amountController.text).toDouble();
    try {
      if (_isEdit) {
        await notifier.updatePayment(
          debtId: widget.debt.id,
          paymentId: widget.payment!.id,
          amount: amount,
          date: _date,
        );
      } else {
        await notifier.addPayment(
          debtId: widget.debt.id,
          amount: amount,
          date: _date,
          walletId: _affectWallet ? _walletId : null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, _isEdit ? 'Cicilan diperbarui!' : 'Pembayaran berhasil dicatat!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final wallets = ref.watch(debtProvider.select((s) => s.wallets));
    final mainColor = debtMainColor(debt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurfaceCard(
          child: AppAmountDisplay(
            label: 'Sisa Tagihan Saat Ini',
            amountText: formatRupiah(_maxAmount),
            color: mainColor,
          ),
        ),
        const SizedBox(height: 14),
        AppAmountField(controller: _amountController, label: 'Jumlah Uang', autofocus: !_isEdit),
        const SizedBox(height: 14),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.tintBlue),
              title: 'Tanggal Pembayaran',
              value: _dayFormat.format(_date),
              showChevron: true,
              onTap: _pickDate,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isEdit) ...[
          if (widget.payment!.affectsWallet)
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text('Perubahan nominal ikut menyesuaikan saldo ${widget.payment!.walletName ?? 'dompet'}.'),
            ),
        ] else ...[
          AppGroupedSection(
            children: [
              AppListRow(
                title: 'Catat ke Dompet?',
                subtitle: wallets.isEmpty ? 'Belum ada dompet' : null,
                trailing: AppSwitch(
                  key: const ValueKey('debt-affect-wallet'),
                  value: _affectWallet,
                  onChanged: wallets.isEmpty ? null : (v) => setState(() => _affectWallet = v),
                ),
              ),
              if (_affectWallet)
                DebtWalletPickerRow(
                  wallets: wallets,
                  selectedWalletId: _walletId,
                  onSelected: (id) => setState(() => _walletId = id),
                ),
            ],
          ),
          if (_affectWallet) ...[
            const SizedBox(height: 10),
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                debt.isPayable
                    ? 'Info: Saldo dompet akan BERKURANG karena Anda membayar utang.'
                    : 'Info: Saldo dompet akan BERTAMBAH karena Anda menerima pembayaran.',
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: 'Simpan',
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
        const SizedBox(height: 4),
        Text(
          'Maksimal ${formatRupiah(_maxAmount)}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
