import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/saving_model.dart';
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

  // [UPDATE 1] Kita ubah List menjadi Map untuk mengelompokkan data berdasarkan Nama Tabungan
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

        // [UPDATE 2] Kelompokkan berdasarkan Nama (huruf besar/kecil dianggap sama biar rapi)
        String groupName = saving.name.trim();
        // Pakai lowercase untuk ngecek key biar kalau user ngetik "Dana Darurat" atau "dana darurat" tetap nyatu
        String groupKey = groupName.toLowerCase();

        // Kita cari apakah key sudah ada (berdasarkan huruf kecilnya),
        // kalau belum, kita buat list baru dengan nama aslinya
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

  // --- LOGIKA MENCARI KATEGORI DEFAULT TABUNGAN ---
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

  // --- HAPUS TABUNGAN & TRANSAKSI OTOMATIS ---
  Future<void> _deleteSaving(SavingModel item) async {
    try {
      await _supabase.from('savings').delete().eq('id', item.id);

      final noteMarker = "[SAVING_ID:${item.id}]";
      await _supabase
          .from('transactions')
          .delete()
          .like('note', '%$noteMarker%');

      _fetchSavings();
      if (mounted)
        AppNotification.success(
          context,
          "Data dihapus! Saldo kas dikembalikan.",
        );
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal menghapus data.");
    }
  }

  // --- DIALOG FORM (TAMBAH / EDIT) ---
  void _showFormDialog({SavingModel? saving}) {
    final isEdit = saving != null;
    final nameController = TextEditingController(text: saving?.name ?? '');
    final amountController = TextEditingController(
      text: saving != null ? saving.amount.toInt().toString() : '',
    );
    final locationController = TextEditingController(
      text: saving?.location ?? '',
    );
    final notesController = TextEditingController(text: saving?.notes ?? '');

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    if (isEdit) {
      amountController.text = currencyFormat.format(saving.amount);
    }

    showDialog(
      context: context,
      builder: (context) {
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
                isEdit ? "Edit Setoran" : "Tambah Tabungan",
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
                  _buildInputLabel("Nama Tabungan / Tujuan"),
                  _buildTextField(
                    controller: nameController,
                    hint: "Contoh: Dana Darurat",
                    icon: PhosphorIconsFill.target,
                  ),
                  const SizedBox(height: 15),

                  _buildInputLabel(
                    isEdit ? "Nominal Setoran" : "Nominal Setoran Awal",
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
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
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
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
                  const SizedBox(height: 15),

                  _buildInputLabel("Tempat Simpan"),
                  _buildTextField(
                    controller: locationController,
                    hint: "Contoh: Bank BCA / Celengan",
                    icon: PhosphorIconsFill.bank,
                  ),
                  const SizedBox(height: 15),

                  _buildInputLabel("Catatan (Opsional)"),
                  _buildTextField(
                    controller: notesController,
                    hint: "Contoh: Jangan diganggu gugat",
                    icon: PhosphorIconsFill.notePencil,
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      amountController.text.isEmpty) {
                    AppNotification.error(
                      context,
                      "Nama dan Nominal wajib diisi!",
                    );
                    return;
                  }

                  final amount = double.parse(
                    amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  final userId = _supabase.auth.currentUser!.id;
                  final savingName = nameController.text.trim();

                  final dataSaving = {
                    'user_id': userId,
                    'name': savingName,
                    'amount': amount,
                    'location': locationController.text.trim(),
                    'notes': notesController.text.trim(),
                  };

                  try {
                    final catId = await _getOrCreateSavingCategory();

                    if (isEdit) {
                      // 1. Update Tabel Tabungan
                      await _supabase
                          .from('savings')
                          .update(dataSaving)
                          .eq('id', saving.id);

                      // 2. Update Transaksi Terkait
                      final noteMarker = "[SAVING_ID:${saving.id}]";
                      final autoNote = "Menabung ke $savingName $noteMarker";

                      await _supabase
                          .from('transactions')
                          .update({'amount': amount, 'note': autoNote})
                          .like('note', '%$noteMarker%');
                    } else {
                      // 1. Insert Tabungan Baru & Ambil ID-nya
                      final insertedData = await _supabase
                          .from('savings')
                          .insert(dataSaving)
                          .select('id')
                          .single();
                      final newSavingId = insertedData['id'];

                      // 2. Buat Transaksi Pengeluaran Otomatis
                      final noteMarker = "[SAVING_ID:$newSavingId]";
                      final autoNote = "Menabung ke $savingName $noteMarker";

                      await _supabase.from('transactions').insert({
                        'user_id': userId,
                        'category_id': catId,
                        'amount': amount,
                        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        'note': autoNote,
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      _fetchSavings();
                      AppNotification.success(
                        context,
                        isEdit
                            ? "Data diperbarui!"
                            : "Tabungan ditambah! Saldo kas dipotong.",
                      );
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                    if (context.mounted)
                      AppNotification.error(context, "Gagal menyimpan data.");
                  }
                },
                child: const Text(
                  "Simpan Data",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // CARD TOTAL TABUNGAN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF009688), // Warna Teal
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF009688).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  PhosphorIconsFill.piggyBank,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  "Total Aset / Tabungan",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
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
          ),

          // [UPDATE 3] MENAMPILKAN DATA SECARA GROUPING (ACCORDION)
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
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Belum ada catatan tabungan",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _groupedSavings.length,
                    itemBuilder: (context, index) {
                      // Ambil Data Group
                      String groupName = _groupedSavings.keys.elementAt(index);
                      List<SavingModel> groupItems =
                          _groupedSavings[groupName]!;

                      // Hitung Total per Group
                      double groupTotal = groupItems.fold(
                        0,
                        (sum, item) => sum + item.amount,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            // HEADER ACCORDION (TOTAL PER TUJUAN)
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF009688,
                                    ).withOpacity(0.1),
                                    shape: BoxShape.circle,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        groupName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        "${groupItems.length} Catatan",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currency.format(groupTotal),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF009688),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),

                            // ANAK ACCORDION (HISTORI RINCIAN PER SETORAN)
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  children: groupItems.map((item) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.shade100,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (item.location != null &&
                                                    item.location!.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        PhosphorIconsFill
                                                            .mapPin,
                                                        size: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.location!,
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                if (item.notes != null &&
                                                    item.notes!.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      item.notes!,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            color: Colors.grey,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                currency.format(item.amount),
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              GestureDetector(
                                                onTap: () => _showFormDialog(
                                                  saving: item,
                                                ),
                                                child: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Colors.blue,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      backgroundColor:
                                                          Colors.white,
                                                      surfaceTintColor:
                                                          Colors.transparent,
                                                      title: const Text(
                                                        "Hapus Setoran?",
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      content: const Text(
                                                        "Yakin hapus data ini? Uang ini akan dikembalikan ke Saldo Kas Anda.",
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                              ),
                                                          child: const Text(
                                                            "Batal",
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            _deleteSaving(item);
                                                          },
                                                          child: const Text(
                                                            "Hapus",
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
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
