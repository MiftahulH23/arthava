import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/category_visuals.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:catat_uang_app/widgets/app_amount_display.dart';
import 'package:catat_uang_app/widgets/app_buttons.dart';
import 'package:catat_uang_app/widgets/app_callout.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:catat_uang_app/widgets/app_grouped_section.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:catat_uang_app/widgets/app_pickers.dart';
import 'package:catat_uang_app/widgets/app_segmented_control.dart';
import 'package:catat_uang_app/widgets/app_sheet.dart';
import 'package:catat_uang_app/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class InputTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel? transactionToEdit;
  final bool initialIsExpense;

  const InputTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.initialIsExpense = false,
  });

  @override
  ConsumerState<InputTransactionScreen> createState() =>
      _InputTransactionScreenState();
}

class _InputTransactionScreenState
    extends ConsumerState<InputTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  late bool _isExpense;

  bool _isReadOnly = false;
  bool _readOnlyFromDebt = false;
  String? _hiddenSavingMarker;

  int? _selectedWalletId;

  bool _isFromSaving = false;
  String? _selectedSavingName;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.initialIsExpense;

    if (widget.transactionToEdit != null) {
      final trx = widget.transactionToEdit!;
      _amountController.text = _currencyFormat.format(trx.amount);

      String rawNote = trx.note ?? '';
      final match = RegExp(r'\s*\[SAVING_ID:\d+\]').firstMatch(rawNote);
      final debtMatch = RegExp(r'\s*\[DEBT_ID:[^\]]*\]').firstMatch(rawNote);
      if (match != null) {
        _hiddenSavingMarker = match.group(0);
        _noteController.text = rawNote.replaceAll(match.group(0)!, '');
        _isReadOnly = true;
      } else if (debtMatch != null) {
        _hiddenSavingMarker = debtMatch.group(0);
        _noteController.text = rawNote.replaceAll(debtMatch.group(0)!, '').trim();
        _isReadOnly = true;
        _readOnlyFromDebt = true;
      } else {
        _noteController.text = rawNote;
      }

      _selectedDate = trx.date;
      _selectedCategoryId = trx.categoryId;
      _selectedWalletId = trx.walletId;
    }
  }

  Future<void> _processScanReceipts(List<XFile> images) async {
    if (images.isEmpty) return;
    final result = await runWithAppLoading(
      context,
      () => GeminiService.scanReceipts(images),
      message: 'Membaca struk...',
    );
    if (!mounted) return;

    if (result != null) {
      final categories = ref.read(inputTransactionProvider).categories;
      setState(() {
        double total = (result['total'] as num?)?.toDouble() ?? 0;
        if (total > 0) {
          _amountController.value = TextEditingValue(
            text: _currencyFormat.format(total),
            selection: TextSelection.collapsed(
              offset: _currencyFormat.format(total).length,
            ),
          );
        }
        String aiCategory = result['kategori'].toString().toLowerCase();
        var matchedCat = categories.where((c) {
          String dbCat = c['name'].toString().toLowerCase();
          return dbCat.contains(aiCategory) || aiCategory.contains(dbCat);
        }).firstOrNull;
        if (matchedCat != null) {
          _selectedCategoryId = matchedCat['id'];
          if (_noteController.text.isEmpty) {
            _noteController.text = images.length > 1
                ? "Total dari ${images.length} Struk"
                : "Hasil Scan AI";
          }
        } else {
          _noteController.text =
              "AI Kategori: ${result['kategori']} (Sesuaikan)";
        }
      });
      if (mounted)
        AppNotification.success(
          context,
          "Berhasil menjumlahkan ${images.length} struk! 🚀",
        );
    } else {
      if (mounted) AppNotification.error(context, "AI gagal membaca struk.");
    }
  }

  Future<void> _saveTransaction() async {
    // Peringatan saldo minimal (spec §7.3): pengeluaran dari dompet, baru atau diedit.
    // Hanya bila isian dasar lengkap, supaya validasi lama di provider tetap bicara
    // lebih dulu (urutan sama dengan Transfer).
    final amount = parseRupiah(_amountController.text).toDouble();
    if (_isExpense &&
        !_isFromSaving &&
        !_isReadOnly &&
        _selectedWalletId != null &&
        _selectedCategoryId != null &&
        amount > 0) {
      Map<String, dynamic>? wallet;
      for (final w in ref.read(inputTransactionProvider).wallets) {
        if (w['id'] == _selectedWalletId) {
          wallet = w;
          break;
        }
      }
      if (wallet != null) {
        // Saat edit, provider mengembalikan dulu efek transaksi lama ke dompetnya.
        var balance = (wallet['balance'] as num).toDouble();
        final old = widget.transactionToEdit;
        if (old != null && old.walletId == _selectedWalletId) {
          balance += widget.initialIsExpense ? old.amount : -old.amount;
        }
        final warning = minBalanceWarningMessage(
          walletName: wallet['name'].toString(),
          balance: balance,
          minBalance: (wallet['min_balance'] as num?)?.toDouble() ?? 0,
          amount: amount,
        );
        if (warning != null) {
          final ok = await showAppConfirmDialog(
            context: context,
            title: 'Di bawah saldo minimal',
            message: warning,
            confirmLabel: 'Lanjutkan',
            destructive: false,
          );
          if (!ok || !mounted) return;
        }
      }
    }
    final notifier = ref.read(inputTransactionProvider.notifier);
    final result = await notifier.saveTransaction(
      amountText: _amountController.text,
      noteText: _noteController.text,
      selectedCategoryId: _selectedCategoryId,
      selectedWalletId: _selectedWalletId,
      isExpense: _isExpense,
      isFromSaving: _isFromSaving,
      selectedSavingName: _selectedSavingName,
      selectedDate: _selectedDate,
      hiddenSavingMarker: _hiddenSavingMarker,
      isReadOnly: _isReadOnly,
      transactionToEdit: widget.transactionToEdit,
      initialIsExpense: widget.initialIsExpense,
    );
    if (!mounted) return;
    if (result.success) {
      AppNotification.success(context, result.message);
      Navigator.pop(context, true);
    } else {
      AppNotification.error(context, result.message);
    }
  }

  void _showImageSourceBottomSheet() {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Metode Scan",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsFill.camera, color: AppColors.primary),
            title: "Kamera",
            subtitle: "(1 Struk)",
            showChevron: true,
            onTap: () async {
              Navigator.pop(sheetContext);
              final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (image != null) _processScanReceipts([image]);
            },
          ),
          AppListRow(
            leading: const AppIconTile(icon: PhosphorIconsFill.images, color: AppColors.tintIndigo),
            title: "Galeri",
            subtitle: "(Banyak Struk)",
            showChevron: true,
            onTap: () async {
              Navigator.pop(sheetContext);
              final images = await _picker.pickMultiImage(imageQuality: 80);
              if (images.isNotEmpty) _processScanReceipts(images);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    if (_isReadOnly) return;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Warna dari data dompet; hex tak valid tidak lagi melempar FormatException.
  Color _walletColor(Map<String, dynamic> wallet) => AppColors.fromWalletHex(wallet['color']?.toString());

  static const Widget _checkIcon = Icon(PhosphorIconsBold.check, color: AppColors.primary, size: 20);

  void _onTypeSelected(bool isExpenseBtn) {
    if (_isReadOnly) return;
    final wallets = ref.read(inputTransactionProvider).wallets;
    setState(() {
      _isExpense = isExpenseBtn;
      _selectedCategoryId = null;
      if (!isExpenseBtn) {
        _isFromSaving = false;
        _selectedSavingName = null;
        if (wallets.isNotEmpty) _selectedWalletId = wallets.first['id'];
      }
    });
  }

  void _useWallet(InputTransactionState state) {
    setState(() {
      _isFromSaving = false;
      _selectedSavingName = null;
      if (state.wallets.isNotEmpty) _selectedWalletId = state.wallets.first['id'];
    });
  }

  void _useSaving(InputTransactionState state) {
    setState(() {
      _isFromSaving = true;
      _selectedWalletId = null;
      if (state.savingNamesList.isNotEmpty && _selectedSavingName == null) {
        _selectedSavingName = state.savingNamesList.first;
      }
    });
  }

  void _showWalletPicker(List<Map<String, dynamic>> wallets) {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Dompet",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final wallet in wallets)
            AppListRow(
              leading: AppIconTile(icon: PhosphorIconsFill.wallet, color: _walletColor(wallet), filled: true),
              title: wallet['name'].toString(),
              value: formatRupiah(wallet['balance'] as num),
              trailing: wallet['id'] == _selectedWalletId ? _checkIcon : null,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedWalletId = wallet['id'] as int);
              },
            ),
        ],
      ),
    );
  }

  void _showSavingPicker(InputTransactionState state) {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Tabungan",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final savingName in state.savingNamesList)
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsFill.piggyBank, color: AppColors.primary),
              title: savingName,
              value: "Sisa: ${formatRupiah(state.savingsBalances[savingName] ?? 0)}",
              trailing: savingName == _selectedSavingName ? _checkIcon : null,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedSavingName = savingName);
              },
            ),
        ],
      ),
    );
  }

  void _showCategoryPicker(List<Map<String, dynamic>> categories) {
    showAppFormSheet<void>(
      context: context,
      title: "Pilih Kategori",
      builder: (sheetContext) => AppGroupedSection(
        children: [
          for (final cat in categories)
            AppListRow(
              leading: AppIconTile(
                icon: categoryIcon(cat['name'].toString()),
                color: categoryColor(cat['name'].toString()),
              ),
              title: cat['name'].toString(),
              trailing: cat['id'] == _selectedCategoryId ? _checkIcon : null,
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedCategoryId = cat['id'] as int);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFundSourceSection(InputTransactionState state) {
    final Widget sourceRow;
    if (_isFromSaving) {
      final selected = state.savingNamesList.contains(_selectedSavingName) ? _selectedSavingName : null;
      sourceRow = AppListRow(
        leading: const AppIconTile(icon: PhosphorIconsFill.piggyBank, color: AppColors.primary),
        title: "Tabungan",
        value: selected ?? (state.savingNamesList.isEmpty ? "Belum ada tabungan" : "Pilih Tabungan..."),
        showChevron: state.savingNamesList.isNotEmpty,
        onTap: state.savingNamesList.isEmpty ? null : () => _showSavingPicker(state),
      );
    } else {
      final selected = state.wallets.where((w) => w['id'] == _selectedWalletId).firstOrNull;
      sourceRow = AppListRow(
        leading: AppIconTile(
          icon: PhosphorIconsFill.wallet,
          color: selected != null ? _walletColor(selected) : AppColors.tintGray,
          filled: true,
        ),
        title: "Dompet",
        value: selected != null
            ? selected['name'].toString()
            : (state.wallets.isEmpty ? "Buat dompet di menu utama!" : "Pilih Dompet..."),
        showChevron: state.wallets.isNotEmpty,
        onTap: state.wallets.isEmpty ? null : () => _showWalletPicker(state.wallets),
      );
    }

    return AppGroupedSection(
      header: _isExpense ? "Sumber Dana" : "Simpan Ke",
      children: [
        if (_isExpense)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: AppSegmentedControl(
              labels: const ['Dompet', 'Tabungan'],
              selectedIndex: _isFromSaving ? 1 : 0,
              onChanged: (i) => i == 0 ? _useWallet(state) : _useSaving(state),
            ),
          ),
        sourceRow,
      ],
    );
  }

  Widget _buildEditWalletNote(InputTransactionState state) {
    String wName = "Memuat...";
    if (state.wallets.isNotEmpty) {
      final w = state.wallets.firstWhere((e) => e['id'] == _selectedWalletId, orElse: () => {});
      wName = w.isNotEmpty ? w['name'] : "Telah Dihapus";
    }
    return AppCallout(
      icon: PhosphorIconsFill.wallet,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: "Transaksi ini tercatat di dompet "),
            TextSpan(text: wName, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inputTransactionProvider);

    ref.listen<InputTransactionState>(inputTransactionProvider, (previous, next) {
      final walletsJustArrived =
          (previous == null || previous.wallets.isEmpty) && next.wallets.isNotEmpty;
      if (walletsJustArrived && _selectedWalletId == null && !_isFromSaving) {
        setState(() => _selectedWalletId = next.wallets.first['id']);
      }

      final categoriesJustArrived =
          (previous == null || previous.categories.isEmpty) &&
          next.categories.isNotEmpty;
      if (categoriesJustArrived &&
          widget.transactionToEdit != null &&
          _selectedCategoryId != null) {
        final selectedCat = next.categories.firstWhere(
          (e) => e['id'] == _selectedCategoryId,
          orElse: () => {},
        );
        if (selectedCat.isNotEmpty) {
          setState(() => _isExpense = selectedCat['is_expense']);
        }
      }
    });

    final filteredCategories = state.categories.where((c) => c['is_expense'] == _isExpense).toList();
    final selectedCategory = filteredCategories.where((c) => c['id'] == _selectedCategoryId).firstOrNull;
    final isNewTransaction = !_isReadOnly && widget.transactionToEdit == null;

    return AppPageScaffold(
      title: _isReadOnly
          ? "Detail Transaksi"
          : (widget.transactionToEdit == null ? "Tambah Transaksi" : "Edit Transaksi"),
      largeTitle: false,
      leading: AppNavAction.text('Batal', onPressed: () => Navigator.pop(context)),
      bottomBar: AppPrimaryButton(
        label: _isReadOnly ? "Kembali" : "Simpan Transaksi",
        color: _isReadOnly ? AppColors.textSecondary : null,
        loading: state.isSaving,
        onPressed: _isReadOnly
            ? () => Navigator.pop(context)
            : (state.isSaving ? null : _saveTransaction),
      ),
      children: [
        if (_isReadOnly)
          AppCallout(
            icon: PhosphorIconsFill.info,
            child: Text(
              // B2: transaksi [DEBT_ID:] dikelola dari halaman Utang & Piutang.
              _readOnlyFromDebt
                  ? "Ini adalah catatan otomatis dari fitur Utang & Piutang. Silakan gunakan menu Utang & Piutang di Beranda untuk mengedit/menghapus data ini."
                  : "Ini adalah catatan otomatis dari fitur Tabungan. Silakan gunakan Menu Tabungan di Beranda untuk mengedit/menghapus data ini.",
            ),
          ),
        AppSegmentedControl(
          labels: const ['Pemasukan', 'Pengeluaran'],
          selectedIndex: _isExpense ? 1 : 0,
          selectedLabelColors: const [AppColors.income, AppColors.expense],
          onChanged: (i) => _onTypeSelected(i == 1),
        ),
        if (_isReadOnly)
          AppAmountDisplay(label: "Nominal", amountText: "Rp ${_amountController.text}")
        else
          AppAmountField(controller: _amountController, label: "Nominal"),
        if (_isExpense && !_isReadOnly)
          Center(
            child: AppPillButton(
              label: "Scan Struk AI",
              icon: PhosphorIconsFill.sparkle,
              onPressed: _showImageSourceBottomSheet,
            ),
          ),
        if (isNewTransaction) _buildFundSourceSection(state),
        if (widget.transactionToEdit != null && _selectedWalletId != null) _buildEditWalletNote(state),
        AppGroupedSection(
          children: [
            AppListRow(
              leading: AppIconTile(
                icon: selectedCategory != null
                    ? categoryIcon(selectedCategory['name'].toString())
                    : PhosphorIconsFill.tag,
                color: selectedCategory != null
                    ? categoryColor(selectedCategory['name'].toString())
                    : AppColors.tintOrange,
              ),
              title: "Kategori",
              value: selectedCategory != null
                  ? selectedCategory['name'].toString()
                  : (state.categories.isEmpty ? "Memuat..." : "Pilih Kategori"),
              showChevron: !_isReadOnly,
              onTap: (_isReadOnly || filteredCategories.isEmpty)
                  ? null
                  : () => _showCategoryPicker(filteredCategories),
            ),
            AppListRow(
              leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.tintRed),
              title: "Tanggal",
              value: DateFormat('EEE, d MMM yyyy', 'id_ID').format(_selectedDate),
              showChevron: !_isReadOnly,
              onTap: _isReadOnly ? null : _pickDate,
            ),
          ],
        ),
        AppGroupedSection(
          header: "Catatan (Opsional)",
          children: [
            AppTextField(
              controller: _noteController,
              hint: "Contoh: Beli Nasi Padang / Bayar Bengkel",
              readOnly: _isReadOnly,
            ),
          ],
        ),
      ],
    );
  }

}
