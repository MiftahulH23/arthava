import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/saving_model.dart';
import 'package:catat_uang_app/screens/saving_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<Map<String, dynamic>> _wallets = [];

  @override
  void initState() {
    super.initState();
    _fetchWallets();
    _fetchSavings();
  }

  Future<void> _fetchWallets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('name');
      if (mounted)
        setState(() => _wallets = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint("Error fetch wallets: $e");
    }
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
        if (!tempGrouped.containsKey(existingKey))
          tempGrouped[existingKey] = [];
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA TRANSAKSI ---
  Future<void> _processSavingTransaction({
    required bool isDeposit,
    required String savingName,
    required double amount,
    required int walletId,
    String? location,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final catId = isDeposit
          ? await _getOrCreateCategory('Tabungan', true)
          : await _getOrCreateCategory('Pencairan Tabungan', false);

      final wallet = _wallets.firstWhere((w) => w['id'] == walletId);
      final currentBalance = (wallet['balance'] as num).toDouble();

      if (isDeposit && amount > currentBalance) {
        AppNotification.error(context, "Saldo dompet tidak cukup!");
        return;
      }

      String? savedLoc = location;
      String? savedNote = notes;
      if (savedLoc == null && savedNote == null) {
        if (_groupedSavings[savingName] != null &&
            _groupedSavings[savingName]!.isNotEmpty) {
          savedLoc = _groupedSavings[savingName]!.last.location;
          savedNote = _groupedSavings[savingName]!.last.notes;
        }
      }

      final finalAmount = isDeposit ? amount : -amount;
      final insertedSaving = await _supabase
          .from('savings')
          .insert({
            'user_id': userId,
            'name': savingName,
            'amount': finalAmount,
            'location': savedLoc,
            'notes': savedNote,
          })
          .select('id')
          .single();

      final noteMarker = "[SAVING_ID:${insertedSaving['id']}]";
      await _supabase.from('transactions').insert({
        'user_id': userId,
        'category_id': catId,
        'wallet_id': walletId,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'note':
            (isDeposit
                    ? "Nabung ke $savingName $noteMarker"
                    : "Pencairan $savingName $noteMarker")
                .trim(),
      });

      final newBalance = isDeposit
          ? currentBalance - amount
          : currentBalance + amount;
      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', walletId);

      _fetchWallets();
      _fetchSavings();
      if (mounted)
        AppNotification.success(
          context,
          isDeposit ? "Berhasil Menabung!" : "Berhasil Dicairkan!",
        );
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menyimpan transaksi!");
    }
  }

  Future<int> _getOrCreateCategory(String name, bool isExpense) async {
    final userId = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('categories')
        .select('id')
        .eq('user_id', userId)
        .eq('is_expense', isExpense)
        .ilike('name', '%$name%')
        .maybeSingle();
    if (res != null) return res['id'] as int;
    final ins = await _supabase
        .from('categories')
        .insert({
          'user_id': userId,
          'name': name,
          'is_expense': isExpense,
          'icon_name': 'bank',
        })
        .select('id')
        .single();
    return ins['id'] as int;
  }

  // --- [UX UPGRADE] Form Buat Tabungan Baru ---
  void _showAddTitleSheet() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();

    final amountController = TextEditingController();
    int? selectedWalletId = _wallets.isNotEmpty
        ? _wallets.first['id'] as int
        : null;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                        "Buat Tabungan",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Text(
                    "Nama Tabungan",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: "Contoh: Dana Darurat",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(
                        PhosphorIconsFill.vault,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFF009688)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

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
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: "Contoh: Bank BCA",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(
                        PhosphorIconsFill.bank,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFF009688)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // [FIX] Catatan kembali normal 1 baris
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
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "Tulis catatan singkat...",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(
                        PhosphorIconsFill.notePencil,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFF009688)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  const Divider(),
                  const SizedBox(height: 10),

                  // [FIX] Dompet & Nominal Atas-Bawah (Bukan Sebelahan)
                  Text(
                    "Tarik Dari Dompet Mana?",
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
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedWalletId,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: const Icon(
                          PhosphorIconsRegular.caretDown,
                          color: Colors.grey,
                        ),
                        items: _wallets
                            .map(
                              (w) => DropdownMenuItem(
                                value: w['id'] as int,
                                child: Text(
                                  "${w['name']} (Sisa: ${currencyFormat.format(w['balance'])})",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => selectedWalletId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Text(
                    "Setoran Awal (Opsional)",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: const Color(0xFF009688),
                    ),
                    decoration: InputDecoration(
                      hintText: "0",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.normal,
                        fontSize: 18,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Text(
                          "Rp",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFF009688)),
                      ),
                    ),
                    onChanged: (s) {
                      s = s.replaceAll(RegExp(r'[^0-9]'), '');
                      if (s.isNotEmpty) {
                        amountController.value = TextEditingValue(
                          text: currencyFormat.format(int.parse(s)),
                          selection: TextSelection.collapsed(
                            offset: currencyFormat.format(int.parse(s)).length,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (nameController.text.isEmpty) {
                          AppNotification.error(
                            context,
                            "Nama tabungan tidak boleh kosong!",
                          );
                          return;
                        }

                        double amt = 0;
                        if (amountController.text.isNotEmpty) {
                          amt = double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );
                        }

                        if (amt > 0 && selectedWalletId == null) {
                          AppNotification.error(
                            context,
                            "Pilih dompet untuk setoran awal!",
                          );
                          return;
                        }

                        try {
                          if (amt > 0) {
                            await _processSavingTransaction(
                              isDeposit: true,
                              savingName: nameController.text.trim(),
                              amount: amt,
                              walletId: selectedWalletId!,
                              location: locationController.text.trim(),
                              notes: notesController.text.trim(),
                            );
                          } else {
                            await _supabase.from('savings').insert({
                              'user_id': _supabase.auth.currentUser!.id,
                              'name': nameController.text.trim(),
                              'amount': 0,
                              'location': locationController.text.trim(),
                              'notes': notesController.text.trim(),
                            });
                            if (context.mounted) {
                              _fetchSavings();
                              AppNotification.success(
                                context,
                                "Tabungan berhasil dibuat!",
                              );
                            }
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted)
                            AppNotification.error(
                              context,
                              "Gagal membuat tabungan.",
                            );
                        }
                      },
                      child: Text(
                        "Simpan Tabungan",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Form Edit Tabungan ---
  void _showEditSheet(String oldName, String oldLocation, String oldNotes) {
    final nameController = TextEditingController(text: oldName);
    final locationController = TextEditingController(text: oldLocation);
    final notesController = TextEditingController(text: oldNotes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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
                      "Edit Tabungan",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Text(
                  "Nama Tabungan",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(
                      PhosphorIconsFill.vault,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF009688)),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                Text(
                  "Tempat Simpan",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locationController,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(
                      PhosphorIconsFill.bank,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF009688)),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // [FIX] Catatan edit kembali normal 1 baris
                Text(
                  "Catatan",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(
                      PhosphorIconsFill.notePencil,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF009688)),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;
                      try {
                        await _supabase
                            .from('savings')
                            .update({
                              'name': nameController.text.trim(),
                              'location': locationController.text.trim(),
                              'notes': notesController.text.trim(),
                            })
                            .eq('user_id', _supabase.auth.currentUser!.id)
                            .eq('name', oldName);

                        if (context.mounted) {
                          Navigator.pop(context);
                          _fetchSavings();
                          AppNotification.success(
                            context,
                            "Berhasil diupdate!",
                          );
                        }
                      } catch (e) {
                        if (context.mounted)
                          AppNotification.error(
                            context,
                            "Gagal update tabungan.",
                          );
                      }
                    },
                    child: Text(
                      "Simpan Perubahan",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Konfirmasi Hapus ---
  void _confirmDelete(String groupName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Tabungan?"),
        content: Text(
          "Anda yakin ingin menghapus '$groupName'? Semua riwayat di tabungan ini akan hilang (Saldo dompet TIDAK akan dikembalikan otomatis).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _supabase
                  .from('savings')
                  .delete()
                  .eq('user_id', _supabase.auth.currentUser!.id)
                  .eq('name', groupName);
              _fetchSavings();
              if (context.mounted)
                AppNotification.success(context, "Tabungan dihapus");
            },
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- Form Setor/Tarik dari Card ---
  void _showTransactionSheet(String groupName, bool isDeposit) {
    final amountController = TextEditingController();
    int? selectedWalletId = _wallets.isNotEmpty
        ? _wallets.first['id'] as int
        : null;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
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
                    Expanded(
                      child: Text(
                        isDeposit
                            ? "Setor ke $groupName"
                            : "Tarik dari $groupName",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Text(
                  isDeposit ? "Tarik dari Dompet" : "Simpan ke Dompet",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedWalletId,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(
                        PhosphorIconsRegular.caretDown,
                        color: Colors.grey,
                      ),
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'] as int,
                              child: Text(
                                "${w['name']} (Sisa: ${currencyFormat.format(w['balance'])})",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => selectedWalletId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  "Nominal",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isDeposit ? const Color(0xFF009688) : Colors.orange,
                  ),
                  decoration: InputDecoration(
                    hintText: "0",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.normal,
                      fontSize: 18,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(
                        "Rp",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: isDeposit
                            ? const Color(0xFF009688)
                            : Colors.orange,
                      ),
                    ),
                  ),
                  onChanged: (s) {
                    s = s.replaceAll(RegExp(r'[^0-9]'), '');
                    if (s.isNotEmpty) {
                      amountController.value = TextEditingValue(
                        text: currencyFormat.format(int.parse(s)),
                        selection: TextSelection.collapsed(
                          offset: currencyFormat.format(int.parse(s)).length,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDeposit
                          ? const Color(0xFF009688)
                          : Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (amountController.text.isEmpty ||
                          selectedWalletId == null) {
                        AppNotification.error(
                          context,
                          "Isi nominal dengan benar!",
                        );
                        return;
                      }
                      double amt = double.parse(
                        amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      );
                      _processSavingTransaction(
                        isDeposit: isDeposit,
                        savingName: groupName,
                        amount: amt,
                        walletId: selectedWalletId!,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(
                      isDeposit ? "Konfirmasi Setoran" : "Konfirmasi Penarikan",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        backgroundColor: AppColors.background,
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
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF009688), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF009688).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Semua Tabungan",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(_totalSavings),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsFill.piggyBank,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Belum ada tabungan",
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _groupedSavings.length,
                    itemBuilder: (context, index) {
                      String groupName = _groupedSavings.keys.elementAt(index);
                      List<SavingModel> items = _groupedSavings[groupName]!;
                      double groupTotal = items.fold(
                        0,
                        (sum, item) => sum + item.amount,
                      );

                      String loc = items.last.location ?? '';
                      String note = items.last.notes ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SavingDetailScreen(savingName: groupName),
                                ),
                              ).then((_) => _fetchSavings()),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF009688,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      PhosphorIconsFill.vault,
                                      color: Color(0xFF009688),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          groupName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          currency.format(groupTotal),
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF009688),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (loc.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  PhosphorIconsFill.bank,
                                                  size: 12,
                                                  color: Colors.blueGrey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  loc,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showEditSheet(
                                          groupName,
                                          loc,
                                          note,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _confirmDelete(groupName),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _showTransactionSheet(groupName, true),
                                    icon: const Icon(
                                      PhosphorIconsFill.downloadSimple,
                                      size: 18,
                                    ),
                                    label: Text(
                                      "Setor",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF009688),
                                      backgroundColor: const Color(
                                        0xFF009688,
                                      ).withOpacity(0.05),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _showTransactionSheet(groupName, false),
                                    icon: const Icon(
                                      PhosphorIconsFill.uploadSimple,
                                      size: 18,
                                    ),
                                    label: Text(
                                      "Tarik",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      backgroundColor: Colors.orange
                                          .withOpacity(0.05),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_new_saving',
        onPressed: () => _showAddTitleSheet(),
        backgroundColor: const Color(0xFF009688),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Buat Tabungan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
