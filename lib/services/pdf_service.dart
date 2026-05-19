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
    required double mainCashBalance,
    bool isCustomRange = false,
    DateTime? endDate,
    required List<Map<String, dynamic>> walletsInfo,
    required Map<String, double> expensesByCategory,
    required Map<String, double> incomeByCategory,
    TransactionModel? largestExpense,
    TransactionModel? largestIncome,
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

    // Helper for colors
    final List<PdfColor> chartColors = [
      PdfColors.blue400,
      PdfColors.red400,
      PdfColors.green400,
      PdfColors.orange400,
      PdfColors.purple400,
      PdfColors.teal400,
      PdfColors.pink400,
      PdfColors.amber400,
      PdfColors.cyan400,
      PdfColors.indigo400,
    ];

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
                    pw.Text('Laporan Keuangan', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
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
            pw.SizedBox(height: 15),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 15),

            // KARTU RINGKASAN
            pw.Text("Ringkasan Arus Kas", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryBox('Total Pemasukan', currencyFormatter.format(totalIncome), '#E8F5E9', '#2E7D32'),
                pw.SizedBox(width: 10),
                _buildSummaryBox('Total Pengeluaran', currencyFormatter.format(totalExpense), '#FFEBEE', '#C62828'),
                pw.SizedBox(width: 10),
                _buildSummaryBox('Total Saldo Dompet', currencyFormatter.format(mainCashBalance), isNetPositive ? '#E3F2FD' : '#FFF3E0', isNetPositive ? '#1565C0' : '#EF6C00'),
                pw.SizedBox(width: 10),
                _buildSummaryBox('Total Tabungan', currencyFormatter.format(totalSavings), '#E0F2F1', '#00796B'),
              ],
            ),
            pw.SizedBox(height: 25),

            // RINCIAN DOMPET (Horizontal Wrap or Row)
            if (walletsInfo.isNotEmpty) ...[
              pw.Text("Rincian Saldo Dompet", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: walletsInfo.map((w) {
                  return pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(w['name'], style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(currencyFormatter.format(w['balance']), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 25),
            ],

            // INSIGHTS & STATISTIK (Dua Kolom)
            pw.Text("Insight Transaksi", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Kolom Pengeluaran
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Pengeluaran Terbesar", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                        pw.SizedBox(height: 5),
                        if (expensesByCategory.isNotEmpty) ...[
                          pw.Text(expensesByCategory.entries.first.key, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(currencyFormatter.format(expensesByCategory.entries.first.value), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Total Akumulasi", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ] else ...[
                          pw.Text("Tidak ada data", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        ],
                        pw.SizedBox(height: 15),
                        pw.Text("Top Kategori", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        ...expensesByCategory.entries.take(4).map((e) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 9))),
                                pw.Text(currencyFormatter.format(e.value), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ],
                            )
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 15),
                // Kolom Pemasukan
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Pemasukan Terbesar", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                        pw.SizedBox(height: 5),
                        if (incomeByCategory.isNotEmpty) ...[
                          pw.Text(incomeByCategory.entries.first.key, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(currencyFormatter.format(incomeByCategory.entries.first.value), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Total Akumulasi", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ] else ...[
                          pw.Text("Tidak ada data", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        ],
                        pw.SizedBox(height: 15),
                        pw.Text("Top Kategori", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        ...incomeByCategory.entries.take(4).map((e) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 9))),
                                pw.Text(currencyFormatter.format(e.value), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ],
                            )
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            // GRAFIK (Hanya tampilkan jika chart tersedia dan ada data. Menggunakan layout bar manual sederhana untuk aman jika package pdf chart complex)
            if (expensesByCategory.isNotEmpty) ...[
               pw.Text("Proporsi Pengeluaran", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
               pw.SizedBox(height: 10),
               pw.Container(
                 padding: const pw.EdgeInsets.all(12),
                 decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                 child: pw.Column(
                   children: expensesByCategory.entries.map((e) {
                     final double percentage = totalExpense > 0 ? (e.value / totalExpense) : 0;
                     final int colorIndex = expensesByCategory.keys.toList().indexOf(e.key) % chartColors.length;
                     return pw.Padding(
                       padding: const pw.EdgeInsets.symmetric(vertical: 4),
                       child: pw.Row(
                         children: [
                           pw.SizedBox(width: 80, child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 9), maxLines: 1)),
                           pw.SizedBox(width: 10),
                           pw.Expanded(
                             child: pw.Stack(
                               children: [
                                 pw.Container(height: 10, decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(5))),
                                 if (percentage > 0)
                                   pw.Container(
                                     height: 10,
                                     width: (percentage * 300).clamp(10.0, 300.0),
                                     decoration: pw.BoxDecoration(color: chartColors[colorIndex], borderRadius: pw.BorderRadius.circular(5))
                                   ),
                               ]
                             ),
                           ),
                           pw.SizedBox(width: 10),
                           pw.SizedBox(width: 40, child: pw.Text('${(percentage * 100).toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                         ]
                       )
                     );
                   }).toList(),
                 )
               ),
               pw.SizedBox(height: 25),
            ],

            // TABEL TRANSAKSI
            pw.Text("Rincian Transaksi", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
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