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
import '../services/system_audit_service.dart';

import '../widgets/communication/communication_dialog.dart';
import '../widgets/reminder_history_section.dart';
import '../widgets/nsbsa_loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/access_control_service.dart';

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

    final groupProvider = context.read<GroupProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();

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

    final currentVendor = vendorProvider.vendors.firstWhere(
      (v) => v.id == widget.vendor.id,
      orElse: () => _currentVendor,
    );

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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 16,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(theme, group, currentVendor),
                  const SizedBox(height: 24),
                  Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: isDesktop ? 2 : 0,
                        fit: isDesktop ? FlexFit.tight : FlexFit.loose,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMainHeader(theme, group, isDesktop, currentVendor),
                            const SizedBox(height: 24),
                            _buildInformationSection(theme, currentVendor),
                            const SizedBox(height: 24),
                            _buildFinancialSummary(theme, totalPaid),
                            if (!isDesktop) const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      if (isDesktop) const SizedBox(width: 40),
                      Flexible(
                        flex: isDesktop ? 3 : 0,
                        fit: isDesktop ? FlexFit.tight : FlexFit.loose,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLoanSection(theme, currentVendor),
                            const SizedBox(height: 24),
                            _buildPaymentHistorySection(theme, vendorPayments, currentVendor),
                            const SizedBox(height: 24),
                            _buildSavingsHistorySection(theme, currentVendor),
                            const SizedBox(height: 24),
                            _buildCommentsSection(theme, currentVendor),
                            const SizedBox(height: 24),
                            _buildDocumentsSection(theme, currentVendor),
                            const SizedBox(height: 24),
                            ReminderHistorySection(vendorId: currentVendor.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ── Custom header (replaces AppBar) ──────────────────────────────────────
  Widget _buildProfileHeader(ThemeData theme, GroupModel group, VendorModel currentVendor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 20, color: theme.primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentVendor.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color ?? Colors.white),
              ),
              Text(
                group.name,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const Spacer(),
          _ProfileActionButton(
            icon: Icons.chat_bubble_outline,
            tooltip: 'Send Message',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CommunicationDialog(vendor: currentVendor),
              );
            },
          ),
          const SizedBox(width: 6),
          if (AccessControlService.canRegisterVendors(
            context.read<AuthProvider>().userProfile,
          ))
            _ProfileActionButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit Profile',
              onPressed: () => _showEditVendorDialog(context),
            ),
          const SizedBox(width: 6),
          _ProfileActionButton(
            icon: Icons.picture_as_pdf_outlined,
            tooltip: 'Download Profile PDF',
            onPressed: () => VendorPdfService.generateProfilePDF(
              context: context,
              vendor: currentVendor,
              group: group,
              loans: _loans,
            ),
          ),
        ],
      ),
    );
  }

  // ── Main header: avatar + name + credit score ────────────────────────────
  Widget _buildMainHeader(ThemeData theme, GroupModel group, bool isDesktop, VendorModel currentVendor) {
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final score = analyticsProvider.vendorCreditScores[currentVendor.id] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: [
          _buildVendorAvatar(theme, currentVendor, radius: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentVendor.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color ?? Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Group: ${group.name}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                SelectableText(
                  'GRP-${group.id}',
                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildCreditBadge(score),
        ],
      ),
    );
  }

  Widget _buildVendorAvatar(ThemeData theme, VendorModel currentVendor, {double radius = 24}) {
    final vendorProvider = context.watch<VendorProvider>();
    final bool isUploading = vendorProvider.isLoading;

    return InkWell(
      onTap: isUploading ? null : () => _showAvatarOptions(currentVendor),
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              backgroundImage: currentVendor.avatarUrl != null && currentVendor.avatarUrl!.isNotEmpty
                  ? NetworkImage(currentVendor.avatarUrl!)
                  : null,
              child: currentVendor.avatarUrl == null || currentVendor.avatarUrl!.isEmpty
                  ? Icon(Icons.person, size: radius * 0.9, color: theme.primaryColor)
                  : null,
            ),
            if (isUploading)
              CircleAvatar(
                radius: radius,
                backgroundColor: Colors.black45,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: radius * 0.35,
                  backgroundColor: theme.primaryColor,
                  child: Icon(Icons.camera_alt, size: radius * 0.4, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions(VendorModel currentVendor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              if (currentVendor.avatarUrl != null && currentVendor.avatarUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.fullscreen, color: Colors.white),
                  title: const Text('View Profile Picture', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _viewFullImage(currentVendor.avatarUrl!, currentVendor.name);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Update Profile Picture', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleAvatarUpload(currentVendor);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _viewFullImage(String url, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Text('Profile Picture', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAvatarUpload(VendorModel currentVendor) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final extension = file.extension ?? 'jpg';

      if (!mounted) return;
      await runWithLoading(
        context,
        task: () async {
          final vendorProvider = context.read<VendorProvider>();
          await vendorProvider.uploadAvatar(currentVendor.id, file.bytes!, extension);
        },
        loadingMessage: 'Updating profile picture\u2026',
        successMessage: 'Profile picture updated successfully',
        errorMessageBuilder: (e) => 'Failed to upload picture: $e',
      );
    }
  }

  Widget _buildCreditBadge(double score) {
    String status = score > 85 ? 'Excellent' : (score > 60 ? 'Moderate' : 'High Risk');
    Color statusColor = score > 85 ? Colors.greenAccent : (score > 60 ? Colors.amberAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Credit Score', style: TextStyle(color: Colors.grey[500], fontSize: 9)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(3)),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Personal Information section ─────────────────────────────────────────
  Widget _buildInformationSection(ThemeData theme, VendorModel currentVendor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Personal Information'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              _buildInfoRow('Role', currentVendor.role ?? 'Member'),
              _buildInfoRow('Home Address', currentVendor.address ?? 'N/A'),
              _buildInfoRow('Phone', currentVendor.phone ?? 'N/A'),
              _buildInfoRow('ID Number', currentVendor.idNumber ?? 'N/A'),
              _buildInfoRow('Business', currentVendor.businessType ?? 'N/A'),
              _buildInfoRow('Email', currentVendor.email ?? 'N/A'),
              InkWell(
                onTap: () => _showUpdateSavingsDialog(context, currentVendor),
                borderRadius: BorderRadius.circular(6),
                child: _buildInfoRow(
                  'Savings Balance',
                  'R ${currentVendor.savingsAmount?.toStringAsFixed(2) ?? '0.00'}',
                  trailing: Icon(Icons.edit_outlined, size: 13, color: Colors.amber),
                ),
              ),
              if (context.watch<SavingsHistoryProvider>().history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 0),
                  child: Text(
                    'Last updated: ${context.watch<SavingsHistoryProvider>().history.first.createdAt.toString().substring(0, 16)} by ${context.watch<SavingsHistoryProvider>().history.first.updatedBy}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 9, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ── Financial Summary ────────────────────────────────────────────────────
  Widget _buildFinancialSummary(ThemeData theme, double totalPaid) {
    final paymentProvider = context.read<PaymentProvider>();
    final allPayments = paymentProvider.payments;

    double totalLiability = 0;
    for (var loan in _loans) {
      final loanPayments = allPayments.where((p) => p.loanId == loan.id).toList();
      totalLiability += loan.openingAmount != null
          ? loan.openingAmount! + LoanCalculationService.calculateAppliedPenalty(loan, loanPayments)
          : (loan.monthlyPayment + LoanCalculationService.effectiveAdminFee(loan)) * loan.durationMonths +
              LoanCalculationService.effectiveInitiationFee(loan) +
              LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);
    }

    final outstanding = totalLiability - totalPaid;
    final activeLoans = _loans.where((l) => l.status == 'Active').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Financial Summary'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Paid', 'R ${totalPaid.toStringAsFixed(0)}', Colors.greenAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Outstanding', 'R ${outstanding.toStringAsFixed(0)}', Colors.redAccent)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard('Active Loans', activeLoans.toString(), Colors.blueAccent)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
        color: t.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Loans section ────────────────────────────────────────────────────────
  Widget _buildLoanSection(ThemeData theme, VendorModel currentVendor) {
    final items = _loans.where((l) => l.status == 'Active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Active Loans'),
            if (items.isNotEmpty)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.download_for_offline, color: Colors.amber, size: 16),
                  onPressed: () => _exportLoansToExcel(currentVendor),
                  tooltip: 'Export Loans to Excel',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
          ),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No active loans found.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
                )
              : Column(
                  children: [for (int i = 0; i < items.length; i++)
                    ...[
                      if (i > 0)
                        Divider(height: 1, color: theme.dividerColor),
                      _buildLoanTile(theme, items[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLoanTile(ThemeData theme, LoanModel loan) {
    final paymentProvider = context.read<PaymentProvider>();
    final loanPayments = paymentProvider.payments.where((p) => p.loanId == loan.id).toList();

    final totalPaid = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    final balance = LoanCalculationService.calculateBalance(loan, loanPayments);
    final liability = balance + totalPaid;
    final arrears = LoanCalculationService.calculateArrears(loan, loanPayments);
    final isOverdue = loan.status == 'Overdue' || arrears > 0;

    return ExpansionTile(
                          tilePadding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                          childrenPadding: EdgeInsets.zero,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Loan R ${loan.amount.toStringAsFixed(0)}',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color ?? Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${loan.durationMonths} Months',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOverdue ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: (isOverdue ? Colors.redAccent : Colors.greenAccent).withOpacity(0.3)),
                                ),
                                child: Text(
                                  loan.status,
                                  style: TextStyle(
                                    color: isOverdue ? Colors.redAccent : Colors.greenAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'R ${balance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: balance <= 0 ? Colors.greenAccent : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (AccessControlService.canProcessPayments(
                                context.read<AuthProvider>().userProfile,
                              ))
                                SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.payment, size: 16, color: Colors.greenAccent),
                                  onPressed: () => _showRecordPaymentDialog(context, loan),
                                  tooltip: 'Record Payment',
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                border: Border(top: BorderSide(color: theme.dividerColor)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _loanDetailItem('Arrears', 'R ${arrears.toStringAsFixed(0)}', arrears > 0 ? Colors.redAccent : Colors.greenAccent),
                                      const SizedBox(width: 24),
                                      _loanDetailItem('Next Due', LoanCalculationService.nextPaymentDate(loan)?.toString().substring(0, 10) ?? 'N/A', Colors.white70),
                                      const SizedBox(width: 24),
                                      _loanDetailItem('Total Paid', 'R ${totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text('Repayments', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                                  const SizedBox(height: 8),
                                  if (loanPayments.isEmpty)
                                    Text('No payments recorded.', style: TextStyle(color: Colors.grey[600], fontSize: 11))
                                  else
                                    ...loanPayments.map((p) => Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(p.datePaid.toString().substring(0, 10), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                          Text('R ${p.amountPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                                        ],
                                      ),
                                    )),
                                ],
                              ),
                            ),
                          ],
                        );
  }

  Widget _loanDetailItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Payment History section ──────────────────────────────────────────────
  Widget _buildPaymentHistorySection(ThemeData theme, List<PaymentModel> vendorPayments, VendorModel currentVendor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Payment History'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
          ),
          child: vendorPayments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No payments recorded.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
                )
              : Column(
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: theme.dividerColor)),
                      ),
                      child: Row(
                        children: [
                          _th('Date', flex: 2),
                          _th('Amount', flex: 2),
                          _th('Method', flex: 2),
                          _th('Loan', flex: 3),
                        ],
                      ),
                    ),
                    // Payment rows
                    ...vendorPayments.map((payment) {
                      final loanProvider = context.read<LoanProvider>();
                      final loan = loanProvider.loans.where((l) => l.id == payment.loanId).firstOrNull;
                      return InkWell(
                        onTap: () {
                          final groupProvider = context.read<GroupProvider>();
                          final group = groupProvider.groups.where((g) => g.id == currentVendor.groupId).firstOrNull;
                          if (loan != null && group != null) {
                            _showPaymentDetailsDialog(context, payment, loan, _currentVendor, group);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            border: vendorPayments.last != payment
                                ? Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)))
                                : null,
                          ),
                          child: Row(
                            children: [
                              _td(payment.datePaid.toString().substring(0, 10), flex: 2),
                              _td('R ${payment.amountPaid.toStringAsFixed(0)}', flex: 2, color: Colors.greenAccent),
                              _td(payment.paymentMethod ?? 'Cash', flex: 2),
                              _td(loan != null ? 'R ${loan.amount.toStringAsFixed(0)}' : '-', flex: 3),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _th(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400])),
    );
  }

  Widget _td(String text, {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color ?? Colors.white70),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Savings History section ──────────────────────────────────────────────
  String _selectedActionFilter = 'All';

  Widget _buildSavingsHistorySection(ThemeData theme, VendorModel currentVendor) {
    final historyProvider = context.watch<SavingsHistoryProvider>();
    final history = historyProvider.history.where((e) {
      if (_selectedActionFilter == 'All') return true;
      return e.actionType == _selectedActionFilter;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surface,
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Text('Savings History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color ?? Colors.white)),
            if (history.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Text('${history.length}', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: _selectedActionFilter,
              underline: const SizedBox(),
              dropdownColor: theme.colorScheme.surface,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              icon: const Icon(Icons.filter_list, size: 14, color: Colors.grey),
              items: ['All', 'Deposit', 'Withdrawal', 'Adjustment']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                  .toList(),
              onChanged: (val) => setState(() => _selectedActionFilter = val!),
            ),
            if (history.isNotEmpty)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => VendorPdfService.exportSavingsHistoryPDF(vendor: _currentVendor, history: history),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  tooltip: 'Export PDF',
                ),
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No matching history found.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ),
                  )
                : Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            _savingsTh('Date/Time', flex: 3),
                            _savingsTh('Action', flex: 2),
                            _savingsTh('Amount', flex: 2),
                            _savingsTh('Balance', flex: 2),
                            _savingsTh('Operator', flex: 2),
                          ],
                        ),
                      ),
                      // Rows
                      ...history.map((entry) {
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

                        return Container(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          decoration: BoxDecoration(
                            border: history.last != entry
                                ? Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5)))
                                : null,
                          ),
                          child: Row(
                            children: [
                              _savingsTd(entry.createdAt.toString().substring(0, 16), flex: 3),
                              _savingsTd(
                                entry.actionType,
                                flex: 2,
                                color: actionColor,
                                isBadge: true,
                              ),
                              _savingsTd('R ${entry.amount.toStringAsFixed(2)}', flex: 2, fontWeight: FontWeight.w600),
                              _savingsTd('R ${entry.newBalance.toStringAsFixed(2)}', flex: 2, color: Colors.amber),
                              _savingsTd(entry.updatedBy, flex: 2, color: Colors.grey[500]),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _savingsTh(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400])),
    );
  }

  Widget _savingsTd(String text, {int flex = 1, Color? color, FontWeight fontWeight = FontWeight.normal, bool isBadge = false}) {
    return Expanded(
      flex: flex,
      child: isBadge
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                text,
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: color ?? Colors.white70,
                fontWeight: fontWeight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  // ── Comments section ─────────────────────────────────────────────────────
  Widget _buildCommentsSection(ThemeData theme, VendorModel currentVendor) {
    final commentProvider = context.watch<CommentProvider>();
    final TextEditingController _commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('My Comments & Mentions'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            children: [
              // Comment Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _commentController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                      decoration: InputDecoration(
                        hintText: 'Add a personal note...',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        fillColor: theme.scaffoldBackgroundColor,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () async {
                            if (_commentController.text.trim().isEmpty) return;

                            final authProvider = context.read<AuthProvider>();
                            final comment = CommentModel(
                              id: '',
                              vendorId: currentVendor.id,
                              authorName: authProvider.currentUser?.email ?? 'Admin',
                              authorRole: 'Staff',
                              content: _commentController.text.trim(),
                              createdAt: DateTime.now(),
                            );

                            await runWithLoading(
                              context,
                              task: () => commentProvider.addComment(comment),
                              loadingMessage: 'Adding note\u2026',
                              successMessage: 'Note added',
                            );
                            _commentController.clear();
                          },
                          child: const Text('Add Note'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              // Comments List
              if (commentProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (commentProvider.comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No comments yet.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: commentProvider.comments.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    final comment = commentProvider.comments[index];
                    final isMention = comment.mentionedVendorIds.contains(_currentVendor.id);

                    return InkWell(
                      onTap: () => _showCommentDetailsDialog(comment, currentVendor),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment.authorName,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color ?? Colors.white),
                                ),
                                const SizedBox(width: 6),
                                if (isMention)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'Mentioned',
                                      style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  comment.createdAt.toString().substring(0, 16),
                                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              comment.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.white70),
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

  // ── Documents section ────────────────────────────────────────────────────
  Widget _buildDocumentsSection(ThemeData theme, VendorModel currentVendor) {
    final docProvider = context.watch<DocumentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Supporting Documents'),
            SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                onPressed: docProvider.isLoading
                    ? null
                    : () async {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                        );

                        if (result != null) {
                          if (!mounted) return;
                          final files = result.files
                              .where((f) => f.bytes != null)
                              .toList();

                          await runWithLoading(
                            context,
                            task: () async {
                              for (var file in files) {
                                await docProvider.uploadDocument(
                                  vendorId: currentVendor.id,
                                  fileName: file.name,
                                  fileBytes: file.bytes!,
                                );
                              }
                            },
                            loadingMessage: 'Uploading ${files.length} document(s)\u2026',
                            successMessage: 'Successfully uploaded ${files.length} document(s)',
                            errorMessageBuilder: (e) => 'Upload failed: $e',
                          );
                        }
                      },
                icon: docProvider.isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_file, size: 14),
                label: Text(docProvider.isLoading ? 'Uploading...' : 'Upload'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surface,
          ),
          child: docProvider.isLoading && docProvider.documents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : docProvider.documents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No documents uploaded yet.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docProvider.documents.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final doc = docProvider.documents[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Icon(_getFileIcon(doc.fileType), size: 18, color: theme.primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.fileName,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.textTheme.bodyLarge?.color ?? Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Uploaded: ${doc.uploadedAt.toString().substring(0, 16)}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.open_in_new, size: 14, color: Colors.blueAccent),
                                  onPressed: () {
                                    final url = docProvider.getPublicUrl(doc.filePath);
                                    launchUrl(Uri.parse(url));
                                  },
                                  tooltip: 'View Document',
                                ),
                              ),
                              if (AccessControlService.canEditData(
                                context.read<AuthProvider>().userProfile,
                              ))
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                    onPressed: () => docProvider.deleteDocument(doc),
                                    tooltip: 'Delete Document',
                                  ),
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

  // ── Helper: section header ───────────────────────────────────────────────
  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400]),
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
      final liability = loan.openingAmount != null
          ? loan.openingAmount! + LoanCalculationService.calculateAppliedPenalty(loan, loanPayments)
          : (loan.monthlyPayment + LoanCalculationService.effectiveAdminFee(loan)) * loan.durationMonths +
              LoanCalculationService.effectiveInitiationFee(loan) +
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

    SystemAuditService.logAction(
      actionType: 'EXPORT_REPORT',
      affectedEntity: 'Vendor: ${currentVendor.name} (${currentVendor.id})',
      description: 'Exported loan history for vendor to Excel.',
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────
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
              Text('Record Savings Transaction', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance: R ${currentVendor.savingsAmount?.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('Action Type', style: TextStyle(color: Colors.grey, fontSize: 12)),
              DropdownButtonFormField<String>(
                value: selectedAction,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                decoration: const InputDecoration(border: UnderlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Deposit', child: Text('Deposit (Add)')),
                  DropdownMenuItem(value: 'Withdrawal', child: Text('Withdrawal (Subtract)')),
                  DropdownMenuItem(value: 'Adjustment', child: Text('Manual Adjustment (Override)')),
                ],
                onChanged: (val) => setState(() => selectedAction = val!),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Transaction Amount',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixText: 'R ',
                  prefixStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }

                if (selectedAction == 'Withdrawal') {
                  final currentBalance = currentVendor.savingsAmount ?? 0.0;
                  if (amount > currentBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient savings for this withdrawal')),
                    );
                    return;
                  }
                }

                if (!context.mounted) return;
                final authProvider = context.read<AuthProvider>();
                final operatorEmail = authProvider.currentUser?.email ?? 'Admin';

                await runWithLoadingAfterPop(
                  context,
                  task: () => context.read<VendorProvider>().recordSavingsTransaction(
                    vendorId: currentVendor.id,
                    amount: amount,
                    actionType: selectedAction,
                    updatedBy: operatorEmail,
                  ),
                  loadingMessage: 'Recording $selectedAction\u2026',
                  successMessage: 'Savings $selectedAction recorded successfully',
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
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
    final businessController = TextEditingController(text: _currentVendor.businessType);
    final dfNameController = TextEditingController(text: _currentVendor.dfName);
    final whatsappController = TextEditingController(text: _currentVendor.whatsappNumber);
    final emailController = TextEditingController(text: _currentVendor.email);
    final addressController = TextEditingController(text: _currentVendor.address);
    final savingsAmountController = TextEditingController(
      text: _currentVendor.savingsAmount?.toString() ?? '0',
    );
    String selectedGender = _currentVendor.gender ?? 'F';
    String selectedRole = _currentVendor.role ?? 'Member';
    String selectedFrequency = _currentVendor.savingsFrequency ?? 'Monthly';
    DateTime selectedSavingsDate = _currentVendor.savingsStartDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Edit Member Profile', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: whatsappController,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'WhatsApp', labelStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    decoration: const InputDecoration(labelText: 'Email Address', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: idController,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'ID Number', labelStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'Gender', labelStyle: TextStyle(color: Colors.grey)),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('M')),
                            DropdownMenuItem(value: 'F', child: Text('F')),
                          ],
                          onChanged: (val) => setState(() => selectedGender = val ?? 'F'),
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
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                          decoration: const InputDecoration(labelText: 'Role', labelStyle: TextStyle(color: Colors.grey)),
                          items: const [
                            DropdownMenuItem(value: 'Member', child: Text('Member')),
                            DropdownMenuItem(value: 'Chairperson', child: Text('Chairperson')),
                            DropdownMenuItem(value: 'Secretary', child: Text('Secretary')),
                            DropdownMenuItem(value: 'Treasurer', child: Text('Treasurer')),
                          ],
                          onChanged: (val) => setState(() => selectedRole = val ?? 'Member'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: dfNameController,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'DF Name', labelStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: businessController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    decoration: const InputDecoration(labelText: 'Business Type', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    decoration: const InputDecoration(labelText: 'Home Address', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.white24),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Savings Balance', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: savingsAmountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'Savings Balance (R)', labelStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedFrequency,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          decoration: const InputDecoration(labelText: 'Frequency', labelStyle: TextStyle(color: Colors.grey)),
                          items: const [
                            DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                            DropdownMenuItem(value: 'Bi-Weekly', child: Text('Bi-Weekly')),
                            DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                          ],
                          onChanged: (val) => setState(() => selectedFrequency = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Date', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    subtitle: Text(
                      "${selectedSavingsDate.toLocal()}".split(' ')[0],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    trailing: const Icon(Icons.calendar_today, color: Colors.amber),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedSavingsDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != selectedSavingsDate) {
                        setState(() { selectedSavingsDate = picked; });
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
                  'role': 'Member',
                  'savings_amount': double.tryParse(savingsAmountController.text) ?? 0,
                  'savings_frequency': selectedFrequency,
                  'savings_start_date': selectedSavingsDate.toIso8601String(),
                };

                if (!context.mounted) return;
                final vendorProvider = context.read<VendorProvider>();
                final updatedId = _currentVendor.id;
                final createdAt = _currentVendor.createdAt;

                await runWithLoadingAfterPop(
                  context,
                  task: () async {
                    await vendorProvider.updateVendor(updatedId, updatedData);
                    final supabase = Supabase.instance.client;
                    if (_currentVendor.groupId.isNotEmpty) {
                      if (selectedRole == 'Member') {
                        await supabase
                            .from('leadership')
                            .delete()
                            .eq('vendor_id', updatedId);
                      } else {
                        await supabase
                            .from('leadership')
                            .delete()
                            .eq('vendor_id', updatedId);
                        await supabase.from('leadership').insert({
                          'group_id': _currentVendor.groupId,
                          'vendor_id': updatedId,
                          'role': selectedRole,
                        });
                      }
                    }
                    _currentVendor = VendorModel(
                      id: updatedId,
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
                      role: 'Member',
                      savingsAmount: double.tryParse(savingsAmountController.text) ?? 0,
                      savingsFrequency: selectedFrequency,
                      savingsStartDate: selectedSavingsDate,
                      createdAt: createdAt,
                    );
                  },
                  loadingMessage: 'Updating profile\u2026',
                  successMessage: 'Profile updated successfully!',
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, LoanModel loan) {
    final monthlyAdminFee = LoanCalculationService.effectiveAdminFee(loan);
    final defaultAmount = (loan.monthlyPayment + monthlyAdminFee).toStringAsFixed(0);
    final amountController = TextEditingController(text: defaultAmount);
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
              Text(
                'Enter the amount received for Loan R ${loan.amount}.',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                  helperText:
                      'R ${loan.monthlyPayment.toStringAsFixed(0)} monthly + R ${monthlyAdminFee.toStringAsFixed(0)} admin',
                  helperStyle: const TextStyle(color: Colors.grey, fontSize: 10),
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
                final currentBalance = LoanCalculationService.calculateBalance(loan, loanPayments);

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
                  if (!context.mounted) return;
                  final paymentProvider = context.read<PaymentProvider>();
                  final loanProvider = context.read<LoanProvider>();
                  final pmt = PaymentModel(
                    id: '',
                    loanId: loan.id,
                    amountPaid: amount,
                    paymentMethod: selectedType,
                    datePaid: DateTime.now(),
                    createdAt: DateTime.now(),
                  );

                  await runWithLoadingAfterPop(
                    context,
                    task: () async {
                      await paymentProvider.addPayment(pmt, loan: loan);
                      await loanProvider.fetchLoans(forceRefresh: true);
                    },
                    loadingMessage: 'Recording payment\u2026',
                    successMessage: 'Payment recorded successfully!',
                  );
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
    final allLoanPayments =
        context
            .read<PaymentProvider>()
            .payments
            .where((p) => p.loanId == loan.id)
            .toList()
          ..sort((a, b) => a.datePaid.compareTo(b.datePaid));

    final totalExpected = loan.openingAmount != null
        ? loan.openingAmount!
        : (loan.monthlyPayment + LoanCalculationService.effectiveAdminFee(loan)) * loan.durationMonths +
            LoanCalculationService.effectiveInitiationFee(loan);

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
        title: const Text('Payment Details', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Member Name', vendor.name),
                _detailRow('Reference No.', vendor.referenceNumber ?? 'N/A'),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _detailRow('Loan Reference', 'L-${loan.id.substring(0, 8)}'),
                _detailRow('Group Name', group.name),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _detailRow('Payment Amount', 'R ${payment.amountPaid.toStringAsFixed(2)}', isHighlight: true),
                _detailRow('Payment Date', payment.datePaid.toString().substring(0, 10)),
                _detailRow('Payment Method', payment.paymentMethod ?? 'Manual'),
                Divider(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                _detailRow('Updated Balance', 'R ${balanceAfterPayment.toStringAsFixed(2)}', isHighlight: true),
                const SizedBox(height: 16),
                const Text('Applicable Fees Included in Loan:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                _detailRow('Initiation Fee', 'R ${LoanCalculationService.effectiveInitiationFee(loan).toStringAsFixed(0)}'),
                _detailRow('Monthly Admin Fee', 'R ${LoanCalculationService.effectiveAdminFee(loan).toStringAsFixed(0)} / mo'),
                _detailRow('Penalty Fee', 'R ${(loan.penaltyFee ?? 0).toStringAsFixed(0)}'),
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
              _generatePaymentReceiptPDF(payment, loan, vendor, group, balanceAfterPayment);
            },
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? Colors.amberAccent : Theme.of(context).textTheme.bodyMedium?.color,
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
                      pw.Text('Payment Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Receipt No: P-${payment.id.substring(0, 8).toUpperCase()}'),
                      pw.Text('Date: ${payment.datePaid.toString().substring(0, 10)}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Text('Member Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _pdfRow('Name:', vendor.name),
              _pdfRow('Reference No:', vendor.referenceNumber ?? 'N/A'),
              _pdfRow('Group:', group.name),
              pw.SizedBox(height: 24),
              pw.Text('Loan Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _pdfRow('Loan Reference:', 'L-${loan.id.substring(0, 8)}'),
              _pdfRow('Loan Amount:', 'R ${loan.amount.toStringAsFixed(2)}'),
              _pdfRow('Initiation Fee:', 'R ${LoanCalculationService.effectiveInitiationFee(loan).toStringAsFixed(2)}'),
              _pdfRow('Admin Fees:', 'R ${(LoanCalculationService.effectiveAdminFee(loan) * loan.durationMonths).toStringAsFixed(2)} (Total)'),
              pw.SizedBox(height: 24),
              pw.Text('Payment Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                    _pdfRow('Amount Paid:', 'R ${payment.amountPaid.toStringAsFixed(2)}', isBold: true),
                    _pdfRow('Payment Method:', payment.paymentMethod ?? 'Manual'),
                    _pdfRow('Payment Date:', payment.datePaid.toString().substring(0, 10)),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    _pdfRow('Remaining Balance:', 'R ${balanceAfterPayment.toStringAsFixed(2)}', isBold: true),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Text('All applicable fees are included in the amounts shown above.', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
              pw.Text('Thank you for your business.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
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

  pw.Widget _pdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
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
    final TextEditingController _editController = TextEditingController(text: comment.content);
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    comment.authorRole!,
                    style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
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
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    child: Text(comment.content, style: const TextStyle(height: 1.5)),
                  ),
              ],
            ),
          ),
          actions: [
            if (!_isEditing && !AccessControlService.canEditData(
              context.read<AuthProvider>().userProfile,
            )) ...[
              const TextButton(
                onPressed: null,
                child: Text('View only', style: TextStyle(color: Colors.grey)),
              ),
            ] else if (!_isEditing) ...[
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Comment?'),
                      content: const Text('Are you sure you want to remove this comment? This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            await commentProvider.deleteComment(comment.id);
                            Navigator.pop(context);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment deleted')));
                          },
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
                  await commentProvider.updateComment(comment.id, _editController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment updated')));
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

// ── Reusable profile header action button ───────────────────────────────────
class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ProfileActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
