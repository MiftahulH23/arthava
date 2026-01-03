import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TargetScreen extends StatefulWidget {
  const TargetScreen({super.key});

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<TargetModel> _targets = [];
  double _totalSavings = 0;

  @override
  void initState() {
    super.initState();
    _fetchTargets();
  }

  Future<void> _fetchTargets() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('targets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<TargetModel> data = (res as List)
          .map((e) => TargetModel.fromJson(e))
          .toList();

      double total = 0;
      for (var t in data) total += t.savedAmount;

      if (mounted) {
        setState(() {
          _targets = data;
          _totalSavings = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Target: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC: REKOMENDASI NABUNG CERDAS ---
  String _getRecommendation(TargetModel target) {
    if (target.savedAmount >= target.targetAmount)
      return "Target tercapai! Mantap! 🎉";
    if (target.deadline == null)
      return "Set deadline agar dapat rekomendasi nabung.";

    final now = DateTime.now();
    // Hitung sisa hari (deadline - hari ini)
    final difference = target.deadline!.difference(now).inDays;
    final remainingAmount = target.targetAmount - target.savedAmount;

    if (difference <= 0) return "Deadline sudah terlewat!";

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Jika waktu < 60 hari, sarankan Harian
    if (difference < 60) {
      double dailySave = remainingAmount / difference;
      return "Nabung ${currency.format(dailySave)} / hari agar tercapai.";
    }
    // Jika waktu masih lama, sarankan Bulanan
    else {
      double months = difference / 30;
      double monthlySave = remainingAmount / months;
      return "Nabung ${currency.format(monthlySave)} / bulan agar tercapai.";
    }
  }

  // --- DIALOG TAMBAH TARGET ---
  void _showAddDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final locationController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    DateTime? selectedDate;

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
                    "Target Baru",
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
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nama Target",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: "Misal: Beli iPhone 15",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.normal,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Target Dana",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
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
                          hintText: "0",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                        onChanged: (s) {
                          s = s.replaceAll(RegExp(r'[^0-9]'), '');
                          if (s.isNotEmpty)
                            targetController.value = TextEditingValue(
                              text: currencyFormat.format(int.parse(s)),
                              selection: TextSelection.collapsed(
                                offset: currencyFormat
                                    .format(int.parse(s))
                                    .length,
                              ),
                            );
                        },
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Lokasi Penyimpanan",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Misal: Bank Jago / Celengan",
                          prefixIcon: const Icon(
                            PhosphorIconsFill.wallet,
                            color: AppColors.primary,
                          ),
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.normal,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Tenggat Waktu (Opsional)",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                    surface: Colors.white,
                                  ),
                                  dialogBackgroundColor: Colors.white,
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null)
                            setDialogState(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade500),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null
                                    ? "Pilih Tanggal"
                                    : DateFormat(
                                        'dd MMMM yyyy',
                                        'id_ID',
                                      ).format(selectedDate!),
                                style: GoogleFonts.poppins(
                                  fontWeight: selectedDate == null
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: selectedDate == null
                                      ? Colors.grey.shade600
                                      : Colors.black,
                                ),
                              ),
                              const Icon(
                                PhosphorIconsFill.calendarBlank,
                                color: AppColors.primary,
                              ),
                            ],
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          targetController.text.isEmpty)
                        return;
                      try {
                        await _supabase.from('targets').insert({
                          'user_id': _supabase.auth.currentUser!.id,
                          'name': nameController.text,
                          'target_amount': double.parse(
                            targetController.text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            ),
                          ),
                          'storage_location': locationController.text.isNotEmpty
                              ? locationController.text
                              : null,
                          'deadline': selectedDate?.toIso8601String(),
                        });
                        if (context.mounted) {
                          Navigator.pop(context);
                          _fetchTargets();
                          AppNotification.success(
                            context,
                            "Target berhasil dibuat!",
                          );
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                    },
                    child: const Text(
                      "Simpan Target",
                      style: TextStyle(
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

  // --- DIALOG EDIT TARGET ---
  void _showEditDialog(TargetModel target) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    final nameController = TextEditingController(text: target.name);
    final targetController = TextEditingController(
      text: currencyFormat.format(target.targetAmount),
    );
    final savedController = TextEditingController(
      text: currencyFormat.format(target.savedAmount),
    );
    final locationController = TextEditingController(
      text: target.storageLocation ?? "",
    );
    DateTime? selectedDate = target.deadline;

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
                    "Edit Target",
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
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nama Target",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Target Dana",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: targetController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
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
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                  ),
                                  onChanged: (s) {
                                    s = s.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (s.isNotEmpty)
                                      targetController.value = TextEditingValue(
                                        text: currencyFormat.format(
                                          int.parse(s),
                                        ),
                                        selection: TextSelection.collapsed(
                                          offset: currencyFormat
                                              .format(int.parse(s))
                                              .length,
                                        ),
                                      );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Terkumpul",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: savedController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        "Rp",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                  ),
                                  onChanged: (s) {
                                    s = s.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (s.isNotEmpty)
                                      savedController.value = TextEditingValue(
                                        text: currencyFormat.format(
                                          int.parse(s),
                                        ),
                                        selection: TextSelection.collapsed(
                                          offset: currencyFormat
                                              .format(int.parse(s))
                                              .length,
                                        ),
                                      );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Lokasi Penyimpanan",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationController,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            PhosphorIconsFill.wallet,
                            color: AppColors.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        "Tenggat Waktu",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.black,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null)
                            setDialogState(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade500),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null
                                    ? "Pilih Tanggal"
                                    : DateFormat(
                                        'dd MMMM yyyy',
                                        'id_ID',
                                      ).format(selectedDate!),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const Icon(
                                PhosphorIconsFill.calendarBlank,
                                color: AppColors.primary,
                              ),
                            ],
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          targetController.text.isEmpty)
                        return;
                      try {
                        await _supabase
                            .from('targets')
                            .update({
                              'name': nameController.text,
                              'target_amount': double.parse(
                                targetController.text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                ),
                              ),
                              'saved_amount': double.parse(
                                savedController.text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                ),
                              ),
                              'storage_location':
                                  locationController.text.isNotEmpty
                                  ? locationController.text
                                  : null,
                              'deadline': selectedDate?.toIso8601String(),
                            })
                            .eq('id', target.id);

                        if (context.mounted) {
                          Navigator.pop(context);
                          _fetchTargets();
                          AppNotification.success(
                            context,
                            "Target berhasil diupdate!",
                          );
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                    },
                    child: const Text(
                      "Simpan Perubahan",
                      style: TextStyle(
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

  // --- DIALOG NABUNG (DEPOSIT) ---
  void _showDepositDialog(TargetModel target) {
    final amountController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

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
              Expanded(
                child: Text(
                  "Nabung: ${target.name}",
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
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.info,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          target.storageLocation != null
                              ? "Uang ini disimpan di: ${target.storageLocation}"
                              : "Lokasi penyimpanan belum ditentukan.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "Mau nabung berapa hari ini?",
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.green,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Text(
                        "Rp",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    hintText: "0",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (s) {
                    s = s.replaceAll(RegExp(r'[^0-9]'), '');
                    if (s.isNotEmpty)
                      amountController.value = TextEditingValue(
                        text: currencyFormat.format(int.parse(s)),
                        selection: TextSelection.collapsed(
                          offset: currencyFormat.format(int.parse(s)).length,
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  if (amountController.text.isEmpty) return;
                  try {
                    final addAmount = double.parse(
                      amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                    );
                    final newTotal = target.savedAmount + addAmount;
                    await _supabase
                        .from('targets')
                        .update({'saved_amount': newTotal})
                        .eq('id', target.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      _fetchTargets();
                      AppNotification.success(
                        context,
                        "Berhasil nabung Rp ${amountController.text}!",
                      );
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
                child: const Text(
                  "Setor Tabungan",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG KONFIRMASI HAPUS ---
  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Target?"),
        content: Text(
          "Anda yakin ingin menghapus target '$name'? Data yang sudah disimpan akan hilang.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _supabase.from('targets').delete().eq('id', id);
              _fetchTargets();
              if (context.mounted)
                AppNotification.success(context, "Target dihapus");
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
          "Target Keuangan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsFill.piggyBank,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Tabungan",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                    Text(
                      currency.format(_totalSavings),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _targets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsFill.target,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Belum ada target",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _targets.length,
                    itemBuilder: (context, index) {
                      final item = _targets[index];
                      final progress = item.targetAmount == 0
                          ? 0.0
                          : item.savedAmount / item.targetAmount;
                      final percent = (progress * 100).clamp(0, 100).toInt();
                      final remaining = item.targetAmount - item.savedAmount;
                      final recommendation = _getRecommendation(item);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (item.storageLocation != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                PhosphorIconsFill.wallet,
                                                size: 14,
                                                color: Colors.blueGrey,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                item.storageLocation!,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.blueGrey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (item.deadline != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            "Deadline: ${DateFormat('dd MMM yyyy').format(item.deadline!)}",
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                      onPressed: () => _showEditDialog(item),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.grey,
                                        size: 22,
                                      ),
                                      onPressed: () =>
                                          _confirmDelete(item.id, item.name),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.only(left: 8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress > 1 ? 1 : progress,
                                backgroundColor: Colors.green.shade50,
                                color: Colors.green,
                                minHeight: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${currency.format(item.savedAmount)} / ${currency.format(item.targetAmount)}",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "$percent%",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),

                            // --- REKOMENDASI BOX ---
                            if (remaining > 0 && item.deadline != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(10),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.orange.shade100,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      PhosphorIconsFill.lightbulb,
                                      size: 18,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        recommendation,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  remaining <= 0
                                      ? "Tercapai! 🎉"
                                      : "Kurang ${currency.format(remaining)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                SizedBox(
                                  height: 35,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showDepositDialog(item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text(
                                      "Nabung",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
