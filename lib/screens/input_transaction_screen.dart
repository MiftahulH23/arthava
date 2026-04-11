import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class InputTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  final bool initialIsExpense;

  const InputTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.initialIsExpense = false,
  });

  @override
  State<InputTransactionScreen> createState() => _InputTransactionScreenState();
}

class _InputTransactionScreenState extends State<InputTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];
  late bool _isExpense;

  int? _tabunganCategoryId;
  bool _isReadOnly = false;
  String? _hiddenSavingMarker;

  List<Map<String, dynamic>> _wallets = [];
  int? _selectedWalletId;

  Map<String, double> _savingsBalances = {};
  List<String> _savingNamesList = [];
  bool _isFromSaving = false;
  String? _selectedSavingName;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.initialIsExpense;
    _fetchCategories();
    _fetchSavingsBalances();
    _fetchWallets();

    if (widget.transactionToEdit != null) {
      final trx = widget.transactionToEdit!;
      _amountController.text = _currencyFormat.format(trx.amount);

      String rawNote = trx.note ?? '';
      final match = RegExp(r'\s*\[SAVING_ID:\d+\]').firstMatch(rawNote);
      if (match != null) {
        _hiddenSavingMarker = match.group(0);
        _noteController.text = rawNote.replaceAll(match.group(0)!, '');
        _isReadOnly = true;
      } else {
        _noteController.text = rawNote;
      }

      _selectedDate = trx.date;
      _selectedCategoryId = trx.categoryId;
      _selectedWalletId = trx.walletId;
    }
  }

  Future<void> _fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('name');

      if (mounted) {
        setState(() {
          _wallets = List<Map<String, dynamic>>.from(res);
          if (_wallets.isNotEmpty &&
              _selectedWalletId == null &&
              !_isFromSaving) {
            _selectedWalletId = _wallets.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetch wallets: $e");
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
        var matchedCat = _categories.where((c) {
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  Future<void> _fetchSavingsBalances() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('savings')
          .select('name, amount')
          .eq('user_id', userId);
      Map<String, double> balances = {};
      for (var item in res) {
        String name = item['name'].toString().trim();
        balances[name] =
            (balances[name] ?? 0) + (item['amount'] as num).toDouble();
      }
      if (mounted) {
        setState(() {
          _savingsBalances = balances;
          for (var key in balances.keys) {
            if (balances[key]! > 0) _savingNamesList.add(key);
          }
        });
      }
    } catch (e) {}
  }

  Future<int> _getOrCreateWithdrawCategory() async {
    final userId = _supabase.auth.currentUser!.id;
    final checkRes = await _supabase
        .from('categories')
        .select('id')
        .eq('is_expense', false)
        .ilike('name', '%Cair%')
        .eq('user_id', userId)
        .maybeSingle();
    if (checkRes != null) return checkRes['id'] as int;
    final insertRes = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': 'Pencairan Tabungan',
          'is_expense': false,
          'icon_name': 'bank',
        })
        .select('id')
        .single();
    return insertRes['id'] as int;
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

  Future<void> _fetchCategories() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('categories')
          .select()
          .or('user_id.eq.$userId,user_id.is.null');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          try {
            final tabungCat = _categories.firstWhere(
              (c) => c['name'].toString().toLowerCase().contains('tabung'),
            );
            _tabunganCategoryId = tabungCat['id'];
          } catch (e) {
            _tabunganCategoryId = null;
          }

          if (widget.transactionToEdit != null && _selectedCategoryId != null) {
            final selectedCat = _categories.firstWhere(
              (e) => e['id'] == _selectedCategoryId,
              orElse: () => {},
            );
            if (selectedCat.isNotEmpty) _isExpense = selectedCat['is_expense'];
          }
        });
      }
    } catch (e) {}
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
      AppNotification.error(context, "Jumlah dan Kategori wajib diisi!");
      return;
    }
    if (_wallets.isEmpty && !_isFromSaving) {
      AppNotification.error(
        context,
        "Kamu belum membuat dompet. Silakan buat di Beranda > Dompet.",
      );
      return;
    }
    if (!_isFromSaving && _selectedWalletId == null) {
      AppNotification.error(context, "Pilih dompet sumber dana!");
      return;
    }
    if (_isExpense &&
        _isFromSaving &&
        _selectedSavingName == null &&
        widget.transactionToEdit == null) {
      AppNotification.error(context, "Pilih tabungan yang ingin digunakan!");
      return;
    }
    if (_selectedCategoryId == _tabunganCategoryId && !_isReadOnly) {
      AppNotification.error(
        context,
        "Untuk nabung, silakan gunakan menu Tabungan di Beranda.",
      );
      return;
    }

    final cleanAmount = _amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final amount = int.parse(cleanAmount);
    final userId = _supabase.auth.currentUser!.id;

    if (_isExpense && _isFromSaving && widget.transactionToEdit == null) {
      double currentBal = _savingsBalances[_selectedSavingName] ?? 0;
      if (amount > currentBal) {
        final limitRp = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(currentBal);
        AppNotification.error(
          context,
          "Saldo tabungan tidak cukup! Sisa: $limitRp",
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        final insertedSaving = await _supabase
            .from('savings')
            .insert({
              'user_id': userId,
              'name': _selectedSavingName,
              'amount': -amount,
              'notes': _noteController.text.trim().isNotEmpty
                  ? _noteController.text.trim()
                  : 'Dipakai untuk pengeluaran',
            })
            .select('id')
            .single();

        final savingId = insertedSaving['id'];
        final noteMarker = "[SAVING_ID:$savingId]";
        final incomeCatId = await _getOrCreateWithdrawCategory();

        await _supabase.from('transactions').insert({
          'user_id': userId,
          'category_id': incomeCatId,
          'amount': amount,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'note': 'Pencairan otomatis $noteMarker',
        });

        String finalNote = _noteController.text.trim();
        finalNote = finalNote.isEmpty ? noteMarker : '$finalNote $noteMarker';

        await _supabase.from('transactions').insert({
          'user_id': userId,
          'category_id': _selectedCategoryId,
          'amount': amount,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'note': finalNote,
        });

        if (mounted) {
          AppNotification.success(
            context,
            "Berhasil! Uang dipotong dari tabungan.",
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) AppNotification.error(context, "Gagal memproses data.");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      String finalNote = _noteController.text.trim();
      if (_hiddenSavingMarker != null) {
        finalNote = finalNote.isEmpty
            ? _hiddenSavingMarker!
            : '$finalNote $_hiddenSavingMarker';
      }

      final data = {
        'user_id': userId,
        'category_id': _selectedCategoryId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'note': finalNote,
        'wallet_id': _selectedWalletId,
      };

      double balanceChange = _isExpense
          ? -(amount.toDouble())
          : amount.toDouble();

      if (widget.transactionToEdit == null) {
        await _supabase.from('transactions').insert(data);
        final currentWalletRes = await _supabase
            .from('wallets')
            .select('balance')
            .eq('id', _selectedWalletId!)
            .single();
        final currentBalance = (currentWalletRes['balance'] as num).toDouble();
        await _supabase
            .from('wallets')
            .update({'balance': currentBalance + balanceChange})
            .eq('id', _selectedWalletId!);

        if (mounted) {
          AppNotification.success(
            context,
            "Transaksi berhasil & Saldo dompet terupdate!",
          );
          Navigator.pop(context, true);
        }
      } else {
        final oldTrx = widget.transactionToEdit!;
        final oldWalletRes = await _supabase
            .from('wallets')
            .select('balance')
            .eq('id', oldTrx.walletId!)
            .single();
        final oldBalance = (oldWalletRes['balance'] as num).toDouble();

        double reverseChange = widget.initialIsExpense
            ? oldTrx.amount.toDouble()
            : -(oldTrx.amount.toDouble());
        await _supabase
            .from('wallets')
            .update({'balance': oldBalance + reverseChange})
            .eq('id', oldTrx.walletId!);

        await _supabase.from('transactions').update(data).eq('id', oldTrx.id);

        final newWalletRes = await _supabase
            .from('wallets')
            .select('balance')
            .eq('id', _selectedWalletId!)
            .single();
        final newBalance = (newWalletRes['balance'] as num).toDouble();
        await _supabase
            .from('wallets')
            .update({'balance': newBalance + balanceChange})
            .eq('id', _selectedWalletId!);

        if (mounted) {
          AppNotification.success(context, "Transaksi berhasil diperbarui!");
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final filteredCategories = _categories
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
                        "Ini adalah catatan otomatis dari fitur Tabungan. Silakan gunakan Menu Tabungan di Beranda untuk mengedit/menghapus data ini.",
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
                            if (_wallets.isNotEmpty)
                              _selectedWalletId = _wallets.first['id'];
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
                            if (_savingNamesList.isNotEmpty &&
                                _selectedSavingName == null)
                              _selectedSavingName = _savingNamesList.first;
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
                          value: _savingNamesList.contains(_selectedSavingName)
                              ? _selectedSavingName
                              : null,
                          hint: Text(
                            _savingNamesList.isEmpty
                                ? "Belum ada tabungan"
                                : "Pilih Tabungan...",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          items: _savingNamesList.map((savingName) {
                            final balance = _savingsBalances[savingName] ?? 0;
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
                          onChanged: _savingNamesList.isEmpty
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
                              _wallets.any((w) => w['id'] == _selectedWalletId)
                              ? _selectedWalletId
                              : null,
                          hint: Text(
                            _wallets.isEmpty
                                ? "Buat dompet di menu utama!"
                                : "Pilih Dompet...",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          items: _wallets.map((wallet) {
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
                          onChanged: _wallets.isEmpty
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
                  if (_wallets.isNotEmpty) {
                    final w = _wallets.firstWhere(
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
                    _categories.isEmpty ? "Memuat..." : "Pilih Kategori",
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
                : (_isLoading ? null : _saveTransaction),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isReadOnly
                  ? Colors.grey.shade300
                  : AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
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
                setState(() {
                  _isExpense = isExpenseBtn;
                  _selectedCategoryId = null;
                  if (!isExpenseBtn) {
                    _isFromSaving = false;
                    _selectedSavingName = null;
                    if (_wallets.isNotEmpty)
                      _selectedWalletId = _wallets.first['id'];
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
