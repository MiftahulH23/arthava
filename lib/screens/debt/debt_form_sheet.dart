import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/core/formatters.dart';
import 'package:arthava/models/debt_model.dart';
import 'package:arthava/providers/debt_provider.dart';
import 'package:arthava/screens/debt/debt_wallet_picker.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_amount_display.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_callout.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_pickers.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:arthava/widgets/app_sheet.dart';
import 'package:arthava/widgets/app_switch.dart';
import 'package:arthava/widgets/app_text_field.dart';
import 'package:arthava/screens/wallet/wallet_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final DateFormat _dayFormat = DateFormat('dd MMM yyyy', 'id_ID');

String _amountText(double value) => formatRupiah(value).replaceFirst('Rp ', '');

String? validateDebtForm({
  required String name,
  required String amountText,
  required bool affectWallet,
  required int? walletId,
  double minAmount = 0,
}) {
  if (name.trim().isEmpty) return 'Nama tidak boleh kosong!';
  if (amountText.trim().isEmpty) return 'Jumlah tidak boleh kosong!';
  final amount = parseRupiah(amountText);
  if (amount <= 0) return 'Nominal harus lebih dari 0.';
  if (amount < minAmount) return 'Jumlah total tidak boleh kurang dari yang sudah dibayar.';
  if (affectWallet && walletId == null) return 'Silakan pilih dompet!';
  return null;
}

Future<void> showDebtFormSheet(
  BuildContext context, {
  DebtType initialType = DebtType.payable,
  DebtModel? debt,
}) {
  final title = debt == null
      ? 'Catat Utang / Piutang'
      : (debt.isPayable ? 'Edit Utang' : 'Edit Piutang');
  return showAppFormSheet<void>(
    context: context,
    title: title,
    builder: (sheetContext) => _DebtForm(initialType: initialType, debt: debt),
  );
}

class _DebtForm extends ConsumerStatefulWidget {
  const _DebtForm({required this.initialType, this.debt});

  final DebtType initialType;
  final DebtModel? debt;

