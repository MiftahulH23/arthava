import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/core/formatters.dart';
import 'package:catat_uang_app/core/wallet_rules.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/providers/input_transaction_provider.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:catat_uang_app/widgets/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    final result = await GeminiService.scanReceipts(images);
    if (mounted) Navigator.pop(context);

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

  void _showImageSourceBottomSheet() {
    showAppBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 200,
        child: Column(
          children: [
            Text(
              "Pilih Metode Scan",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (image != null) _processScanReceipts([image]);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Kamera",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "(1 Struk)",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    final images = await _picker.pickMultiImage(
                      imageQuality: 80,
                    );
                    if (images.isNotEmpty) _processScanReceipts(images);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: Colors.purple,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Galeri",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "(Banyak Struk)",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('makan'))
      return PhosphorIcons.bowlFood(PhosphorIconsStyle.fill);
    if (name.contains('minum') ||
        name.contains('kopi') ||
        name.contains('cafe'))
      return PhosphorIcons.coffee(PhosphorIconsStyle.fill);
    if (name.contains('transport') || name.contains('bensin'))
      return PhosphorIcons.bus(PhosphorIconsStyle.fill);
    if (name.contains('belanja') || name.contains('mart'))
      return PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill);
    if (name.contains('hiburan') || name.contains('nonton'))
      return PhosphorIcons.gameController(PhosphorIconsStyle.fill);
    if (name.contains('kesehatan') || name.contains('obat'))
      return PhosphorIcons.firstAid(PhosphorIconsStyle.fill);
    if (name.contains('tagihan') || name.contains('listrik'))
      return PhosphorIcons.lightning(PhosphorIconsStyle.fill);
    if (name.contains('gaji'))
      return PhosphorIcons.money(PhosphorIconsStyle.fill);
    if (name.contains('bonus'))
      return PhosphorIcons.gift(PhosphorIconsStyle.fill);
    if (name.contains('tabung'))
      return PhosphorIcons.bank(PhosphorIconsStyle.fill);
    return PhosphorIcons.tag(PhosphorIconsStyle.fill);
  }

  Future<void> _saveTransaction() async {
    // Peringatan saldo minimal (spec §7.3): hanya pengeluaran baru dari dompet.
    if (_isExpense && !_isFromSaving && widget.transactionToEdit == null && _selectedWalletId != null) {
      Map<String, dynamic>? wallet;
      for (final w in ref.read(inputTransactionProvider).wallets) {
        if (w['id'] == _selectedWalletId) {
          wallet = w;
          break;
        }
      }
      if (wallet != null) {
        final warning = minBalanceWarningMessage(
          walletName: wallet['name'].toString(),
          balance: (wallet['balance'] as num).toDouble(),
          minBalance: (wallet['min_balance'] as num?)?.toDouble() ?? 0,
          amount: parseRupiah(_amountController.text).toDouble(),
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

  Future<void> _pickDate() async {
    if (_isReadOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inputTransactionProvider);

    // Sama seperti efek samping di dalam `setState` pada `_fetchWallets` dan
    // `_fetchCategories` aslinya: begitu daftar dompet/kategori pertama kali
    // terisi, isi field lokal yang belum dipilih pengguna.
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

    final filteredCategories = state.categories
        .where((c) => c['is_expense'] == _isExpense)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isReadOnly
              ? "Detail Transaksi"
              : (widget.transactionToEdit == null
                    ? "Tambah Transaksi"
                    : "Edit Transaksi"),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isReadOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.info, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _readOnlyFromDebt
                            ? "Ini adalah catatan otomatis dari fitur Utang & Piutang. Silakan gunakan menu Utang & Piutang di Beranda untuk mengedit/menghapus data ini."
                            : "Ini adalah catatan otomatis dari fitur Tabungan. Silakan gunakan Menu Tabungan di Beranda untuk mengedit/menghapus data ini.",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _buildToggleBtn("Pemasukan", false),
                  _buildToggleBtn("Pengeluaran", true),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // ==========================================
            // [UI/UX UPDATE] OPSI SUMBER DANA
            if (!_isReadOnly && widget.transactionToEdit == null) ...[
              // [UX FIX] Teks dinamis sesuai tipe transaksi
              Text(
                _isExpense ? "Sumber Dana" : "Simpan Ke",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),

              if (_isExpense)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isFromSaving = false;
                            _selectedSavingName = null;
                            if (state.wallets.isNotEmpty)
                              _selectedWalletId = state.wallets.first['id'];
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isFromSaving
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !_isFromSaving
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                      ),
                                    ]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PhosphorIconsFill.wallet,
                                  size: 16,
                                  color: !_isFromSaving
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Dompet",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: !_isFromSaving
                                        ? AppColors.primary
                                        : Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isFromSaving = true;
                            _selectedWalletId = null;
                            if (state.savingNamesList.isNotEmpty &&
                                _selectedSavingName == null)
                              _selectedSavingName = state.savingNamesList.first;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isFromSaving
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _isFromSaving
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                      ),
                                    ]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  PhosphorIconsFill.piggyBank,
                                  size: 16,
                                  color: _isFromSaving
                                      ? Colors.teal
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Tabungan",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: _isFromSaving
                                        ? Colors.teal
                                        : Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // DROPDOWN ESTETIK (SAMA KAYAK KATEGORI)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: _isFromSaving
                      ? DropdownButton<String>(
                          dropdownColor: Colors.white,
                          value: state.savingNamesList.contains(_selectedSavingName)
                              ? _selectedSavingName
                              : null,
                          hint: Text(
                            state.savingNamesList.isEmpty
                                ? "Belum ada tabungan"
                                : "Pilih Tabungan...",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          items: state.savingNamesList.map((savingName) {
                            final balance = state.savingsBalances[savingName] ?? 0;
                            return DropdownMenuItem<String>(
                              value: savingName,
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsFill.piggyBank,
                                    color: Colors.teal,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "$savingName (Sisa: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(balance)})",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: state.savingNamesList.isEmpty
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedSavingName = val;
                                  });
                                },
                        )
                      : DropdownButton<int>(
                          dropdownColor: Colors.white,
                          value:
                              state.wallets.any((w) => w['id'] == _selectedWalletId)
                              ? _selectedWalletId
                              : null,
                          hint: Text(
                            state.wallets.isEmpty
                                ? "Buat dompet di menu utama!"
                                : "Pilih Dompet...",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          items: state.wallets.map((wallet) {
                            final colorHex = wallet['color'] ?? '#1E3A8A';
                            final walletColor = Color(
                              int.parse(colorHex.replaceFirst('#', '0xFF')),
                            );
                            return DropdownMenuItem<int>(
                              value: wallet['id'] as int,
                              child: Row(
                                children: [
                                  Icon(
                                    PhosphorIconsFill.wallet,
                                    color: walletColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "${wallet['name']} (${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(wallet['balance'])})",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: state.wallets.isEmpty
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedWalletId = val;
                                  });
                                },
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // [UX FIX] JIKA MODE EDIT TAMPILKAN NAMA DOMPET REAL-TIME
            if (widget.transactionToEdit != null &&
                _selectedWalletId != null) ...[
              Builder(
                builder: (context) {
                  String wName = "Memuat...";
                  if (state.wallets.isNotEmpty) {
                    final w = state.wallets.firstWhere(
                      (e) => e['id'] == _selectedWalletId,
                      orElse: () => {},
                    );
                    wName = w.isNotEmpty ? w['name'] : "Telah Dihapus";
                  }
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsFill.wallet,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              children: [
                                const TextSpan(
                                  text: "Transaksi ini tercatat di dompet ",
                                ),
                                TextSpan(
                                  text: wName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Nominal",
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                ),
                if (_isExpense && !_isReadOnly)
                  GestureDetector(
                    onTap: _showImageSourceBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.magicWand,
                            color: Colors.purple,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Scan Struk AI",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              enabled: !_isReadOnly,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: 5, top: 2),
                  child: Text(
                    "Rp",
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                hintText: "0",
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade300),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              onChanged: (string) {
                string = string.replaceAll(RegExp(r'[^0-9]'), '');
                if (string.isNotEmpty) {
                  final formatted = _currencyFormat.format(int.parse(string));
                  if (_amountController.text != formatted)
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                }
              },
            ),
            const SizedBox(height: 30),

            Text(
              "Kategori",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(15),
                color: _isReadOnly ? Colors.grey.shade100 : Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  dropdownColor: Colors.white,
                  value:
                      filteredCategories.any(
                        (cat) => cat['id'] == _selectedCategoryId,
                      )
                      ? _selectedCategoryId
                      : null,
                  hint: Text(
                    state.categories.isEmpty ? "Memuat..." : "Pilih Kategori",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  items: filteredCategories.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'] as int,
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(cat['name']),
                            color: _isExpense
                                ? AppColors.expense
                                : AppColors.income,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cat['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isReadOnly
                      ? null
                      : (val) {
                          setState(() => _selectedCategoryId = val);
                        },
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              "Tanggal",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(15),
                  color: _isReadOnly ? Colors.grey.shade100 : Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsFill.calendarBlank,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat(
                        'EEEE, d MMMM yyyy',
                        'id_ID',
                      ).format(_selectedDate),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              "Catatan (Opsional)",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              enabled: !_isReadOnly,
              maxLines: 1,
              style: GoogleFonts.poppins(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: _isReadOnly ? Colors.grey.shade100 : Colors.white,
                hintText: "Contoh: Beli Nasi Padang / Bayar Bengkel",
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.white)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isReadOnly
                ? () => Navigator.pop(context)
                : (state.isSaving ? null : _saveTransaction),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isReadOnly
                  ? Colors.grey.shade300
                  : AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: state.isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    _isReadOnly ? "Kembali" : "Simpan Transaksi",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isReadOnly ? Colors.black87 : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String title, bool isExpenseBtn) {
    final bool isSelected = _isExpense == isExpenseBtn;
    return Expanded(
      child: GestureDetector(
        onTap: _isReadOnly
            ? null
            : () {
                final wallets = ref.read(inputTransactionProvider).wallets;
                setState(() {
                  _isExpense = isExpenseBtn;
                  _selectedCategoryId = null;
                  if (!isExpenseBtn) {
                    _isFromSaving = false;
                    _selectedSavingName = null;
                    if (wallets.isNotEmpty)
                      _selectedWalletId = wallets.first['id'];
                  }
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isExpenseBtn ? AppColors.expense : AppColors.income)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
