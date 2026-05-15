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

  static Future<Uint8List> generateVendorProfilePdf({
    required String memberName,
    required String idNumber,
    required String phone,
    required String email,
    required String address,
    required String groupName,
    required String centerName,
    required double currentBalance,
    required List<Map<String, dynamic>> savingsHistory,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: 'R');

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
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                logoPlaceholder,
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('VENDOR PROFILE REPORT', 
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated: ${dateFormat.format(DateTime.now())}', 
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.amber, thickness: 2),
            pw.SizedBox(height: 20),

            pw.Text('PERSONAL INFORMATION', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(child: _buildInfoItem('Full Name', memberName)),
                pw.Expanded(child: _buildInfoItem('ID Number', idNumber)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(child: _buildInfoItem('Phone', phone)),
                pw.Expanded(child: _buildInfoItem('Email', email)),
              ],
            ),
            pw.SizedBox(height: 10),
            _buildInfoItem('Home Address', address),

            pw.SizedBox(height: 25),
            pw.Text('ASSOCIATION DETAILS', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(child: _buildInfoItem('Group Name', groupName)),
                pw.Expanded(child: _buildInfoItem('Center Name', centerName)),
              ],
            ),

            pw.SizedBox(height: 25),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.amber200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('CURRENT SAVINGS BALANCE', 
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(currencyFormat.format(currentBalance), 
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                ],
              ),
            ),

            pw.SizedBox(height: 30),
            pw.Text('RECENT SAVINGS HISTORY', 
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date/Time', isHeader: true),
                    _buildTableCell('Action', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                    _buildTableCell('New Balance', isHeader: true),
                  ],
                ),
                ...savingsHistory.take(10).map((h) => pw.TableRow(
                  children: [
                    _buildTableCell(dateFormat.format(h['createdAt'] as DateTime)),
                    _buildTableCell(h['actionType'].toString()),
                    _buildTableCell(currencyFormat.format(h['amount'])),
                    _buildTableCell(currencyFormat.format(h['newBalance'])),
                  ],
                )),
              ],
            ),

            if (savingsHistory.isEmpty) 
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Center(child: pw.Text('No recent transactions found.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
              ),

            pw.SizedBox(height: 30),
            pw.Text('COMPLIANCE & TERMS', 
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Bullet(text: 'All savings transactions are recorded in real-time and subject to audit.', style: const pw.TextStyle(fontSize: 9)),
            pw.Bullet(text: 'Withdrawals are subject to group approval and center policies.', style: const pw.TextStyle(fontSize: 9)),
            pw.Bullet(text: 'Monthly admin fees (R65.00) apply for active management.', style: const pw.TextStyle(fontSize: 9)),
            
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 40),
              child: pw.Divider(),
            ),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('NSBSA | Empowering Communities', 
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('info@nsbsa.org.za | 087 107 7524 | www.stokvelbody.org.za', 
                    style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(value.isEmpty ? '-' : value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildTableCell(String value, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(value, 
        style: pw.TextStyle(
          fontSize: 9, 
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
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
