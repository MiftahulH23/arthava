import 'package:arthava/core/app_notification.dart';
import 'package:arthava/core/colors.dart';
import 'package:arthava/services/export_report_service.dart';
import 'package:arthava/services/pdf_service.dart';
import 'package:arthava/theme/app_text_styles.dart';
import 'package:arthava/widgets/app_buttons.dart';
import 'package:arthava/widgets/app_grouped_section.dart';
import 'package:arthava/widgets/app_list_row.dart';
import 'package:arthava/widgets/app_page_scaffold.dart';
import 'package:arthava/widgets/app_pickers.dart';
import 'package:arthava/widgets/app_segmented_control.dart';
import 'package:arthava/widgets/app_surface_card.dart';
import 'package:flutter/material.dart';
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
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isCustomRange = false;
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _selectedDateRange;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  Future<void> _pickMonth() async {
    final currentYear = DateTime.now().year;
    final picked = await showAppMonthPicker(
      context: context,
      title: 'Pilih Periode',
      initialMonth: _selectedMonth,
      firstYear: currentYear - 5,
      lastYear: currentYear + 5,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedMonth = picked);
  }

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      initialRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDateRange = picked);
  }

 Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);
    try {
      DateTime startDate;
      DateTime endDate;
      String reportTitle;

      if (_isCustomRange && _selectedDateRange != null) {
        startDate = _selectedDateRange!.start;
        endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        reportTitle = 'Laporan_${DateFormat('ddMMMyy').format(startDate)}_sd_${DateFormat('ddMMMyy').format(endDate)}';
      } else {
        startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
        reportTitle = 'Laporan_Keuangan_${DateFormat('MMMM_yyyy', 'id_ID').format(_selectedMonth)}';
      }

      final data = await loadExportReport(_supabase, startDate: startDate, endDate: endDate);

      if (data.transactions.isEmpty) {
        if (mounted) AppNotification.error(context, "Tidak ada transaksi di periode ini.");
        return; // finally mematikan loading (dengan cek mounted)
      }

      final pdfBytes = await PdfService().generateReport(
        month: _isCustomRange ? startDate : _selectedMonth,
        transactions: data.transactions,
        userName: data.userName,
        totalIncome: data.totalIncome,
        totalExpense: data.totalExpense,
        totalSavings: data.totalSavings,
        totalInvestments: data.totalInvestments,
        mainCashBalance: data.mainCashBalance,
        isCustomRange: _isCustomRange,
        endDate: endDate,
        walletsInfo: data.walletsInfo,
        expensesByCategory: data.expensesByCategory,
        incomeByCategory: data.incomeByCategory,
        largestExpense: data.largestExpense,
        largestIncome: data.largestIncome,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: reportTitle,
      );
      
    } catch (e) {
      if (mounted) AppNotification.error(context, "Gagal membuat PDF: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final String rangeLabel = _selectedDateRange != null
        ? "${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yy', 'id_ID').format(_selectedDateRange!.end)}"
        : "Pilih rentang";

    return AppPageScaffold(
      title: 'Export Laporan',
      backLabel: 'Beranda',
      bottomBar: AppPrimaryButton(
        label: 'Cetak Laporan PDF',
        icon: PhosphorIconsFill.printer,
        loading: _isGenerating,
        onPressed: _isGenerating ? null : _generatePdf,
      ),
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              const AppIconTile(icon: PhosphorIconsFill.filePdf, color: AppColors.primary, size: 72),
              const SizedBox(height: 12),
              Text('Cetak Laporan Keuangan', style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                'Pilih mode periode laporan di bawah ini',
                style: AppTextStyles.subhead,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        AppSegmentedControl(
          labels: const ['Satu Bulan', 'Pilih Tanggal'],
          selectedIndex: _isCustomRange ? 1 : 0,
          onChanged: (index) => setState(() => _isCustomRange = index == 1),
        ),
        AppGroupedSection(
          children: [
            if (!_isCustomRange)
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.calendarBlank, color: AppColors.primary),
                title: 'Bulan Laporan',
                value: DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                showChevron: true,
                onTap: _pickMonth,
              )
            else
              AppListRow(
                leading: const AppIconTile(icon: PhosphorIconsFill.calendarPlus, color: AppColors.primary),
                title: 'Rentang Tanggal',
                value: rangeLabel,
                showChevron: true,
                onTap: _pickDateRange,
              ),
          ],
        ),
      ],
    );
  }
}
