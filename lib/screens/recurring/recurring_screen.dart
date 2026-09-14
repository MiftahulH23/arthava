import 'package:flutter/services.dart';
import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/recurring_transaction_model.dart';
import 'package:catat_uang_app/providers/recurring_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  Future<void> _toggleActive(RecurringTransactionModel item, bool value) async {
    try {
      await ref.read(recurringProvider.notifier).toggleActive(item, value);
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal mengubah status");
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await ref.read(recurringProvider.notifier).deleteItem(id);
      if (mounted) AppNotification.success(context, "Jadwal otomatis dihapus");
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data");
    }
  }

  // [UX UPGRADE] Ubah Dialog jadi Bottom Sheet Modern
  void _showAddEditSheet({RecurringTransactionModel? item}) {
    final isEdit = item != null;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    final wallets = ref.read(recurringProvider).wallets;
    bool isExpense = isEdit ? (item.category?['is_expense'] ?? true) : true;
    int? selectedCatId = isEdit ? item.categoryId : null;
    int? selectedWalletId = isEdit ? item.walletId : (wallets.isNotEmpty ? wallets.first['id'] as int : null);
    String selectedFreq = isEdit ? item.frequency : 'Bulanan';
    DateTime selectedDate = isEdit ? item.startDate : DateTime.now();

    final amountController = TextEditingController(text: isEdit ? currencyFormat.format(item.amount) : '');
    final noteController = TextEditingController(text: isEdit ? item.note ?? '' : '');
    final frequencies = ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'];

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categories = ref.read(recurringProvider).categories;
            final wallets = ref.read(recurringProvider).wallets;
            final filteredCats = categories
                .where((c) => c['is_expense'] == isExpense)
                .toList();

            return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? "Edit Jadwal Tagihan" : "Buat Jadwal Tagihan",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOGGLE JENIS TRANSAKSI
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() {
                                        isExpense = false;
                                        selectedCatId = null;
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: !isExpense
                                              ? AppColors.income
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: !isExpense
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.income
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Pemasukan",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: !isExpense
                                                ? Colors.white
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setSheetState(() {
                                        isExpense = true;
                                        selectedCatId = null;
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isExpense
                                              ? AppColors.expense
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: isExpense
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.expense
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "Pengeluaran",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: isExpense
                                                ? Colors.white
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // DOMPET (WALLET)
                            Text(
                              isExpense
                                  ? "Potong Dari Dompet Mana?"
                                  : "Masuk Ke Dompet Mana?",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: selectedWalletId,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  hint: Text(
                                    wallets.isEmpty
                                        ? "Belum ada dompet"
                                        : "Pilih Dompet",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  icon: const Icon(
                                    PhosphorIconsRegular.caretDown,
                                    color: Colors.grey,
                                  ),
                                  items: wallets.map((w) {
                                    return DropdownMenuItem<int>(
                                      value: w['id'] as int,
                                      child: Text(
                                        "${w['name']}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setSheetState(
                                    () => selectedWalletId = val,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            // KATEGORI
                            Text(
                              "Kategori",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value:
                                      filteredCats.any(
                                        (c) => c['id'] == selectedCatId,
                                      )
                                      ? selectedCatId
                                      : null,
                                  hint: Text(
                                    "Pilih Kategori",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  items: filteredCats.map((cat) {
                                    return DropdownMenuItem<int>(
                                      value: cat['id'] as int,
                                      child: Text(
                                        cat['name'],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setSheetState(() => selectedCatId = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            // NOMINAL
                            Text(
                              "Nominal",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isExpense
                                    ? AppColors.expense
                                    : AppColors.income,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 15,
                                    right: 10,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Rp",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              onChanged: (s) {
                                s = s.replaceAll(RegExp(r'[^0-9]'), '');
                                if (s.isNotEmpty) {
                                  amountController.value = TextEditingValue(
                                    text: currencyFormat.format(int.parse(s)),
                                    selection: TextSelection.collapsed(
                                      offset: currencyFormat
                                          .format(int.parse(s))
                                          .length,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 15),

                            // FREKUENSI
                            Text(
                              "Diulang Setiap",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedFreq,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  items: frequencies
                                      .map(
                                        (f) => DropdownMenuItem(
                                          value: f,
                                          child: Text(
                                            f,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setSheetState(() => selectedFreq = val!),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            // TANGGAL MULAI
                            Text(
                              "Mulai Tanggal (Jatuh Tempo Pertama)",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppColors.primary,
                                        surface: Colors.white,
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null)
                                  setSheetState(() => selectedDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      PhosphorIconsRegular.calendarBlank,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      DateFormat(
                                        'dd MMMM yyyy',
                                        'id_ID',
                                      ).format(selectedDate),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            // CATATAN
                            Text(
                              "Catatan (Cth: Bayar Kos / Tagihan WiFi)",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: noteController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Tulis catatan...",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),

                    // TOMBOL SIMPAN
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (amountController.text.isEmpty ||
                              selectedCatId == null ||
                              selectedWalletId == null) {
                            AppNotification.error(
                              context,
                              "Nominal, Kategori, dan Dompet wajib diisi!",
                            );
                            return;
                          }

                          double amount = double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );
                          final userId =
                              Supabase.instance.client.auth.currentUser!.id;
                          final dateStr = DateFormat(
                            'yyyy-MM-dd',
                          ).format(selectedDate);
                          try {
                            final data = {
                              'user_id': userId,
                              'category_id': selectedCatId,
                              'wallet_id': selectedWalletId,
                              'amount': amount,
                              'note': noteController.text.trim(),
                              'frequency': selectedFreq,
                              'start_date': dateStr,
                              'next_run_date': isEdit ? item.nextRunDate.toIso8601String() : dateStr,
                            };

                            if (isEdit) {
                              await ref
                                  .read(recurringProvider.notifier)
                                  .updateRecurring(item.id, data);
                            } else {
                              await ref
                                  .read(recurringProvider.notifier)
                                  .addRecurring(data);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.success(
                                context,
                                isEdit ? "Jadwal diperbarui!" : "Jadwal berhasil dibuat!",
                              );
                            }
                          } catch (e) {
                            if (context.mounted)
                              AppNotification.error(
                                context,
                                "Gagal menyimpan jadwal",
                              );
                          }
                        },
                        child: Text(
                          isEdit ? "Perbarui Jadwal" : "Simpan Jadwal",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final recurringState = ref.watch(recurringProvider);
    final isLoading = recurringState.isLoading;
    final recurringList = recurringState.recurringList;
    final walletNames = recurringState.walletNames;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Tagihan & Pemasukan Rutin",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : recurringList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsFill.calendarPlus,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Belum ada jadwal otomatis",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: recurringList.length,
              itemBuilder: (context, index) {
                final item = recurringList[index];
                final isExpense = item.category?['is_expense'] ?? true;
                final catName = item.category?['name'] ?? 'Umum';
                final color = isExpense ? AppColors.expense : AppColors.income;

                // [NEW] Tampilkan Nama Dompet
                final walletName =
                    walletNames[item.walletId] ?? 'Dompet Dihapus';

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.isActive
                          ? color.withOpacity(0.2)
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? color.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isExpense
                                  ? PhosphorIcons.arrowUp()
                                  : PhosphorIcons.arrowDown(),
                              color: item.isActive ? color : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  catName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: item.isActive
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.note != null && item.note!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item.note!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Per ${item.frequency}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    // [NEW] Badge Dompet
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            PhosphorIconsFill.wallet,
                                            size: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              walletName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currency.format(item.amount),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: item.isActive ? color : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 24,
                                child: Switch(
                                  value: item.isActive,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) => _toggleActive(item, val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.clock,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "Lanjut: ",
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        TextSpan(
                                          text: DateFormat(
                                            'dd MMM yyyy',
                                            'id_ID',
                                          ).format(item.nextRunDate),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: item.isActive
                                                ? Colors.black87
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showAddEditSheet(item: item),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsRegular.pencilSimple,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: Text(
                                        "Hapus Jadwal?",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        "Jadwal otomatis ini akan dihentikan dan dihapus dari daftar.",
                                        style: GoogleFonts.poppins(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text(
                                            "Batal",
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteItem(item.id);
                                          },
                                          child: Text(
                                            "Hapus",
                                            style: GoogleFonts.poppins(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: AppColors.primary,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Buat Jadwal",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
