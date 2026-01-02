import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:catat_uang_app/services/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime _selectedMonth = DateTime.now();
  bool _isGenerating = false;

  Future<void> _pickMonth() async {
    final currentYear = DateTime.now().year;
    // Generate tahun dari 5 tahun lalu sampai 5 tahun ke depan
    final years = List.generate(11, (i) => (currentYear - 5) + i);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              // HEADER: JUDUL & DROPDOWN TAHUN
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pilih Periode",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // DROPDOWN TAHUN
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth.year,
                        // FIX: SET WARNA BACKGROUND PUTIH
                        dropdownColor: Colors.white,
                        isDense: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.primary,
                        ),
                        items: years.map((year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              "$year",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              _selectedMonth = DateTime(
                                val,
                                _selectedMonth.month,
                              );
                            });
                            setState(() {
                              _selectedMonth = DateTime(
                                val,
                                _selectedMonth.month,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // BODY: GRID BULAN
              content: SizedBox(
                width: 300,
                height: 300,
                child: Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final int monthIndex = index + 1;
                          final bool isSelected =
                              _selectedMonth.month == monthIndex;

                          return InkWell(
                            onTap: () {
                              setState(
                                () => _selectedMonth = DateTime(
                                  _selectedMonth.year,
                                  monthIndex,
                                ),
                              );
                              Navigator.pop(context);
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                DateFormat(
                                  'MMM',
                                  'id_ID',
                                ).format(DateTime(2024, monthIndex)),
                                style: GoogleFonts.poppins(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
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

  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

      final userResponse = await _supabase
          .from('profiles')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      final userName = userResponse != null ? userResponse['name'] : "User";

      final response = await _supabase
          .from('transactions')
          .select('*, categories!inner(*)')
          .eq('user_id', userId)
          .gte('date', DateFormat('yyyy-MM-dd').format(start))
          .lt('date', DateFormat('yyyy-MM-dd').format(end))
          .order('date', ascending: true);

      final List<TransactionModel> transactions = (response as List)
          .map((x) => TransactionModel.fromJson(x))
          .toList();

      if (transactions.isEmpty) {
        if (mounted)
          AppNotification.error(context, "Tidak ada transaksi di bulan ini.");
        setState(() => _isGenerating = false);
        return;
      }

      double income = 0;
      double expense = 0;
      for (var t in transactions) {
        if (t.category?.isExpense == true) {
          expense += t.amount;
        } else {
          income += t.amount;
        }
      }

      final pdfBytes = await PdfService().generateReport(
        month: _selectedMonth,
        transactions: transactions,
        userName: userName,
        totalIncome: income,
        totalExpense: expense,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name:
            'Laporan_Keuangan_${DateFormat('MM_yyyy').format(_selectedMonth)}',
      );
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal membuat PDF: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Export Laporan",
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    PhosphorIconsFill.filePdf,
                    size: 50,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Pilih Periode Laporan",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Laporan akan dicetak dalam format PDF",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  InkWell(
                    onTap: _pickMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                PhosphorIconsRegular.calendarBlank,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                monthLabel,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generatePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            PhosphorIconsFill.printer,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Cetak Laporan PDF",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
