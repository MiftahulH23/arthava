import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/screens/saving_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, List<SavingModel>> _groupedSavings = {};
  double _totalSavings = 0;

  @override
  void initState() {
    super.initState();
    _fetchSavings();
  }

  Future<void> _fetchSavings() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('savings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      double total = 0;
      Map<String, List<SavingModel>> tempGrouped = {};

      for (var item in res) {
        final saving = SavingModel.fromJson(item);
        total += saving.amount;

        String groupName = saving.name.trim();
        String groupKey = groupName.toLowerCase();

        String existingKey = tempGrouped.keys.firstWhere(
          (k) => k.toLowerCase() == groupKey,
          orElse: () => groupName,
        );

        if (!tempGrouped.containsKey(existingKey)) {
          tempGrouped[existingKey] = [];
        }
        tempGrouped[existingKey]!.add(saving);
      }

      if (mounted) {
        setState(() {
          _groupedSavings = tempGrouped;
          _totalSavings = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _getOrCreateSavingCategory() async {
    final userId = _supabase.auth.currentUser!.id;
    final checkRes = await _supabase
        .from('categories')
        .select('id')
        .eq('is_expense', true)
        .ilike('name', '%Tabung%')
        .eq('user_id', userId)
        .maybeSingle();
    if (checkRes != null) return checkRes['id'] as int;
    final insertRes = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': 'Tabungan',
          'is_expense': true,
          'icon_name': 'bank',
        })
        .select('id')
        .single();
    return insertRes['id'] as int;
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

  void _showFormDialog() {
    bool isDeposit = true;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final locationController =
        TextEditingController(); // [FIX] Controller dikembalikan
    final notesController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Catat Tabungan",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                onTap: () =>
                                    setDialogState(() => isDeposit = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDeposit
                                        ? AppColors.expense
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Setor (Nabung)",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: isDeposit
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setDialogState(() => isDeposit = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !isDeposit
                                        ? AppColors.income
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Tarik (Ambil)",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: !isDeposit
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

                      Text(
                        isDeposit
                            ? "Nama Tujuan Tabungan"
                            : "Tarik Dari Tabungan Apa?",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        style: GoogleFonts.poppins(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Contoh: Dana Darurat",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ), // [FIX] Hint warna abu
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            PhosphorIconsFill.target,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Nominal ${isDeposit ? 'Disetor' : 'Ditarik'}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: isDeposit ? Colors.black : AppColors.income,
                        ),
                        decoration: InputDecoration(
                          hintText: "0",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Text(
                              "Rp",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
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

                      // [FIX] MENGEMBALIKAN INPUT TEMPAT SIMPAN
                      Text(
                        "Tempat Simpan (Opsional)",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        style: GoogleFonts.poppins(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Contoh: Bank BCA / Celengan",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            PhosphorIconsFill.bank,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Catatan (Opsional)",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        minLines: 1,
                        style: GoogleFonts.poppins(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: isDeposit
                              ? "Biar cepat kaya"
                              : "Buat benerin motor",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ), // [FIX] Hint abu-abu
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            PhosphorIconsFill.notePencil,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDeposit
                          ? AppColors.primary
                          : AppColors.income,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          amountController.text.isEmpty)
                        return;

                      double rawAmount = double.parse(
                        amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      );
                      final savingName = nameController.text.trim();

                      if (!isDeposit) {
                        double currentBalance = 0;
                        String groupKey = savingName.toLowerCase();
                        String? existingKey;
                        try {
                          existingKey = _groupedSavings.keys.firstWhere(
                            (k) => k.toLowerCase() == groupKey,
                          );
                        } catch (e) {
                          existingKey = null;
                        }

                        if (existingKey == null) {
                          AppNotification.error(
                            context,
                            "Tabungan '$savingName' belum pernah ada!",
                          );
                          return;
                        }

                        if (existingKey != null) {
                          for (var item in _groupedSavings[existingKey]!)
                            currentBalance += item.amount;
                        }

                        if (rawAmount > currentBalance) {
                          final limitRp = NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(currentBalance);
                          AppNotification.error(
                            context,
                            "Saldo tidak cukup! Maksimal sisa saldo: $limitRp",
                          );
                          return;
                        }
                      }

                      final finalAmount = isDeposit ? rawAmount : -rawAmount;
                      final userId = _supabase.auth.currentUser!.id;

                      try {
                        final catId = isDeposit
                            ? await _getOrCreateSavingCategory()
                            : await _getOrCreateWithdrawCategory();

                        final insertedData = await _supabase
                            .from('savings')
                            .insert({
                              'user_id': userId,
                              'name': savingName,
                              'amount': finalAmount,
                              'location': locationController.text
                                  .trim(), // [FIX] Location disimpan
                              'notes': notesController.text.trim(),
                            })
                            .select('id')
                            .single();

                        final newSavingId = insertedData['id'];
                        final noteMarker = "[SAVING_ID:$newSavingId]";
                        final autoNote = isDeposit
                            ? "Menabung ke $savingName $noteMarker"
                            : "Pencairan $savingName $noteMarker";

                        await _supabase.from('transactions').insert({
                          'user_id': userId,
                          'category_id': catId,
                          'amount': rawAmount,
                          'date': DateFormat(
                            'yyyy-MM-dd',
                          ).format(DateTime.now()),
                          'note': autoNote,
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          _fetchSavings();
                          if (isDeposit) {
                            AppNotification.success(
                              context,
                              "Tabungan ditambah! Saldo kas dipotong.",
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: Row(
                                  children: [
                                    const Icon(
                                      PhosphorIconsFill.checkCircle,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Berhasil Dicairkan!",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  "Uang telah dikembalikan ke Saldo Utama Anda.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Oke, Paham"),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted)
                          AppNotification.error(
                            context,
                            "Gagal menyimpan data.",
                          );
                      }
                    },
                    child: Text(
                      isDeposit ? "Simpan Setoran" : "Cairkan Dana",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Buku Tabungan",
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Semua Aset",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(_totalSavings),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF009688),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009688).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsFill.piggyBank,
                    color: Color(0xFF009688),
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedSavings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsFill.vault,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Belum ada tabungan",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _groupedSavings.length,
                    itemBuilder: (context, index) {
                      String groupName = _groupedSavings.keys.elementAt(index);
                      List<SavingModel> groupItems =
                          _groupedSavings[groupName]!;
                      double groupTotal = groupItems.fold(
                        0,
                        (sum, item) => sum + item.amount,
                      );

                      return GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SavingDetailScreen(savingName: groupName),
                            ),
                          );
                          if (result == true) _fetchSavings();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF009688,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.wallet,
                                  color: Color(0xFF009688),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      groupName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${groupItems.length} Transaksi",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(groupTotal),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF009688),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'savings_fab',
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF009688),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
