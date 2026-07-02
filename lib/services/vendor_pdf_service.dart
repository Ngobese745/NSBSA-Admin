import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/vendor.dart';
import '../models/group.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../providers/comment_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/savings_history_provider.dart';
import '../models/savings_history.dart';
import '../core/pdf_branding.dart';
import 'loan_calculation_service.dart';

class VendorPdfService {
  static Future<void> generateProfilePDF({
    required BuildContext context,
    required VendorModel vendor,
    required GroupModel group,
    required List<LoanModel> loans,
  }) async {
    final commentProvider = context.read<CommentProvider>();
    final paymentProvider = context.read<PaymentProvider>();
    final savingsHistoryProvider = context.read<SavingsHistoryProvider>();
    final pdf = pw.Document();

    final logo = await PdfBranding.loadLogo();

    // Filter payments for this vendor's loans
    final loanIds = loans.map((l) => l.id).toSet();
    final vendorPayments = paymentProvider.payments
        .where((p) => loanIds.contains(p.loanId))
        .toList();
    double totalPaid = vendorPayments.fold(0, (sum, p) => sum + p.amountPaid);
    final totalExpected = loans.fold(
      0.0,
      (sum, loan) =>
          sum +
          (loan.openingAmount != null
              ? loan.openingAmount!
              : (loan.monthlyPayment + LoanCalculationService.effectiveAdminFee(loan)) * loan.durationMonths +
                  LoanCalculationService.effectiveInitiationFee(loan)),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, height: 50),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Member Profile Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Reference: ${vendor.referenceNumber ?? 'N/A'}'),
                  pw.Text(
                    'Date: ${DateTime.now().toString().substring(0, 10)}',
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 20),
            pw.Text(
              'Personal Information',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfInfoRow('Name', vendor.name),
                      _pdfInfoRow('Role', vendor.role ?? 'Member'),
                      _pdfInfoRow('Group', group.name),
                      _pdfInfoRow('Phone', vendor.phone ?? 'N/A'),
                      _pdfInfoRow('WhatsApp', vendor.whatsappNumber ?? 'N/A'),
                      _pdfInfoRow('Address', vendor.address ?? 'N/A'),
                      _pdfInfoRow(
                        'Savings Balance',
                        'R ${vendor.savingsAmount?.toStringAsFixed(2) ?? '0.00'} (${vendor.savingsFrequency ?? 'Monthly'})',
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfInfoRow('ID Number', vendor.idNumber ?? 'N/A'),
                      _pdfInfoRow('Business', vendor.businessType ?? 'N/A'),
                      _pdfInfoRow('Gender', vendor.gender ?? 'N/A'),
                      _pdfInfoRow('DF Name', vendor.dfName ?? 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Comments Section
            if (commentProvider.comments.isNotEmpty) ...[
              pw.Text(
                'Notes & Comments',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              ...commentProvider.comments.map((comment) {
                final isMention = comment.mentionedVendorIds.contains(
                  vendor.id,
                );
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${comment.authorName} ${isMention ? "(Mentioned)" : ""}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            comment.createdAt.toString().substring(0, 10),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        comment.content,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 24),
            ],

            // Savings History Section
            if (savingsHistoryProvider.history.isNotEmpty) ...[
              pw.Text(
                'Savings History Log',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfCell('Date/Time', isBold: true),
                      _pdfCell('Action', isBold: true),
                      _pdfCell('Amount', isBold: true),
                      _pdfCell('New Balance', isBold: true),
                      _pdfCell('Operator', isBold: true),
                    ],
                  ),
                  ...savingsHistoryProvider.history.map(
                    (entry) => pw.TableRow(
                      children: [
                        _pdfCell(entry.createdAt.toString().substring(0, 16)),
                        _pdfCell(entry.actionType),
                        _pdfCell('R ${entry.amount.toStringAsFixed(2)}'),
                        _pdfCell('R ${entry.newBalance.toStringAsFixed(2)}'),
                        _pdfCell(entry.updatedBy),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            pw.Text(
              'Financial Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStatItem('Total Loans', loans.length.toString()),
                _pdfStatItem('Total Paid', 'R ${totalPaid.toStringAsFixed(2)}'),
                _pdfStatItem(
                  'Outstanding',
                  'R ${(totalExpected - totalPaid).toStringAsFixed(2)}',
                ),
                _pdfStatItem('Account Status', 'Active'),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Loan History',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
            loans.isEmpty
                ? pw.Text(
                    'No loan history found.',
                    style: const pw.TextStyle(color: PdfColors.black),
                  )
                : pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey100,
                        ),
                        children: [
                          _pdfCell('Amount', isBold: true),
                          _pdfCell('Duration', isBold: true),
                          _pdfCell('Monthly', isBold: true),
                          _pdfCell('Balance', isBold: true),
                          _pdfCell('Status', isBold: true),
                        ],
                      ),
                      ...loans.map((loan) {
                        final loanPayments = vendorPayments
                            .where((p) => p.loanId == loan.id)
                            .toList();
                        final balance = LoanCalculationService.calculateBalance(
                          loan,
                          loanPayments,
                        );

                        return pw.TableRow(
                          children: [
                            _pdfCell('R ${loan.amount.toStringAsFixed(0)}'),
                            _pdfCell('${loan.durationMonths} Months'),
                            _pdfCell(
                              'R ${loan.monthlyPayment.toStringAsFixed(0)}',
                            ),
                            _pdfCell('R ${balance.toStringAsFixed(0)}'),
                            _pdfCell(loan.status),
                          ],
                        );
                      }),
                    ],
                  ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Payment History',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
            vendorPayments.isEmpty
                ? pw.Text(
                    'No payment history found.',
                    style: const pw.TextStyle(color: PdfColors.black),
                  )
                : pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey100,
                        ),
                        children: [
                          _pdfCell('Date', isBold: true),
                          _pdfCell('Amount', isBold: true),
                          _pdfCell('Method', isBold: true),
                          _pdfCell('Balance', isBold: true),
                        ],
                      ),
                      ...(() {
                        double currentRunningBalance =
                            totalExpected - totalPaid;
                        final sorted = List<PaymentModel>.from(vendorPayments)
                          ..sort((a, b) => b.datePaid.compareTo(a.datePaid));

                        return sorted.map((payment) {
                          final balanceAfterPayment = currentRunningBalance;
                          currentRunningBalance += payment.amountPaid;
                          return pw.TableRow(
                            children: [
                              _pdfCell(
                                payment.datePaid.toString().substring(0, 10),
                              ),
                              _pdfCell(
                                'R ${payment.amountPaid.toStringAsFixed(2)}',
                              ),
                              _pdfCell(payment.paymentMethod ?? 'Manual'),
                              _pdfCell(
                                'R ${balanceAfterPayment.toStringAsFixed(2)}',
                              ),
                            ],
                          );
                        }).toList();
                      })(),
                    ],
                  ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'All applicable fees are included in the amounts shown above.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Member_Profile_${vendor.name.replaceAll(' ', '_')}',
    );
  }

  static Future<void> exportSavingsHistoryPDF({
    required VendorModel vendor,
    required List<SavingsHistoryModel> history,
  }) async {
    final pdf = pw.Document();
    final logo = await PdfBranding.loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(logo, height: 40),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Savings Audit Log',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Member: ${vendor.name}'),
                pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}'),
              ],
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Date/Time', isBold: true),
                  _pdfCell('Action', isBold: true),
                  _pdfCell('Amount', isBold: true),
                  _pdfCell('New Balance', isBold: true),
                  _pdfCell('Operator', isBold: true),
                ],
              ),
              ...history
                  .map(
                    (entry) => pw.TableRow(
                      children: [
                        _pdfCell(entry.createdAt.toString().substring(0, 16)),
                        _pdfCell(entry.actionType),
                        _pdfCell('R ${entry.amount.toStringAsFixed(2)}'),
                        _pdfCell('R ${entry.newBalance.toStringAsFixed(2)}'),
                        _pdfCell(entry.updatedBy),
                      ],
                    ),
                  )
                  .toList(),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Savings_History_${vendor.name.replaceAll(' ', '_')}',
    );
  }

  static pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _pdfStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _pdfCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
