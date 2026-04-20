import 'package:flutter/foundation.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateAndShareTaxStatement({
    required String name,
    required List<Map<String, dynamic>> transactions,
    required String dateRange,
  }) async {
    final pdf = pw.Document();

    // Filter for Returns/Interest only
    // Based on _TxTile logic: 'return', 'repay', 'settlement'
    final filtered = transactions.where((tx) {
      final desc = tx['description']?.toString().toLowerCase() ?? '';
      final status = tx['status']?.toString().toLowerCase() ?? 'completed';
      return (desc.contains('return') ||
              desc.contains('repay') ||
              desc.contains('settlement')) &&
          status == 'completed';
    }).toList();

    double totalReturns = 0;
    for (final tx in filtered) {
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
      totalReturns += amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          ),
        build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Finworks360',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Tax Statement',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Investor: $name',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),),
                    pw.Text('Report Type: Interest & Returns Only'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Period: $dateRange'),
                    pw.Text(
                        'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.TableHelper.fromTextArray(
              border: null,
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headerHeight: 25,
              cellHeight: 25,
              headerStyle: pw.TextStyle(
                color: PdfColors.black,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(
                color: PdfColors.black,
                fontSize: 9,
              ),
              headers: ['Date', 'Description', 'Amount (INR)'],
              data: filtered.map((tx) => [
                  tx['date']?.toString() ?? '',
                  tx['description']?.toString() ?? '',
                  fmtAmount(double.tryParse(tx['amount']?.toString() ?? '0') ?? 0),
                ],).toList(),
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'Total Return/Interest Earned: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'INR ${fmtAmount(totalReturns)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
              ),
              child: pw.Text(
                'This is a computer-generated statement and does not require a physical signature. Finworks360 Invoice Discounting Platform.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'tax_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing PDF: $e');
      }
    }
  }
}
