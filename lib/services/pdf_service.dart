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
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);

    // Styling
    final titleStyle = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final contentStyle = const pw.TextStyle(fontSize: 10);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // 1. HEADER
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Laporan Keuangan", style: titleStyle),
                    pw.Text("Periode: $monthLabel"),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Dibuat oleh:", style: const pw.TextStyle(color: PdfColors.grey)),
                    pw.Text(userName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 2. SUMMARY BOX
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem("Total Pemasukan", totalIncome, PdfColors.green, currencyFormat),
                  _buildSummaryItem("Total Pengeluaran", totalExpense, PdfColors.red, currencyFormat),
                  _buildSummaryItem("Sisa Saldo", totalIncome - totalExpense, PdfColors.blue, currencyFormat),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 3. TABEL TRANSAKSI
            pw.TableHelper.fromTextArray(
              headers: ['Tanggal', 'Kategori', 'Catatan', 'Tipe', 'Jumlah'],
              data: transactions.map((trx) {
                final isExpense = trx.category?.isExpense ?? true;
                return [
                  dateFormat.format(trx.date),
                  trx.category?.name ?? "Umum",
                  trx.note ?? "-",
                  isExpense ? "Keluar" : "Masuk",
                  (isExpense ? "- " : "+ ") + currencyFormat.format(trx.amount),
                ];
              }).toList(),
              border: null,
              headerStyle: headerStyle,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: contentStyle,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            
            // 4. FOOTER
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(
              child: pw.Text(
                "Dicetak otomatis oleh Aplikasi DompetKu",
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryItem(String label, double amount, PdfColor color, NumberFormat format) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(
          format.format(amount),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }
}