import 'package:flutter/material.dart';

import '../core/pdf_branding.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';

import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import '../models/payment.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import '../models/group.dart';
import '../providers/group_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().fetchPayments();
      context.read<VendorProvider>().fetchVendors();
      context.read<LoanProvider>().fetchLoans();
      context.read<GroupProvider>().fetchGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentProvider = context.watch<PaymentProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final vendorProvider = context.watch<VendorProvider>();
    final groupProvider = context.watch<GroupProvider>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payments History',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showGlobalRecordPaymentDialog(context),
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Record Payment'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: paymentProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : paymentProvider.payments.isEmpty
                  ? const Center(
                      child: Text(
                        'No payments recorded yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: paymentProvider.payments.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                      itemBuilder: (context, index) {
                        final payment = paymentProvider.payments[index];

                        final matchingLoans = loanProvider.loans.where(
                          (l) => l.id == payment.loanId,
                        );
                        final loan = matchingLoans.isNotEmpty
                            ? matchingLoans.first
                            : null;

                        final vendor = loan != null
                            ? vendorProvider.vendors
                                  .where((v) => v.id == loan.vendorId)
                                  .firstOrNull
                            : null;

                        final group = vendor != null
                            ? groupProvider.groups
                                  .where((g) => g.id == vendor.groupId)
                                  .firstOrNull
                            : null;

                        return ListTile(
                          onTap: () {
                            if (vendor != null &&
                                loan != null &&
                                group != null) {
                              _showPaymentDetailsDialog(
                                context,
                                payment,
                                loan,
                                vendor,
                                group,
                              );
                            }
                          },
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: const Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 14,
                            ),
                          ),
                          title: Text(
                            vendor != null
                                ? '${vendor.name} - R ${payment.amountPaid}'
                                : 'Payment of R ${payment.amountPaid}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Loan: L-${payment.loanId.substring(0, 8)} • Date: ${payment.datePaid.toString().substring(0, 10)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: const Text(
                            'Success',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGlobalRecordPaymentDialog(BuildContext context) {
    final vendorProvider = context.read<VendorProvider>();
    final loanProvider = context.read<LoanProvider>();

    VendorModel? selectedVendor;
    LoanModel? selectedLoan;
    String selectedType = 'Cash';
    final amountController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filteredVendors = vendorProvider.vendors
              .where(
                (v) => v.name.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .take(5)
              .toList();

          final memberLoans = selectedVendor != null
              ? loanProvider.loans
                    .where((l) => l.vendorId == selectedVendor!.id)
                    .toList()
              : <LoanModel>[];

          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text(
              'Record New Payment',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Search Member',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type name to search...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.05),
                    ),
                    onChanged: (val) => setState(() => searchQuery = val),
                  ),
                  if (searchQuery.isNotEmpty && selectedVendor == null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: filteredVendors
                            .map(
                              (v) => ListTile(
                                title: Text(
                                  v.name,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    selectedVendor = v;
                                    searchQuery = '';
                                    // Auto-select loan if only one exists
                                    final loans = loanProvider.loans
                                        .where((l) => l.vendorId == v.id)
                                        .toList();
                                    if (loans.length == 1) {
                                      selectedLoan = loans.first;
                                      amountController.text = selectedLoan!
                                          .monthlyPayment
                                          .toStringAsFixed(0);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (selectedVendor != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedVendor!.name,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() {
                              selectedVendor = null;
                              selectedLoan = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '2. Select Loan',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButtonFormField<LoanModel>(
                      value: selectedLoan,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      items: memberLoans
                          .map(
                            (l) => DropdownMenuItem(
                              value: l,
                              child: Text('Loan R ${l.amount} (${l.status})'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedLoan = val;
                          if (val != null)
                            amountController.text = val.monthlyPayment
                                .toStringAsFixed(0);
                        });
                      },
                    ),
                  ],
                  if (selectedLoan != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '3. Payment Type',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'EFT', child: Text('EFT')),
                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                      ],
                      onChanged: (val) =>
                          setState(() => selectedType = val ?? 'Cash'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '4. Payment Amount',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    TextField(
                      controller: amountController,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'R ',
                        prefixStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (selectedVendor != null && selectedLoan != null)
                    ? () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (amount > 0) {
                          await context.read<PaymentProvider>().addPayment(
                            PaymentModel(
                              id: '',
                              loanId: selectedLoan!.id,
                              amountPaid: amount,
                              paymentMethod: selectedType,
                              datePaid: DateTime.now(),
                              createdAt: DateTime.now(),
                            ),
                            loan: selectedLoan,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payment recorded successfully!'),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        }
                      }
                    : null,
                child: const Text('Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentDetailsDialog(
    BuildContext context,
    PaymentModel payment,
    LoanModel loan,
    VendorModel vendor,
    GroupModel group,
  ) {
    // Calculate balance at the time of payment
    final allLoanPayments =
        context
            .read<PaymentProvider>()
            .payments
            .where((p) => p.loanId == loan.id)
            .toList()
          ..sort((a, b) => a.datePaid.compareTo(b.datePaid));

    final totalExpected = (loan.monthlyPayment * loan.durationMonths) + (loan.initiationFee ?? 0);

    double runningBalance = totalExpected;
    double balanceAfterPayment = totalExpected;

    for (var p in allLoanPayments) {
      runningBalance -= p.amountPaid;
      if (p.id == payment.id) {
        balanceAfterPayment = runningBalance;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Payment Details',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Member Name', vendor.name),
                _buildDetailRow(
                  'Reference No.',
                  vendor.referenceNumber ?? 'N/A',
                ),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildDetailRow(
                  'Loan Reference',
                  'L-${loan.id.substring(0, 8)}',
                ),
                _buildDetailRow('Group Name', group.name),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildDetailRow(
                  'Payment Amount',
                  'R ${payment.amountPaid.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                _buildDetailRow(
                  'Payment Date',
                  payment.datePaid.toString().substring(0, 10),
                ),
                _buildDetailRow(
                  'Payment Method',
                  payment.paymentMethod ?? 'Manual',
                ),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _buildDetailRow(
                  'Updated Balance',
                  'R ${balanceAfterPayment.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Applicable Fees Included in Loan:',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                _buildDetailRow(
                  'Initiation Fee',
                  'R ${(loan.initiationFee ?? 0).toStringAsFixed(0)}',
                ),
                _buildDetailRow(
                  'Monthly Admin Fee',
                  'R ${(loan.monthlyAdminFee ?? 0).toStringAsFixed(0)} / mo',
                ),
                _buildDetailRow(
                  'Penalty Fee',
                  'R ${(loan.penaltyFee ?? 0).toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download PDF'),
            onPressed: () {
              Navigator.pop(context);
              _generatePaymentReceiptPDF(
                payment,
                loan,
                vendor,
                group,
                balanceAfterPayment,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight
                    ? Colors.amberAccent
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePaymentReceiptPDF(
    PaymentModel payment,
    LoanModel loan,
    VendorModel vendor,
    GroupModel group,
    double balanceAfterPayment,
  ) async {
    final pdf = pw.Document();

    final logo = await PdfBranding.loadLogo();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logo, height: 60),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Payment Receipt',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Receipt No: P-${payment.id.substring(0, 8).toUpperCase()}',
                      ),
                      pw.Text(
                        'Date: ${payment.datePaid.toString().substring(0, 10)}',
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              pw.Text(
                'Member Details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _pdfInfoRow('Name:', vendor.name),
              _pdfInfoRow('Reference No:', vendor.referenceNumber ?? 'N/A'),
              _pdfInfoRow('Group:', group.name),

              pw.SizedBox(height: 24),
              pw.Text(
                'Loan Details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _pdfInfoRow('Loan Reference:', 'L-${loan.id.substring(0, 8)}'),
              _pdfInfoRow(
                'Loan Amount:',
                'R ${loan.amount.toStringAsFixed(2)}',
              ),
              _pdfInfoRow(
                'Initiation Fee:',
                'R ${(loan.initiationFee ?? 0).toStringAsFixed(2)}',
              ),
              _pdfInfoRow(
                'Admin Fees:',
                'R ${((loan.monthlyAdminFee ?? 0) * loan.durationMonths).toStringAsFixed(2)} (Total)',
              ),

              pw.SizedBox(height: 24),
              pw.Text(
                'Payment Details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _pdfInfoRow(
                      'Amount Paid:',
                      'R ${payment.amountPaid.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    _pdfInfoRow(
                      'Payment Method:',
                      payment.paymentMethod ?? 'Manual',
                    ),
                    _pdfInfoRow(
                      'Payment Date:',
                      payment.datePaid.toString().substring(0, 10),
                    ),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    _pdfInfoRow(
                      'Remaining Balance:',
                      'R ${balanceAfterPayment.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Text(
                'All applicable fees are included in the amounts shown above.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.black),
              ),
              pw.Text(
                'Thank you for your business.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Payment_Receipt_${payment.id.substring(0, 8)}',
    );
  }

  pw.Widget _pdfInfoRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
