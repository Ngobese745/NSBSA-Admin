import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../models/group.dart';
import '../models/payment.dart';
import '../models/vendor.dart';
import '../providers/group_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../services/loan_calculation_service.dart';

class LoanDetailsScreen extends StatelessWidget {
  final LoanModel loan;

  const LoanDetailsScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.read<GroupProvider>();
    final vendorProvider = context.read<VendorProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    
    final group = groupProvider.groups.firstWhere(
      (g) => g.id == loan.groupId,
      orElse: () => GroupModel(id: '', name: 'Unknown Group', referenceNumber: '', createdAt: DateTime.now()),
    );

    final vendor = loan.vendorId != null 
      ? vendorProvider.vendors.where((v) => v.id == loan.vendorId).firstOrNull
      : null;

    final loanPayments = paymentProvider.payments.where((p) => p.loanId == loan.id).toList();
    double totalPaid = loanPayments.fold(0, (sum, p) => sum + p.amountPaid);
    double balance = LoanCalculationService.calculateBalance(loan, loanPayments);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generateLoanPDF(context, group, vendor, totalPaid, balance, loanPayments),
            tooltip: 'Download Statement',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditLoanDialog(context),
            tooltip: 'Edit Loan',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirmation(context),
            tooltip: 'Delete Loan',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Main Stats & Information
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLoanHeader(context, theme, group, vendor),
                  const SizedBox(height: 24),
                  _buildFinancialGrid(theme, totalPaid, balance),
                  const SizedBox(height: 24),
                  _buildFeeDetails(theme, loanPayments),
                ],
              ),
            ),
            const SizedBox(width: 40),
            // Right Column: Payment History
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPaymentHistory(theme, loanPayments),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanHeader(BuildContext context, ThemeData theme, GroupModel group, dynamic vendor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            child: Icon(Icons.account_balance, size: 35, color: theme.primaryColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vendor != null) ...[
                  Text(
                    vendor.name,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Group: ${group.name}',
                    style: TextStyle(color: theme.primaryColor, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ] else
                  Text(
                    'Group: ${group.name}',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Loan ID: L-${loan.id.substring(0, 8)}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: loan.status == 'Active' ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    loan.status.toUpperCase(),
                    style: TextStyle(
                      color: loan.status == 'Active' ? Colors.green : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showRecordPaymentDialog(context),
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Record Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context) {
    final amountController = TextEditingController(text: loan.monthlyPayment.toStringAsFixed(0));
    String selectedType = 'Cash';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Record Loan Payment', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the amount received for this loan repayment.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text('Payment Type', style: TextStyle(color: Colors.grey, fontSize: 12)),
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'EFT', child: Text('EFT')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                ],
                onChanged: (val) => setState(() => selectedType = val ?? 'Cash'),
              ),
              const SizedBox(height: 16),
              const Text('Amount Paid', style: TextStyle(color: Colors.grey, fontSize: 12)),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  prefixText: 'R ',
                  prefixStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  await context.read<PaymentProvider>().addPayment(PaymentModel(
                    id: '',
                    loanId: loan.id,
                    amountPaid: amount,
                    paymentMethod: selectedType,
                    datePaid: DateTime.now(),
                    createdAt: DateTime.now(),
                  ));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment recorded successfully!')),
                    );
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialGrid(ThemeData theme, double totalPaid, double balance) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSimpleStat('Loan Amount', 'R ${loan.amount.toStringAsFixed(0)}', theme)),
            const SizedBox(width: 16),
            Expanded(child: _buildSimpleStat('Monthly Payment', 'R ${loan.monthlyPayment.toStringAsFixed(0)}', theme)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSimpleStat('Total Paid', 'R ${totalPaid.toStringAsFixed(0)}', theme, color: Colors.greenAccent)),
            const SizedBox(width: 16),
            Expanded(child: _buildSimpleStat('Est. Balance', 'R ${balance.toStringAsFixed(0)}', theme, color: Colors.amberAccent)),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleStat(String label, String value, ThemeData theme, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFeeDetails(ThemeData theme, List<PaymentModel> payments) {
    final appliedPenalty = LoanCalculationService.calculateAppliedPenalty(loan, payments);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fee Structure & Dates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildInfoRow('Initiation Fee', 'R ${loan.initiationFee?.toStringAsFixed(0) ?? '0'}'),
          _buildInfoRow('Monthly Admin Fee', 'R ${loan.monthlyAdminFee?.toStringAsFixed(0) ?? '0'}'),
          _buildInfoRow('Applied Penalty', 'R ${appliedPenalty.toStringAsFixed(0)}', isValueBold: appliedPenalty > 0, valueColor: appliedPenalty > 0 ? Colors.redAccent : null),
          _buildInfoRow('Opening Amount', 'R ${loan.openingAmount?.toStringAsFixed(0) ?? '0'}'),
          _buildInfoRow('Term Duration', '${loan.durationMonths} Months'),
          _buildInfoRow('First Instalment', loan.firstInstalmentDate?.toString().substring(0, 10) ?? 'N/A'),
          _buildInfoRow('Created On', loan.createdAt.toString().substring(0, 10)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isValueBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500, fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(ThemeData theme, List<PaymentModel> payments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loan Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: payments.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No payments recorded for this loan.', style: TextStyle(color: Colors.grey))),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                    title: Text('Payment R ${payment.amountPaid.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Date: ${payment.datePaid.toString().substring(0, 10)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      onPressed: () async {
                        // Confirm deletion of payment
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            title: const Text('Delete Payment?'),
                            content: const Text('Are you sure you want to delete this payment?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          try {
                            await context.read<PaymentProvider>().deletePayment(payment.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment deleted successfully')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        }
                      },
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Theme.of(c).colorScheme.surface,
        title: const Text('Delete Loan', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Are you sure you want to permanently delete this loan? This action cannot be undone.\n\n'
          'WARNING: All associated payments will be deleted as well.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await context.read<LoanProvider>().deleteLoan(loan.id);
                if (context.mounted) {
                  Navigator.pop(c); // close dialog
                  Navigator.pop(context); // close screen
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan deleted successfully')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditLoanDialog(BuildContext context) {
    final amountController = TextEditingController(text: loan.amount.toStringAsFixed(0));
    final termController = TextEditingController(text: loan.durationMonths.toString());
    final initFeeController = TextEditingController(text: loan.initiationFee?.toStringAsFixed(0) ?? '0');
    final adminFeeController = TextEditingController(text: loan.monthlyAdminFee?.toStringAsFixed(0) ?? '0');
    final penaltyController = TextEditingController(text: loan.penaltyFee?.toStringAsFixed(0) ?? '0');
    final monthlyController = TextEditingController(text: loan.monthlyPayment.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          backgroundColor: Theme.of(c).colorScheme.surface,
          title: const Text('Edit Loan', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Principal Amount (R)', labelStyle: TextStyle(color: Colors.grey)),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: termController,
                  decoration: const InputDecoration(labelText: 'Term (Months)', labelStyle: TextStyle(color: Colors.grey)),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: initFeeController,
                  decoration: const InputDecoration(labelText: 'Initiation Fee (R)', labelStyle: TextStyle(color: Colors.grey)),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: adminFeeController,
                  decoration: const InputDecoration(labelText: 'Monthly Admin Fee (R)', labelStyle: TextStyle(color: Colors.grey)),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: penaltyController,
                  decoration: const InputDecoration(labelText: 'Penalty Fee (R)', labelStyle: TextStyle(color: Colors.grey)),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: monthlyController,
                  decoration: const InputDecoration(labelText: 'Monthly Instalment (R)', labelStyle: TextStyle(color: Colors.grey)),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? loan.amount;
                final term = int.tryParse(termController.text) ?? loan.durationMonths;
                final initFee = double.tryParse(initFeeController.text) ?? loan.initiationFee;
                final adminFee = double.tryParse(adminFeeController.text) ?? loan.monthlyAdminFee;
                final penalty = double.tryParse(penaltyController.text) ?? loan.penaltyFee;
                final monthly = double.tryParse(monthlyController.text) ?? loan.monthlyPayment;

                try {
                  await context.read<LoanProvider>().updateLoan(loan.id, {
                    'amount': amount,
                    'duration_months': term,
                    'initiation_fee': initFee,
                    'monthly_admin_fee': adminFee,
                    'penalty_fee': penalty,
                    'monthly_payment': monthly,
                  });
                  if (context.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan updated successfully. Please close and re-open to see changes.')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateLoanPDF(BuildContext context, GroupModel group, VendorModel? vendor, double totalPaid, double balance, List<PaymentModel> payments) async {
    final pdf = pw.Document();
    
    ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoData = bytes.buffer.asUint8List();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(pw.MemoryImage(logoData), width: 120),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('LOAN STATEMENT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFD4AF37))),
                    pw.SizedBox(height: 4),
                    pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(color: PdfColors.grey700)),
                    pw.Text('Loan ID: L-${loan.id.substring(0, 8)}', style: const pw.TextStyle(color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            
            // Info Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Member Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFD4AF37))),
                      pw.Divider(color: const PdfColor.fromInt(0xFFD4AF37)),
                      pw.Text('Name: ${vendor?.name ?? 'Unknown'}'),
                      pw.Text('ID Number: ${vendor?.idNumber ?? '-'}'),
                      pw.Text('Phone: ${vendor?.phone ?? '-'}'),
                    ]
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Group Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFD4AF37))),
                      pw.Divider(color: const PdfColor.fromInt(0xFFD4AF37)),
                      pw.Text('Name: ${group.name}'),
                      pw.Text('Ref: ${group.referenceNumber}'),
                    ]
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Financial Summary
            pw.Text('Financial Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Principal: R ${loan.amount.toStringAsFixed(0)}'),
                      pw.Text('Monthly: R ${loan.monthlyPayment.toStringAsFixed(0)}'),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Paid: R ${totalPaid.toStringAsFixed(0)}', style: const pw.TextStyle(color: PdfColors.green700)),
                      pw.Text('Balance: R ${balance.toStringAsFixed(0)}', style: pw.TextStyle(color: PdfColors.orange700, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 30),

            // Payment History Table
            pw.Text('Payment History', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Method', 'Amount'],
              data: payments.map((p) => [
                p.datePaid.toString().substring(0, 10),
                p.paymentMethod ?? 'Unknown',
                'R ${p.amountPaid.toStringAsFixed(2)}'
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2C2C2C)),
              cellPadding: const pw.EdgeInsets.all(6),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Loan_Statement_${vendor?.name.replaceAll(" ", "_") ?? "Unknown"}.pdf',
    );
  }
}
