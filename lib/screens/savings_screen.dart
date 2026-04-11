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
      if (mounted) {
        setState(() {
          _wallets = List<Map<String, dynamic>>.from(res);
        });
      }
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

  // [UX UPGRADE] Ubah Dialog jadi Bottom Sheet yang lebih modern
  void _showFormSheet() {
    bool isDeposit = true;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();

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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
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
                    // Drag Handle (Garis kecil di atas)
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
                    const SizedBox(height: 15),

                    // Toggle Setor / Tarik
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
                                  setSheetState(() => isDeposit = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDeposit
                                      ? const Color(0xFF009688)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isDeposit
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF009688,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Setor (Nabung)",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: isDeposit
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isDeposit = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !isDeposit
                                      ? Colors.orange
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !isDeposit
                                      ? [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Tarik (Ambil)",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: !isDeposit
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Konten Form (Bisa di-scroll kalau layarnya kecil)
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDeposit
                                  ? "Nama Tujuan Tabungan"
                                  : "Tarik Dari Tabungan Apa?",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
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
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(
                                  PhosphorIconsFill.target,
                                  color: Colors.grey,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF009688),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            Text(
                              isDeposit
                                  ? "Tarik Dari Dompet Mana?"
                                  : "Simpan Ke Dompet Mana?",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
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
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: selectedWalletId,
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  hint: Text(
                                    _wallets.isEmpty
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
                                  items: _wallets.map((w) {
                                    return DropdownMenuItem<int>(
                                      value: w['id'] as int,
                                      child: Text(
                                        "${w['name']} (Sisa: ${currencyFormat.format(w['balance'])})",
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
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

                            Text(
                              "Nominal ${isDeposit ? 'Disetor' : 'Ditarik'}",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
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
                                color: isDeposit ? Colors.black : Colors.orange,
                              ),
                              decoration: InputDecoration(
                                hintText: "0",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
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
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF009688),
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

                            Text(
                              "Tempat Simpan (Opsional)",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: locationController,
                              style: GoogleFonts.poppins(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "Contoh: Bank BCA / Celengan Ayam",
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
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF009688),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            Text(
                              "Catatan (Opsional)",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade700,
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
                                    ? "Biar cepat beli rumah"
                                    : "Buat benerin motor",
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
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF009688),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),

                    // Tombol Simpan
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
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              amountController.text.isEmpty)
                            return;

                          if (selectedWalletId == null) {
                            AppNotification.error(
                              context,
                              "Pilih dompet terlebih dahulu!",
                            );
                            return;
                          }

                          double rawAmount = double.parse(
                            amountController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          );
                          final savingName = nameController.text.trim();

                          final selectedWalletData = _wallets.firstWhere(
                            (w) => w['id'] == selectedWalletId,
                          );
                          final currentWalletBal =
                              (selectedWalletData['balance'] as num).toDouble();

                          if (isDeposit && rawAmount > currentWalletBal) {
                            AppNotification.error(
                              context,
                              "Saldo dompet ${selectedWalletData['name']} tidak cukup!",
                            );
                            return;
                          }

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

                          final finalAmount = isDeposit
                              ? rawAmount
                              : -rawAmount;
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
                                  'location': locationController.text.trim(),
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
                              'wallet_id': selectedWalletId,
                            });

                            double newBalance = isDeposit
                                ? currentWalletBal - rawAmount
                                : currentWalletBal + rawAmount;
                            await _supabase
                                .from('wallets')
                                .update({'balance': newBalance})
                                .eq('id', selectedWalletId!);

                            if (context.mounted) {
                              Navigator.pop(context);
                              _fetchWallets();
                              _fetchSavings();
                              if (isDeposit) {
                                AppNotification.success(
                                  context,
                                  "Tabungan ditambah! Saldo dompet dipotong.",
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
                                    content: Text(
                                      "Uang telah dikembalikan ke dompet ${selectedWalletData['name']} Anda.",
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
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // [UX UPGRADE] Kartu Total Aset Jadi Premium Gradient
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

          // LIST TABUNGAN
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
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF009688,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.vault,
                                  color: Color(0xFF009688),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      groupName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${groupItems.length} Riwayat Transaksi",
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
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Detail",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey.shade600,
                                          size: 14,
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
                    },
                  ),
          ),
        ],
      ),
      // [UX UPGRADE] Extended FAB Biar Lebih Jelas
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'savings_fab',
        onPressed: () => _showFormSheet(),
        backgroundColor: const Color(0xFF009688),
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Catat Tabungan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
