import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/target_model.dart';
import 'package:catat_uang_app/providers/target_provider.dart';
import 'package:catat_uang_app/widgets/app_bottom_sheet.dart';
import 'package:catat_uang_app/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TargetScreen extends ConsumerStatefulWidget {
  const TargetScreen({super.key});

  @override
  ConsumerState<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends ConsumerState<TargetScreen> {
  String _getRecommendation(TargetModel target) {
    if (target.savedAmount >= target.targetAmount)
      return "Target tercapai! Mantap! 🎉";
    if (target.deadline == null)
      return "Set deadline agar dapat rekomendasi nabung.";

    final now = DateTime.now();
    final difference = target.deadline!.difference(now).inDays;
    final remainingAmount = target.targetAmount - target.savedAmount;

    if (difference <= 0) return "Deadline sudah terlewat!";

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (difference < 60) {
      double dailySave = remainingAmount / difference;
      return "Nabung ${currency.format(dailySave)} / hari agar tercapai.";
    } else {
      double months = difference / 30;
      double monthlySave = remainingAmount / months;
      return "Nabung ${currency.format(monthlySave)} / bulan agar tercapai.";
    }
  }

  void _showAddSheet() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final locationController = TextEditingController();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    DateTime? selectedDate;

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final savingNames = ref.read(targetProvider).savingNames;
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
                    const SizedBox(height: 15),

                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
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
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: "Misal: Beli iPhone 15",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(
                                  PhosphorIconsFill.target,
                                  color: Colors.grey,
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
                                    color: Color(0xFF009688),
                                  ),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: const Color(0xFF009688),
                              ),
                              decoration: InputDecoration(
                                hintText: "0",
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
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
                                    color: Color(0xFF009688),
                                  ),
                                ),
                              ),
                              onChanged: (s) {
                                s = s.replaceAll(RegExp(r'[^0-9]'), '');
                                if (s.isNotEmpty) {
                                  targetController.value = TextEditingValue(
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
                              "Lokasi Penyimpanan Sementara",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return savingNames;
                                }
                                return savingNames.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                locationController.text = selection;
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                textEditingController.addListener(() {
                                  locationController.text = textEditingController.text;
                                });
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Pilih / Ketik Nama Tabungan",
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: const Icon(
                                      PhosphorIconsFill.link,
                                      color: Colors.grey,
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
                                        color: Color(0xFF009688),
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF009688),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      PhosphorIconsRegular.calendarBlank,
                                      color: Color(0xFF009688),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: AppButton(
                        label: "Simpan Target",
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              targetController.text.isEmpty)
                            return;
                          try {
                            await ref.read(targetProvider.notifier).addTarget(
                                  name: nameController.text,
                                  targetAmount: double.parse(
                                    targetController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  ),
                                  storageLocation:
                                      locationController.text.isNotEmpty
                                      ? locationController.text
                                      : null,
                                  deadline: selectedDate,
                                );
                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.success(
                                context,
                                "Target berhasil dibuat!",
                              );
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        },
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

  void _showEditSheet(TargetModel target) {
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

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final savingNames = ref.read(targetProvider).savingNames;
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
                    const SizedBox(height: 15),

                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
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
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
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
                                    color: Color(0xFF009688),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF009688),
                                            ),
                                          ),
                                        ),
                                        onChanged: (s) {
                                          s = s.replaceAll(
                                            RegExp(r'[^0-9]'),
                                            '',
                                          );
                                          if (s.isNotEmpty) {
                                            targetController
                                                .value = TextEditingValue(
                                              text: currencyFormat.format(
                                                int.parse(s),
                                              ),
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: currencyFormat
                                                        .format(int.parse(s))
                                                        .length,
                                                  ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.green.shade50,
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.green.shade100,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.green.shade100,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF009688),
                                            ),
                                          ),
                                        ),
                                        onChanged: (s) {
                                          s = s.replaceAll(
                                            RegExp(r'[^0-9]'),
                                            '',
                                          );
                                          if (s.isNotEmpty) {
                                            savedController
                                                .value = TextEditingValue(
                                              text: currencyFormat.format(
                                                int.parse(s),
                                              ),
                                              selection:
                                                  TextSelection.collapsed(
                                                    offset: currencyFormat
                                                        .format(int.parse(s))
                                                        .length,
                                                  ),
                                            );
                                          }
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
                            Autocomplete<String>(
                              initialValue: TextEditingValue(text: locationController.text),
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return savingNames;
                                }
                                return savingNames.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                locationController.text = selection;
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                textEditingController.addListener(() {
                                  locationController.text = textEditingController.text;
                                });
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Pilih / Ketik Nama Tabungan",
                                    hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: const Icon(
                                      PhosphorIconsFill.link,
                                      color: Color(0xFF009688),
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
                                        color: Color(0xFF009688),
                                      ),
                                    ),
                                  ),
                                );
                              },
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
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF009688),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      color: Color(0xFF009688),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: AppButton(
                        label: "Simpan Perubahan",
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              targetController.text.isEmpty)
                            return;
                          try {
                            await ref.read(targetProvider.notifier).editTarget(
                                  id: target.id,
                                  name: nameController.text,
                                  targetAmount: double.parse(
                                    targetController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  ),
                                  savedAmount: double.parse(
                                    savedController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  ),
                                  storageLocation:
                                      locationController.text.isNotEmpty
                                      ? locationController.text
                                      : null,
                                  deadline: selectedDate,
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.success(
                                context,
                                "Target berhasil diupdate!",
                              );
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        },
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

  void _showDepositSheet(TargetModel target) {
    final amountController = TextEditingController();
    final wallets = ref.read(targetProvider).wallets;
    int? selectedWalletId = wallets.isNotEmpty
        ? wallets.first['id'] as int
        : null;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.info,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              target.storageLocation != null
                                  ? "Disimpan di: ${target.storageLocation}"
                                  : "Lokasi penyimpanan belum ditentukan.",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Tarik Dana Dari Dompet Mana?",
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
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          icon: const Icon(
                            PhosphorIconsRegular.caretDown,
                            color: Colors.grey,
                          ),
                          items: wallets.map((w) {
                            return DropdownMenuItem<int>(
                              value: w['id'] as int,
                              child: Text(
                                "${w['name']} (Sisa: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(w['balance'])})",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setSheetState(() => selectedWalletId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Text(
                      "Mau nabung berapa hari ini?",
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
                        fontSize: 18,
                        color: Colors.green,
                      ),
                      decoration: InputDecoration(
                        hintText: "0",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.green),
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
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (amountController.text.isEmpty ||
                              selectedWalletId == null)
                            return;

                          try {
                            final rawAmount = double.parse(
                              amountController.text.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              ),
                            );

                            final result = await ref
                                .read(targetProvider.notifier)
                                .depositToTarget(
                                  target: target,
                                  rawAmount: rawAmount,
                                  walletId: selectedWalletId!,
                                );

                            if (result != null) {
                              if (context.mounted) {
                                AppNotification.error(context, result);
                              }
                              return;
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              AppNotification.success(
                                context,
                                "Berhasil nabung Rp ${amountController.text}!",
                              );
                            }
                          } catch (e) {
                            debugPrint(e.toString());
                          }
                        },
                        child: Text(
                          "Setor Tabungan",
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

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Target?"),
        content: Text(
          "Anda yakin ingin menghapus target '$name'? Saldo di target ini akan hilang (Catatan: Saldo dompet Anda TIDAK akan dikembalikan otomatis karena ini dihapus paksa).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(targetProvider.notifier).deleteTarget(id);
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

    final targetState = ref.watch(targetProvider);
    final isLoading = targetState.isLoading;
    final targets = targetState.targets;
    final totalSavings = targetState.totalSavings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Target Keuangan",
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
                      "Total Semua Target",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currency.format(totalSavings),
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
                    PhosphorIconsFill.target,
                    color: Color(0xFF009688),
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : targets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsFill.target,
                          size: 60,
                          color: Colors.grey.shade300,
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
                    physics: const BouncingScrollPhysics(),
                    itemCount: targets.length,
                    itemBuilder: (context, index) {
                      final item = targets[index];
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
                              blurRadius: 10,
                              offset: const Offset(0, 4),
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
                                            top: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                PhosphorIconsRegular
                                                    .calendarBlank,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                "Deadline: ${DateFormat('dd MMM yyyy').format(item.deadline!)}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // [UX UPGRADE] Tombol Edit dan Delete dibikin lebih rapat & premium
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showEditSheet(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(
                                            0.1,
                                          ),
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
                                      onTap: () =>
                                          _confirmDelete(item.id, item.name),
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
                                    onPressed: remaining <= 0
                                        ? null
                                        : () => _showDepositSheet(item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF009688),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: const Color(0xFF009688),
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Buat Target",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
