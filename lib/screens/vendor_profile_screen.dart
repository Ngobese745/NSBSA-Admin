import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/vendor.dart';
import '../models/group.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../providers/vendor_provider.dart';
import '../providers/group_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';

class VendorProfileScreen extends StatefulWidget {
  final VendorModel vendor;

  const VendorProfileScreen({super.key, required this.vendor});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  late VendorModel _currentVendor;
  List<LoanModel> _loans = [];
  List<PaymentModel> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentVendor = widget.vendor;
    _loadData();
  }

  Future<void> _loadData() async {
    final loanProvider = context.read<LoanProvider>();

    await loanProvider.fetchLoans();
    final vendorLoans = loanProvider.loans
        .where((l) => l.vendorId == _currentVendor.id)
        .toList();

    if (mounted) {
      setState(() {
        _loans = vendorLoans;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.read<GroupProvider>();
    final paymentProvider = context.watch<PaymentProvider>();

    // Filter payments for this vendor's loans reactively
    final loanIds = _loans.map((l) => l.id).toSet();
    final vendorPayments = paymentProvider.payments
        .where((p) => loanIds.contains(p.loanId))
        .toList();

    double totalPaid = vendorPayments.fold(0, (sum, p) => sum + p.amountPaid);
    final group = groupProvider.groups.firstWhere(
      (g) => g.id == _currentVendor.groupId,
      orElse: () => GroupModel(
        id: '',
        name: 'Unknown Group',
        referenceNumber: '',
        createdAt: DateTime.now(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            onPressed: () => _generateProfilePDF(context, group),
            tooltip: 'Download Profile PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Basic Info & Details
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainHeader(theme, group),
                        const SizedBox(height: 24),
                        _buildInformationSection(theme),
                        const SizedBox(height: 24),
                        _buildFinancialSummary(theme, totalPaid),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Right Column: History Lists
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHistorySection(
                          theme,
                          'My Loan History',
                          _loans,
                          true,
                        ),
                        const SizedBox(height: 24),
                        _buildHistorySection(
                          theme,
                          'My Payment History',
                          vendorPayments,
                          false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMainHeader(ThemeData theme, GroupModel group) {
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
            child: Icon(Icons.person, size: 35, color: theme.primaryColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currentVendor.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: theme.primaryColor,
                      ),
                      onPressed: () => _showEditVendorDialog(context),
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Group: ${group.name}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentVendor.referenceNumber ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Information',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            'Phone',
            _currentVendor.phone ?? 'N/A',
            Icons.phone_outlined,
          ),
          _buildInfoRow(
            'ID Number',
            _currentVendor.idNumber ?? 'N/A',
            Icons.badge_outlined,
          ),
          _buildInfoRow(
            'Business',
            _currentVendor.businessType ?? 'N/A',
            Icons.business_center_outlined,
          ),
          _buildInfoRow(
            'Gender',
            _currentVendor.gender ?? 'N/A',
            Icons.person_outline,
          ),
          _buildInfoRow(
            'DF Name',
            _currentVendor.dfName ?? 'N/A',
            Icons.assignment_ind_outlined,
          ),
          _buildInfoRow(
            'WhatsApp',
            _currentVendor.whatsappNumber ?? 'N/A',
            Icons.chat_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(ThemeData theme, double totalPaid) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Loans', _loans.length.toString()),
              _buildStatItem(
                'Total Payments',
                'R ${totalPaid.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _generateProfilePDF(
    BuildContext context,
    GroupModel group,
  ) async {
    final paymentProvider = context.read<PaymentProvider>();
    final pdf = pw.Document();

    // Load logo
    final logoImage = await rootBundle.load('assets/images/NSBSA Logo (1).png');
    final logo = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Filter payments for this vendor's loans
    final loanIds = _loans.map((l) => l.id).toSet();
    final vendorPayments = paymentProvider.payments
        .where((p) => loanIds.contains(p.loanId))
        .toList();
    double totalPaid = vendorPayments.fold(0, (sum, p) => sum + p.amountPaid);
    final totalExpected = _loans.fold(
      0.0,
      (sum, loan) =>
          sum +
          loan.amount +
          (loan.initiationFee ?? 0) +
          ((loan.monthlyAdminFee ?? 0) * loan.durationMonths),
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
                  pw.Text(
                    'Reference: ${_currentVendor.referenceNumber ?? 'N/A'}',
                  ),
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
                      _pdfInfoRow('Name', _currentVendor.name),
                      _pdfInfoRow('Group', group.name),
                      _pdfInfoRow('Phone', _currentVendor.phone ?? 'N/A'),
                      _pdfInfoRow(
                        'WhatsApp',
                        _currentVendor.whatsappNumber ?? 'N/A',
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfInfoRow(
                        'ID Number',
                        _currentVendor.idNumber ?? 'N/A',
                      ),
                      _pdfInfoRow(
                        'Business',
                        _currentVendor.businessType ?? 'N/A',
                      ),
                      _pdfInfoRow('Gender', _currentVendor.gender ?? 'N/A'),
                      _pdfInfoRow('DF Name', _currentVendor.dfName ?? 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Financial Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStatItem('Total Loans', _loans.length.toString()),
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
            _loans.isEmpty
                ? pw.Text(
                    'No loan history found.',
                    style: const pw.TextStyle(color: PdfColors.grey),
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
                      ..._loans.map((loan) {
                        final loanPayments = vendorPayments
                            .where((p) => p.loanId == loan.id)
                            .toList();
                        final totalPaidForLoan = loanPayments.fold(
                          0.0,
                          (sum, p) => sum + p.amountPaid,
                        );
                        final balance =
                            (loan.amount +
                                (loan.initiationFee ?? 0) +
                                ((loan.monthlyAdminFee ?? 0) *
                                    loan.durationMonths)) -
                            totalPaidForLoan;

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
                      }).toList(),
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
                    style: const pw.TextStyle(color: PdfColors.grey),
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
                      color: PdfColors.grey700,
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
      name: 'Member_Profile_${_currentVendor.name.replaceAll(' ', '_')}',
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
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

  pw.Widget _pdfStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _pdfCell(String text, {bool isBold = false}) {
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

  Widget _buildHistorySection(
    ThemeData theme,
    String title,
    List items,
    bool isLoans,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No $title found.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.dividerColor,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (isLoans) {
                      final loan = item as LoanModel;
                      return ListTile(
                        dense: true,
                        title: Text(
                          'Loan R ${loan.amount}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${loan.durationMonths} Months • ${loan.status}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R ${loan.monthlyPayment}/mo',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.payment,
                                size: 20,
                                color: Colors.greenAccent,
                              ),
                              onPressed: () =>
                                  _showRecordPaymentDialog(context, loan),
                              tooltip: 'Record Payment',
                            ),
                          ],
                        ),
                      );
                    } else {
                      final payment = item as PaymentModel;
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 18,
                        ),
                        title: Text('Payment R ${payment.amountPaid}'),
                        subtitle: Text(
                          '${payment.datePaid.toString().substring(0, 10)} • ${payment.paymentMethod ?? 'Cash'}',
                        ),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  void _showEditVendorDialog(BuildContext context) {
    final nameController = TextEditingController(text: _currentVendor.name);
    final phoneController = TextEditingController(text: _currentVendor.phone);
    final idController = TextEditingController(text: _currentVendor.idNumber);
    final businessController = TextEditingController(
      text: _currentVendor.businessType,
    );
    final dfNameController = TextEditingController(text: _currentVendor.dfName);
    final whatsappController = TextEditingController(
      text: _currentVendor.whatsappNumber,
    );
    String selectedGender = _currentVendor.gender ?? 'F';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Edit Member Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: whatsappController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: InputDecoration(
                            labelText: 'WhatsApp',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: idController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: InputDecoration(
                            labelText: 'ID Number',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('M')),
                            DropdownMenuItem(value: 'F', child: Text('F')),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedGender = val ?? 'F'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: businessController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Business Type',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dfNameController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: 'DF Name',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedData = {
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'id_number': idController.text,
                  'business_type': businessController.text,
                  'gender': selectedGender,
                  'df_name': dfNameController.text,
                  'whatsapp_number': whatsappController.text,
                };

                try {
                  await context.read<VendorProvider>().updateVendor(
                    _currentVendor.id,
                    updatedData,
                  );

                  if (context.mounted) {
                    setState(() {
                      _currentVendor = VendorModel(
                        id: _currentVendor.id,
                        groupId: _currentVendor.groupId,
                        name: nameController.text,
                        phone: phoneController.text,
                        referenceNumber: _currentVendor.referenceNumber,
                        idNumber: idController.text,
                        gender: selectedGender,
                        businessType: businessController.text,
                        whatsappNumber: whatsappController.text,
                        dfName: dfNameController.text,
                        createdAt: _currentVendor.createdAt,
                      );
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                      ),
                    );
                    Navigator.pop(context);

                    // Trigger a rebuild of the profile screen
                    this.setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating profile: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, LoanModel loan) {
    final amountController = TextEditingController(
      text: loan.monthlyPayment.toStringAsFixed(0),
    );

    String selectedType = 'Cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Record Loan Payment',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the amount received for Loan R ${loan.amount}.',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Type',
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
                'Amount Paid',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: InputDecoration(
                  prefixText: 'R ',
                  prefixStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  await context.read<PaymentProvider>().addPayment(
                    PaymentModel(
                      id: '',
                      loanId: loan.id,
                      amountPaid: amount,
                      paymentMethod: selectedType,
                      datePaid: DateTime.now(),
                      createdAt: DateTime.now(),
                    ),
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
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
