import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfService {
  static Future<Uint8List> generatePaymentSlip({
    required String loanRef,
    required String memberName,
    required String groupName,
    required String centerName,
    required double amountPaid,
    required double balanceRemaining,
    required DateTime paymentDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: 'R');

    // Load logo if possible, otherwise use text
    pw.Widget logoPlaceholder;
    try {
      final logoData = await rootBundle.load('assets/images/logo1.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      logoPlaceholder = pw.Image(logoImage, width: 100);
    } catch (e) {
      logoPlaceholder = pw.Text('NSBSA', 
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.amber));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    logoPlaceholder,
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PAYMENT RECEIPT', 
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(dateFormat.format(paymentDate), 
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.amber),
                pw.SizedBox(height: 10),
                
                _buildRow('Member Name:', memberName),
                _buildRow('Loan Reference:', loanRef),
                _buildRow('Group:', groupName),
                _buildRow('Center:', centerName),
                
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  color: PdfColors.grey100,
                  child: pw.Column(
                    children: [
                      _buildRow('Amount Paid:', currencyFormat.format(amountPaid), isBold: true),
                      pw.SizedBox(height: 5),
                      _buildRow('Remaining Balance:', currencyFormat.format(balanceRemaining)),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                pw.Text('FEE INFORMATION', 
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Bullet(text: 'Initiation Fee: R150.00'),
                pw.Bullet(text: 'Monthly Admin Fee: R65.00'),
                pw.Bullet(text: 'Penalty: Applied if payment is missed by 20 days.'),
                
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('NSBSA | Empowering Communities', 
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('www.stokvelbody.org.za', 
                        style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(
            fontSize: 10, 
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal
          )),
        ],
      ),
    );
  }
}