  @override
  ConsumerState<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<_DebtForm> {
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late DebtType _type;
  late DateTime _loanDate;
  DateTime? _dueDate;
  bool _affectWallet = false;
  int? _walletId;
  bool _submitting = false;

  bool get _isEdit => widget.debt != null;

  DateTime get _today => DateUtils.dateOnly(ref.read(debtClockProvider)());

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    _type = d?.type ?? widget.initialType;
    _amountController = TextEditingController(text: d == null ? '' : _amountText(d.amount));
    _nameController = TextEditingController(text: d?.name ?? '');
    _notesController = TextEditingController(text: d?.notes ?? '');
    _loanDate = d?.loanDate ?? _today;
    _dueDate = d?.dueDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickLoanDate() async {
    final today = _today;
    final picked = await showAppDatePicker(
      context: context,
      title: 'Tanggal Pinjam',
      initialDate: _loanDate.isAfter(today) ? today : _loanDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _loanDate = picked);
  }

  Future<void> _pickDueDate() async {
    final today = _today;
    final last = DateTime(today.year + 10, 12, 31);
    final initial = _dueDate ?? today;
    final picked = await showAppDatePicker(
      context: context,
      title: 'Jatuh Tempo',
      initialDate: initial.isBefore(DateTime(2000)) ? today : initial,
      firstDate: DateTime(2000),
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    // Dua tap yang mendarat sebelum rebuild memanggil ini dua kali.
    if (_submitting) return;
    final error = validateDebtForm(
      name: _nameController.text,
      amountText: _amountController.text,
      affectWallet: !_isEdit && _affectWallet,
      walletId: _walletId,
      minAmount: widget.debt?.paidAmount ?? 0,
    );
    if (error != null) {
      AppNotification.error(context, error);
      return;
    }
    setState(() => _submitting = true);
    final notifier = ref.read(debtProvider.notifier);
    final amount = parseRupiah(_amountController.text).toDouble();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    try {
      if (_isEdit) {
        await notifier.updateDebt(
          debtId: widget.debt!.id,
          name: _nameController.text.trim(),
          amount: amount,
          loanDate: _loanDate,
          dueDate: _dueDate,
          notes: notes,
        );
      } else {
        await notifier.createDebt(
          name: _nameController.text.trim(),
          type: _type,
          amount: amount,
          loanDate: _loanDate,
          dueDate: _dueDate,
          notes: notes,
          walletId: _affectWallet ? _walletId : null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppNotification.success(context, _isEdit ? 'Perubahan disimpan!' : 'Utang/Piutang berhasil dicatat!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppNotification.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(debtProvider.select((s) => s.wallets));
    final isPayable = _type == DebtType.payable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isEdit) ...[
          AppSegmentedControl(
            labels: const ['Utang', 'Piutang'],
            selectedIndex: isPayable ? 0 : 1,
            selectedLabelColors: const [AppColors.expense, AppColors.income],
            onChanged: (i) => setState(() => _type = i == 0 ? DebtType.payable : DebtType.receivable),
          ),
          const SizedBox(height: 14),
        ],
        AppAmountField(controller: _amountController, label: 'Jumlah Uang', autofocus: !_isEdit),
        const SizedBox(height: 14),
        Text('Nama Peminjam / Pemberi Pinjaman', style: AppTextStyles.caption),
        const SizedBox(height: 6),
        AppTextField(
          controller: _nameController,
          icon: PhosphorIconsRegular.user,
          hint: isPayable ? 'Contoh: Budi, Bank, dll' : 'Contoh: Andi, Teman, dll',
        ),
        const SizedBox(height: 14),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsRegular.calendarBlank, color: AppColors.tintBlue),
              title: 'Tanggal Pinjam',
              value: _dayFormat.format(_loanDate),
              showChevron: true,
              onTap: _pickLoanDate,
            ),
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsRegular.clock, color: AppColors.tintOrange),
              title: 'Jatuh Tempo (Opsional)',
              value: _dueDate == null ? 'Pilih Tanggal' : _dayFormat.format(_dueDate!),
              showChevron: _dueDate == null,
              trailing: _dueDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Hapus jatuh tempo',
                      icon: const Icon(PhosphorIconsRegular.xCircle, color: AppColors.textSecondary, size: 20),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: _pickDueDate,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Catatan (Opsional)', style: AppTextStyles.caption),
        const SizedBox(height: 6),
        AppTextField(controller: _notesController, hint: 'Contoh: Modal usaha', maxLines: 2),
        const SizedBox(height: 14),
        if (_isEdit) ...[
          if (widget.debt!.transactionId != null)
            const AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text('Perubahan jumlah ikut menyesuaikan saldo dompet yang dipakai saat pinjaman dicatat.'),
            ),
        ] else ...[
          AppGroupedSection(
            children: [
              AppListRow(
                title: 'Catat transaksi ini ke Dompet?',
                subtitle: wallets.isEmpty ? 'Belum ada dompet — buat di bawah' : null,
                trailing: AppSwitch(
                  key: const ValueKey('debt-form-affect-wallet'),
                  value: _affectWallet,
                  onChanged: (v) => setState(() => _affectWallet = v),
                ),
              ),
              if (_affectWallet)
                DebtWalletPickerRow(
                  wallets: wallets,
                  selectedWalletId: _walletId,
                  onSelected: (id) => setState(() => _walletId = id),
                  onCreate: () => showWalletFormSheet(
                    context,
                    onSaved: () => ref.read(debtProvider.notifier).fetchData(silent: true),
                  ),
                ),
            ],
          ),
          if (_affectWallet) ...[
            const SizedBox(height: 10),
            AppCallout(
              icon: PhosphorIconsFill.info,
              child: Text(
                isPayable
                    ? 'Info: Saldo dompet akan BERTAMBAH karena Anda menerima uang pinjaman.'
                    : 'Info: Saldo dompet akan BERKURANG karena Anda meminjamkan uang.',
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
      ],
    );
  }
}
