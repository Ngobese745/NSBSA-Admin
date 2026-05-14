import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_breakpoints.dart';
import '../core/pdf_branding.dart';
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
import '../models/comment.dart';
import '../providers/comment_provider.dart';
import '../providers/auth_provider.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../providers/analytics_provider.dart';
import '../services/loan_calculation_service.dart';
import '../models/savings_history.dart';
import '../providers/savings_history_provider.dart';
import '../services/vendor_pdf_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/excel_export_service.dart';

import '../widgets/communication/communication_dialog.dart';

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
    final vendorProvider = context.read<VendorProvider>();

    await loanProvider.fetchLoans();

    // Find the latest vendor data from provider
    final updatedVendor = vendorProvider.vendors.firstWhere(
      (v) => v.id == _currentVendor.id,
      orElse: () => _currentVendor,
    );

    final vendorLoans = loanProvider.loans
        .where((l) => l.vendorId == _currentVendor.id)
        .toList();

    await context.read<CommentProvider>().fetchCommentsByVendor(
      _currentVendor.id,
    );
    await context.read<DocumentProvider>().fetchDocumentsByVendor(
      _currentVendor.id,
    );
    await context.read<SavingsHistoryProvider>().fetchHistoryByVendor(
      _currentVendor.id,
    );

    // Fetch data for analytics calculation
    final groupProvider = context.read<GroupProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();

    // Ensure all data is present for score calculation
    analyticsProvider.calculateAnalytics(
      groups: groupProvider.groups,
      vendors: vendorProvider.vendors,
      loans: context.read<LoanProvider>().loans,
      payments: context.read<PaymentProvider>().payments,
    );

    if (mounted) {
      setState(() {
        _currentVendor = updatedVendor;
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
    final vendorProvider = context.watch<VendorProvider>();

    // Derive current vendor from provider reactively
    final currentVendor = vendorProvider.vendors.firstWhere(
      (v) => v.id == widget.vendor.id,
      orElse: () => _currentVendor,
    );

    // Filter payments for this vendor's loans reactively
    final loanIds = _loans.map((l) => l.id).toSet();
    final vendorPayments = paymentProvider.payments
        .where((p) => loanIds.contains(p.loanId))
        .toList();

    double totalPaid = vendorPayments.fold(0, (sum, p) => sum + p.amountPaid);
    final group = groupProvider.groups.firstWhere(
      (g) => g.id == currentVendor.groupId,
      orElse: GroupModel.unknown,
    );

    final isDesktop =
        MediaQuery.of(context).size.width >=
        AppBreakpoints.vendorProfileDesktopMin;
    final isTablet =
        MediaQuery.of(context).size.width >=
        AppBreakpoints.vendorProfileTabletMin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CommunicationDialog(vendor: currentVendor),
              );
            },
            tooltip: 'Send Message',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditVendorDialog(context),
            tooltip: 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            onPressed: () => VendorPdfService.generateProfilePDF(
              context: context,
              vendor: currentVendor,
              group: group,
              loans: _loans,
            ),
            tooltip: 'Download Profile PDF',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 16,
                vertical: 24,
              ),
              child: Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Basic Info & Details
                  Flexible(
                    flex: isDesktop ? 2 : 0,
                    fit: isDesktop ? FlexFit.tight : FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainHeader(theme, group, isDesktop, currentVendor),
                        const SizedBox(height: 24),
                        _buildInformationSection(theme, isTablet, currentVendor),
                        const SizedBox(height: 24),
                        _buildFinancialSummary(theme, totalPaid, isTablet),
                        if (!isDesktop) const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  if (isDesktop) const SizedBox(width: 40),
                  // Right Column: History Lists
                  Flexible(
                    flex: isDesktop ? 3 : 0,
                    fit: isDesktop ? FlexFit.tight : FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHistorySection(theme, 'Active Loans', _loans.where((l) => l.status == 'Active').toList(), true, currentVendor),
                        const SizedBox(height: 24),
                        _buildHistorySection(theme, 'Payment History', vendorPayments, false, currentVendor),
                        const SizedBox(height: 24),
                        _buildSavingsHistorySection(theme, currentVendor),
                        const SizedBox(height: 24),
                        _buildCommentsSection(theme, currentVendor),
                        const SizedBox(height: 24),
                        _buildDocumentsSection(theme, currentVendor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentsSection(ThemeData theme, VendorModel currentVendor) {
    final docProvider = context.watch<DocumentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Supporting Documents',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            ElevatedButton.icon(
              onPressed: docProvider.isLoading
                  ? null
                  : () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        type: FileType.custom,
                        allowedExtensions: [
                          'pdf',
                          'jpg',
                          'jpeg',
                          'png',
                          'doc',
                          'docx',
                        ],
                      );

                      if (result != null) {
                        try {
                          int count = 0;
                          for (var file in result.files) {
                            if (file.bytes != null) {
                              await docProvider.uploadDocument(
                                vendorId: currentVendor.id,
                                fileName: file.name,
                                fileBytes: file.bytes!,
                              );
                              count++;
                            }
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Successfully uploaded $count document(s)',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Upload failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      }
                    },
              icon: docProvider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(docProvider.isLoading ? 'Uploading...' : 'Upload'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: docProvider.isLoading && docProvider.documents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : docProvider.documents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No documents uploaded yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docProvider.documents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final doc = docProvider.documents[index];
                    return ListTile(
                      leading: Icon(
                        _getFileIcon(doc.fileType),
                        color: theme.primaryColor,
                      ),
                      title: Text(
                        doc.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Uploaded: ${doc.uploadedAt.toString().substring(0, 16)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.open_in_new,
                              size: 20,
                              color: Colors.blueAccent,
                            ),
                            onPressed: () {
                              final url = docProvider.getPublicUrl(
                                doc.filePath,
                              );
                              launchUrl(Uri.parse(url));
                            },
                            tooltip: 'View Document',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => docProvider.deleteDocument(doc),
                            tooltip: 'Delete Document',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _exportLoansToExcel(VendorModel currentVendor) async {
    final paymentProvider = context.read<PaymentProvider>();
    List<Map<String, dynamic>> loanData = [];

    for (var loan in _loans) {
      final loanPayments = paymentProvider.payments.where((p) => p.loanId == loan.id).toList();
      final totalPaid = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
      final liability = loan.amount +
          (loan.initiationFee ?? 0) +
          ((loan.monthlyAdminFee ?? 0) * loan.durationMonths) +
          LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);
      final balance = liability - totalPaid;
      final arrears = LoanCalculationService.calculateArrears(loan, loanPayments);

      loanData.add({
        'date': loan.createdAt.toString().substring(0, 10),
        'amount': loan.amount,
        'type': loan.loanType ?? 'Standard',
        'duration': loan.durationMonths,
        'status': loan.status,
        'totalPaid': totalPaid,
        'arrears': arrears,
        'balance': balance,
      });
    }

    await ExcelExportService.exportLoanHistory(
      memberName: currentVendor.name,
      loanData: loanData,
    );
  }

  Widget _buildCommentsSection(ThemeData theme, VendorModel currentVendor) {
    final commentProvider = context.watch<CommentProvider>();
    final TextEditingController _commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Comments & Mentions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Comment Input
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _commentController,
                      maxLines: 2,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a personal note...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        fillColor: theme.scaffoldBackgroundColor,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_commentController.text.trim().isEmpty) return;

                          final authProvider = context.read<AuthProvider>();
                          final comment = CommentModel(
                            id: '',
                            vendorId: currentVendor.id,
                            authorName:
                                authProvider.currentUser?.email ?? 'Admin',
                            authorRole: 'Staff',
                            content: _commentController.text.trim(),
                            createdAt: DateTime.now(),
                          );

                          await commentProvider.addComment(comment);
                          _commentController.clear();
                          (context as Element).markNeedsBuild();
                        },
                        child: const Text('Add Note'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Comments List
              if (commentProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (commentProvider.comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No comments yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: commentProvider.comments.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final comment = commentProvider.comments[index];
                    final isMention = comment.mentionedVendorIds.contains(
                      _currentVendor.id,
                    );

                    return InkWell(
                      onTap: () => _showCommentDetailsDialog(comment, currentVendor),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isMention)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Mentioned',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  comment.createdAt.toString().substring(0, 16),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              comment.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainHeader(ThemeData theme, GroupModel group, bool isDesktop, VendorModel currentVendor) {
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final score =
        analyticsProvider.vendorCreditScores[currentVendor.id] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isDesktop
          ? Row(
              children: [
                _buildVendorAvatar(theme),
                const SizedBox(width: 24),
                Expanded(child: _buildVendorTitle(theme, group, isDesktop, currentVendor)),
                const SizedBox(width: 24),
                _buildCreditBadge(score),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    _buildVendorAvatar(theme, radius: 25),
                    const SizedBox(width: 16),
                    Expanded(child: _buildVendorTitle(theme, group, isDesktop, currentVendor)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildCreditBadge(score),
              ],
            ),
    );
  }

  Widget _buildVendorAvatar(ThemeData theme, {double radius = 35}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.primaryColor.withOpacity(0.1),
      child: Icon(Icons.person, size: radius * 0.9, color: theme.primaryColor),
    );
  }

  Widget _buildVendorTitle(ThemeData theme, GroupModel group, bool isDesktop, VendorModel currentVendor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentVendor.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isDesktop ? 24 : 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Group: ${group.name}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        SelectableText(
          'GRP-${group.id}',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditBadge(double score) {
    String status = score > 85
        ? 'Excellent'
        : (score > 60 ? 'Moderate' : 'High Risk');
    Color statusColor = score > 85
        ? Colors.greenAccent
        : (score > 60 ? Colors.amberAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Credit Profile Score',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInformationSection(ThemeData theme, bool isTablet, VendorModel currentVendor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                'Role',
                currentVendor.role ?? 'Member',
                Icons.stars_outlined,
              ),
              _buildInfoRow(
                'Home Address',
                currentVendor.address ?? 'N/A',
                Icons.location_on_outlined,
              ),
              _buildInfoRow(
                'Phone',
                currentVendor.phone ?? 'N/A',
                Icons.phone_outlined,
              ),
              _buildInfoRow(
                'ID Number',
                currentVendor.idNumber ?? 'N/A',
                Icons.badge_outlined,
              ),
              _buildInfoRow(
                'Business',
                currentVendor.businessType ?? 'N/A',
                Icons.business_center_outlined,
              ),
              _buildInfoRow(
                'Email',
                currentVendor.email ?? 'N/A',
                Icons.email_outlined,
              ),
              InkWell(
                onTap: () => _showUpdateSavingsDialog(context, currentVendor),
                borderRadius: BorderRadius.circular(8),
                child: _buildInfoRow(
                  'Savings Balance',
                  'R ${currentVendor.savingsAmount?.toStringAsFixed(2) ?? '0.00'}',
                  Icons.savings_outlined,
                  trailing: const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              ),
              if (context.watch<SavingsHistoryProvider>().history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 0, left: 30),
                  child: Text(
                    'Last updated: ${context.watch<SavingsHistoryProvider>().history.first.createdAt.toString().substring(0, 16)} by ${context.watch<SavingsHistoryProvider>().history.first.updatedBy}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(
    ThemeData theme,
    double totalPaid,
    bool isTablet,
  ) {
    final paymentProvider = context.read<PaymentProvider>();
    final allPayments = paymentProvider.payments;

    double totalLiability = 0;
    for (var loan in _loans) {
      final loanPayments = allPayments
          .where((p) => p.loanId == loan.id)
          .toList();
      totalLiability +=
          loan.amount +
          (loan.initiationFee ?? 0) +
          ((loan.monthlyAdminFee ?? 0) * loan.durationMonths) +
          LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);
    }

    final outstanding = totalLiability - totalPaid;
    final activeLoans = _loans.where((l) => l.status == 'Active').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Summary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
              children: [
                _buildSummaryTile(
                  'Total Paid',
                  'R ${totalPaid.toStringAsFixed(0)}',
                  Colors.greenAccent,
                ),
                _buildSummaryTile(
                  'Outstanding',
                  'R ${outstanding.toStringAsFixed(0)}',
                  Colors.redAccent,
                ),
                _buildSummaryTile(
                  'Active',
                  activeLoans.toString(),
                  Colors.blueAccent,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildHistorySection(
    ThemeData theme,
    String title,
    List items,
    bool isLoans,
    VendorModel currentVendor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (isLoans && items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.download_for_offline, color: Colors.amber, size: 20),
                onPressed: () => _exportLoansToExcel(currentVendor),
                tooltip: 'Export Loans to Excel',
              ),
          ],
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
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (isLoans) {
                      final loan = item as LoanModel;
                      final paymentProvider = context.read<PaymentProvider>();
                      final loanPayments = paymentProvider.payments.where((p) => p.loanId == loan.id).toList();
                      
                      final totalPaid = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
                      final liability = loan.amount + (loan.initiationFee ?? 0) + ((loan.monthlyAdminFee ?? 0) * loan.durationMonths) + LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);
                      final balance = liability - totalPaid;
                      final arrears = LoanCalculationService.calculateArrears(loan, loanPayments);
                      
                      final isOverdue = loan.status == 'Overdue' || arrears > 0;
                      
                      return ExpansionTile(
                        title: Text(
                          'Loan R ${loan.amount}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${loan.durationMonths} Months • ${loan.status}',
                          style: TextStyle(
                            color: isOverdue ? Colors.redAccent : Colors.grey,
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bal: R ${balance.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: balance <= 0 ? Colors.greenAccent : theme.primaryColor,
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.black12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildDetailItem('Arrears', 'R ${arrears.toStringAsFixed(0)}', arrears > 0 ? Colors.redAccent : Colors.greenAccent),
                                    _buildDetailItem('Next Due', LoanCalculationService.nextPaymentDate(loan)?.toString().substring(0, 10) ?? 'N/A', Colors.white70),
                                    _buildDetailItem('Total Paid', 'R ${totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text('Repayments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 8),
                                if (loanPayments.isEmpty)
                                  const Text('No payments recorded.', style: TextStyle(color: Colors.grey, fontSize: 11))
                                else
                                  ...loanPayments.map((p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(p.datePaid.toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text('R ${p.amountPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                                      ],
                                    ),
                                  )),
                              ],
                            ),
                          )
                        ],
                      );
                    } else {
                      final payment = item as PaymentModel;
                      return ListTile(
                        onTap: () {
                          final loanProvider = context.read<LoanProvider>();
                          final groupProvider = context.read<GroupProvider>();

                          final loan = loanProvider.loans
                              .where((l) => l.id == payment.loanId)
                              .firstOrNull;
                          final group = groupProvider.groups
                              .where((g) => g.id == currentVendor.groupId)
                              .firstOrNull;

                          if (loan != null && group != null) {
                            _showPaymentDetailsDialog(
                              context,
                              payment,
                              loan,
                              _currentVendor,
                              group,
                            );
                          }
                        },
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

  String _selectedActionFilter = 'All';

  Widget _buildSavingsHistorySection(ThemeData theme, VendorModel currentVendor) {
    final historyProvider = context.watch<SavingsHistoryProvider>();
    final history = historyProvider.history.where((e) {
      if (_selectedActionFilter == 'All') return true;
      return e.actionType == _selectedActionFilter;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Savings History Log',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _selectedActionFilter,
              underline: const SizedBox(),
              dropdownColor: theme.cardColor,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              icon: const Icon(Icons.filter_list, size: 16, color: Colors.grey),
              items: ['All', 'Deposit', 'Withdrawal', 'Adjustment']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedActionFilter = val!),
            ),
            if (history.isNotEmpty)
              IconButton(
                onPressed: () => VendorPdfService.exportSavingsHistoryPDF(
                  vendor: _currentVendor,
                  history: history,
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                tooltip: 'Export PDF',
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No matching history found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      horizontalMargin: 16,
                      headingRowHeight: 40,
                      dataRowHeight: 52,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber,
                      ),
                      columns: const [
                        DataColumn(label: Text('Date/Time')),
                        DataColumn(label: Text('Action')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('New Balance')),
                        DataColumn(label: Text('Operator')),
                      ],
                      rows: history.map((entry) {
                        Color actionColor;
                        switch (entry.actionType) {
                          case 'Deposit':
                            actionColor = Colors.greenAccent;
                            break;
                          case 'Withdrawal':
                            actionColor = Colors.redAccent;
                            break;
                          default:
                            actionColor = Colors.amberAccent;
                        }

                        return DataRow(
                          cells: [
                            DataCell(Text(entry.createdAt.toString().substring(0, 16), style: const TextStyle(fontSize: 11))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: actionColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: actionColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  entry.actionType,
                                  style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DataCell(Text('R ${entry.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            DataCell(Text('R ${entry.newBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber))),
                            DataCell(Text(entry.updatedBy, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }


  void _showUpdateSavingsDialog(BuildContext context, VendorModel currentVendor) {
    final controller = TextEditingController(text: '0');
    String selectedAction = 'Deposit';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.savings_outlined, color: Colors.amber, size: 24),
              SizedBox(width: 12),
              Text(
                'Record Savings Transaction',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance: R ${currentVendor.savingsAmount?.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Action Type',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              DropdownButtonFormField<String>(
                value: selectedAction,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Deposit',
                    child: Text('Deposit (Add)'),
                  ),
                  DropdownMenuItem(
                    value: 'Withdrawal',
                    child: Text('Withdrawal (Subtract)'),
                  ),
                  DropdownMenuItem(
                    value: 'Adjustment',
                    child: Text('Manual Adjustment (Override)'),
                  ),
                ],
                onChanged: (val) => setState(() => selectedAction = val!),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Transaction Amount',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixText: 'R ',
                  prefixStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                    ),
                  );
                  return;
                }

                double currentBalance = currentVendor.savingsAmount ?? 0.0;
                double newBalance;

                if (selectedAction == 'Deposit') {
                  newBalance = currentBalance + amount;
                } else if (selectedAction == 'Withdrawal') {
                  if (amount > currentBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Insufficient savings for this withdrawal',
                        ),
                      ),
                    );
                    return;
                  }
                  newBalance = currentBalance - amount;
                } else {
                  // Manual Adjustment
                  newBalance = amount;
                }

                try {
                  final authProvider = context.read<AuthProvider>();
                  final operatorEmail = authProvider.currentUser?.email ?? 'Admin';

                  await context.read<VendorProvider>().recordSavingsTransaction(
                    vendorId: currentVendor.id,
                    amount: amount,
                    actionType: selectedAction,
                    updatedBy: operatorEmail,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Savings $selectedAction recorded successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Confirm Transaction'),
            ),
          ],
        ),
      ),
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
    final emailController = TextEditingController(text: _currentVendor.email);
    final addressController = TextEditingController(
      text: _currentVendor.address,
    );
    final savingsAmountController = TextEditingController(
      text: _currentVendor.savingsAmount?.toString() ?? '0',
    );
    String selectedGender = _currentVendor.gender ?? 'F';
    String selectedRole = _currentVendor.role ?? 'Member';
    String selectedFrequency = _currentVendor.savingsFrequency ?? 'Monthly';
    DateTime selectedSavingsDate =
        _currentVendor.savingsStartDate ?? DateTime.now();

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
            width: 600,
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
                  TextField(
                    controller: emailController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
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
                      Expanded(
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Role',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Member',
                              child: Text('Member'),
                            ),
                            DropdownMenuItem(
                              value: 'Chairperson',
                              child: Text('Chairperson'),
                            ),
                            DropdownMenuItem(
                              value: 'Secretary',
                              child: Text('Secretary'),
                            ),
                            DropdownMenuItem(
                              value: 'Treasurer',
                              child: Text('Treasurer'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedRole = val ?? 'Member'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dfNameController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: InputDecoration(
                            labelText: 'DF Name',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
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
                    controller: addressController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Home Address',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white24),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Savings Balance',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: savingsAmountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Savings Balance (R)',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedFrequency,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'Bi-Weekly',
                              child: Text('Bi-Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'Monthly',
                              child: Text('Monthly'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedFrequency = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Start Date',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    subtitle: Text(
                      "${selectedSavingsDate.toLocal()}".split(' ')[0],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    trailing: const Icon(
                      Icons.calendar_today,
                      color: Colors.amber,
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedSavingsDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != selectedSavingsDate) {
                        setState(() {
                          selectedSavingsDate = picked;
                        });
                      }
                    },
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
                  'email': emailController.text,
                  'address': addressController.text,
                  'role': selectedRole,
                  'savings_amount':
                      double.tryParse(savingsAmountController.text) ?? 0,
                  'savings_frequency': selectedFrequency,
                  'savings_start_date': selectedSavingsDate.toIso8601String(),
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
                        email: emailController.text,
                        dfName: dfNameController.text,
                        address: addressController.text,
                        role: selectedRole,
                        savingsAmount:
                            double.tryParse(savingsAmountController.text) ?? 0,
                        savingsFrequency: selectedFrequency,
                        savingsStartDate: selectedSavingsDate,
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
                final loanPayments = context
                    .read<PaymentProvider>()
                    .payments
                    .where((p) => p.loanId == loan.id)
                    .toList();
                final currentBalance = LoanCalculationService.calculateBalance(
                  loan,
                  loanPayments,
                );

                if (amount > currentBalance + 0.01) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Payment R $amount exceeds outstanding balance R ${currentBalance.toStringAsFixed(2)}',
                      ),
                    ),
                  );
                  return;
                }

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
                    loan: loan,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment recorded successfully!'),
                      ),
                    );
                    Navigator.pop(context);
                    // Refresh loan provider to show updated status
                    context.read<LoanProvider>().fetchLoans(forceRefresh: true);
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

    final totalExpected =
        loan.amount +
        (loan.initiationFee ?? 0) +
        ((loan.monthlyAdminFee ?? 0) * loan.durationMonths);

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
              _pdfInfoRowPayment('Name:', vendor.name),
              _pdfInfoRowPayment(
                'Reference No:',
                vendor.referenceNumber ?? 'N/A',
              ),
              _pdfInfoRowPayment('Group:', group.name),

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
              _pdfInfoRowPayment(
                'Loan Reference:',
                'L-${loan.id.substring(0, 8)}',
              ),
              _pdfInfoRowPayment(
                'Loan Amount:',
                'R ${loan.amount.toStringAsFixed(2)}',
              ),
              _pdfInfoRowPayment(
                'Initiation Fee:',
                'R ${(loan.initiationFee ?? 0).toStringAsFixed(2)}',
              ),
              _pdfInfoRowPayment(
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
                    _pdfInfoRowPayment(
                      'Amount Paid:',
                      'R ${payment.amountPaid.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    _pdfInfoRowPayment(
                      'Payment Method:',
                      payment.paymentMethod ?? 'Manual',
                    ),
                    _pdfInfoRowPayment(
                      'Payment Date:',
                      payment.datePaid.toString().substring(0, 10),
                    ),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    _pdfInfoRowPayment(
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
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
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

  pw.Widget _pdfInfoRowPayment(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
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

  void _showCommentDetailsDialog(CommentModel comment, VendorModel currentVendor) {
    final theme = Theme.of(context);
    final commentProvider = context.read<CommentProvider>();
    final TextEditingController _editController = TextEditingController(
      text: comment.content,
    );
    bool _isEditing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.comment, size: 20),
              const SizedBox(width: 12),
              const Text('Comment Details'),
              const Spacer(),
              if (comment.authorRole != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    comment.authorRole!,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      comment.createdAt.toString().substring(0, 16),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isEditing)
                  TextField(
                    controller: _editController,
                    maxLines: 5,
                    autofocus: true,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      comment.content,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (!_isEditing) ...[
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Comment?'),
                      content: const Text(
                        'Are you sure you want to remove this comment? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await commentProvider.deleteComment(comment.id);
                            Navigator.pop(context); // Close confirm
                            Navigator.pop(context); // Close details
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Comment deleted')),
                            );
                          },
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton.icon(
                onPressed: () => setDialogState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ] else ...[
              TextButton(
                onPressed: () => setDialogState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_editController.text.trim().isEmpty) return;
                  await commentProvider.updateComment(
                    comment.id,
                    _editController.text.trim(),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment updated')),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
