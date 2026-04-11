import 'dart:typed_data';
import 'package:catat_uang_app/models/transaction_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  Future<Uint8List> generateReport({
    required DateTime month,
    required List<TransactionModel> transactions,
    required String userName,
    required double totalIncome,
    required double totalExpense,
    double totalSavings = 0,
    required double mainCashBalance, // [NEW] Parameter Kas Utama
    bool isCustomRange = false, 
    DateTime? endDate, 
  }) async {
    final pdf = pw.Document();

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    String periodLabel = "";
    if (isCustomRange && endDate != null) {
      periodLabel = "${DateFormat('dd MMM yyyy', 'id_ID').format(month)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(endDate)}";
    } else {
      periodLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    }

    final isNetPositive = mainCashBalance >= 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Laporan Keuangan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
                    pw.SizedBox(height: 4),
                    pw.Text('Oleh: $userName', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Periode Laporan', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(periodLabel, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 20),

            // KARTU RINGKASAN
            pw.Text("Ringkasan Saldo", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Pemasukan', currencyFormatter.format(totalIncome), '#E8F5E9', '#2E7D32'),
                pw.SizedBox(width: 10),
                _buildSummaryBox('Pengeluaran', currencyFormatter.format(totalExpense), '#FFEBEE', '#C62828'),
                pw.SizedBox(width: 10),
                // [UPDATE] Ubah jadi Sisa Kas Utama
               _buildSummaryBox('Total Saldo Dompet', currencyFormatter.format(mainCashBalance), isNetPositive ? '#E3F2FD' : '#FFF3E0', isNetPositive ? '#1565C0' : '#EF6C00'),
                _buildSummaryBox('Total Tabungan', currencyFormatter.format(totalSavings), '#E0F2F1', '#00796B'),
              ],
            ),
            pw.SizedBox(height: 30),

            // TABEL TRANSAKSI
            pw.Text("Rincian Transaksi", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Tanggal', 'Kategori', 'Catatan', 'Tipe', 'Jumlah'],
              data: transactions.map((trx) {
                final isExpense = trx.category?.isExpense ?? true;
                return [
                  DateFormat('dd MMM yyyy', 'id_ID').format(trx.date),
                  trx.category?.name ?? 'Umum',
                  trx.note ?? '-',
                  isExpense ? 'Keluar' : 'Masuk',
                  (isExpense ? '- ' : '+ ') + currencyFormatter.format(trx.amount),
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryBox(String title, String amount, String bgColorHex, String textColorHex) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex(bgColorHex),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex(textColorHex))),
            pw.SizedBox(height: 4),
            pw.Text(amount, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex(textColorHex))),
          ],
        ),
      ),
    );
  }
}