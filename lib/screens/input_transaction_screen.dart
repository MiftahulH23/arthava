import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputTransactionScreen extends StatefulWidget {
  final TransactionModel? transactionToEdit;
  // [UPDATE 1] Tambahkan parameter untuk setting default tab
  final bool initialIsExpense;

  const InputTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.initialIsExpense = false, // Default pemasukan jika tidak dikirim
  });

  @override
  State<InputTransactionScreen> createState() => _InputTransactionScreenState();
}

class _InputTransactionScreenState extends State<InputTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  bool _isLoading = false;
  List<Map<String, dynamic>> _categories = [];

  late bool
  _isExpense; // [UPDATE 2] Gunakan "late" agar bisa diisi di initState

  int? _tabunganCategoryId;
  bool _isReadOnly = false;
  String? _hiddenSavingMarker;

  @override
  void initState() {
    super.initState();

    // [UPDATE 3] Set toggle awal berdasarkan darimana dia diklik
    _isExpense = widget.initialIsExpense;

    _fetchCategories();

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
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    // [UPDATE 4] Pisahkan icon Makan dan Minum
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

            if (selectedCat.isNotEmpty) {
              _isExpense = selectedCat['is_expense'];
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error cat: $e");
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
      AppNotification.error(context, "Jumlah dan Kategori wajib diisi!");
      return;
    }

    if (_selectedCategoryId == _tabunganCategoryId && !_isReadOnly) {
      AppNotification.error(
        context,
        "Untuk mencatat tabungan, silakan gunakan menu Tabungan di Beranda.",
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final cleanAmount = _amountController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final amount = int.parse(cleanAmount);

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
      };

      if (widget.transactionToEdit == null) {
        await _supabase.from('transactions').insert(data);
        if (mounted) {
          AppNotification.success(context, "Transaksi berhasil disimpan!");
          Navigator.pop(context, true);
        }
      } else {
        await _supabase
            .from('transactions')
            .update(data)
            .eq('id', widget.transactionToEdit!.id);
        if (mounted) {
          AppNotification.success(context, "Transaksi berhasil diperbarui!");
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) AppNotification.error(context, e.toString());
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
              ? "Detail Tabungan"
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
                        "Ini adalah catatan otomatis dari fitur Tabungan. Silakan gunakan Menu Tabungan di Beranda untuk mengedit data ini.",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. TOGGLE
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

            // 2. NOMINAL
            Text(
              "Nominal",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
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
                  if (_amountController.text != formatted) {
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 30),

            // 3. KATEGORI
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

            // 4. TANGGAL
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

            // 5. CATATAN
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
                hintText: "Contoh: Beli Nasi Padang",
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
