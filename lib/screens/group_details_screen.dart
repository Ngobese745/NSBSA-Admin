import 'package:flutter/material.dart';

import '../core/app_breakpoints.dart';
import '../core/pdf_branding.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/group.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/group_provider.dart';
import '../providers/center_provider.dart';
import '../models/center.dart';
import '../models/leadership.dart';
import 'vendor_profile_screen.dart';
import 'loan_details_screen.dart';
import '../services/loan_calculation_service.dart';
import '../services/loan_interest_service.dart';
import '../widgets/communication/communication_dialog.dart';
import '../widgets/communication/group_communication_dialog.dart';
import '../services/excel_export_service.dart';
import '../models/comment.dart';
import '../providers/comment_provider.dart';
import '../providers/auth_provider.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/nsbsa_loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/access_control_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<VendorModel> _members = [];
  List<LoanModel> _loans = [];
  CenterModel? _center;
  List<LeadershipModel> _leaders = [];
  bool _isLoading = true;
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.group.name;
    _loadData();
  }

  Future<void> _loadData() async {
    final vendorProvider = context.read<VendorProvider>();
    final loanProvider = context.read<LoanProvider>();
    final paymentProvider = context.read<PaymentProvider>();
    final centerProvider = context.read<CenterProvider>();

    final results = await Future.wait<dynamic>([
      vendorProvider.fetchVendorsByGroup(widget.group.id),
      loanProvider.fetchLoansByGroup(widget.group.id),
      paymentProvider.fetchPayments(),
      context.read<CommentProvider>().fetchCommentsByGroup(widget.group.id),
      context.read<DocumentProvider>().fetchDocumentsByGroup(widget.group.id),
      if (widget.group.centerId != null)
        centerProvider.fetchLeadership(groupId: widget.group.id),
    ]);

    if (widget.group.centerId != null) {
      final centers = centerProvider.centers;
      try {
        _center = centers.firstWhere((c) => c.id == widget.group.centerId);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _members = results[0] as List<VendorModel>;
        _loans = results[1] as List<LoanModel>;
        if (results.length > 5) {
          _leaders = results[5] as List<LeadershipModel>;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop =
        MediaQuery.of(context).size.width >=
        AppBreakpoints.groupDetailsDesktopMin;
    final isTablet =
        MediaQuery.of(context).size.width >=
        AppBreakpoints.groupDetailsTabletMin;

    final vendorProvider = context.watch<VendorProvider>();

    // Derive members reactively from provider
    final members = vendorProvider.vendors
        .where((v) => v.groupId == widget.group.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme, isDesktop, members),
                  const SizedBox(height: 32),
                  _buildSummarySection(theme, isTablet, members),
                  const SizedBox(height: 32),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildMembersList(theme, members)),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildLoansList(theme, members)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildMembersList(theme, members),
                        const SizedBox(height: 32),
                        _buildLoansList(theme, members),
                      ],
                    ),
                  const SizedBox(height: 32),
                  _buildSavingsSection(theme, members),
                  const SizedBox(height: 32),
                  _buildCommentsSection(theme, members),
                  const SizedBox(height: 32),
                  _buildDocumentsSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildCommentsSection(ThemeData theme, List<VendorModel> members) {
    final commentProvider = context.watch<CommentProvider>();
    final TextEditingController _commentController = TextEditingController();
    List<String> _selectedMentionIds = [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group Comments',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              // Comment Input
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatefulBuilder(
                          builder: (context, setState) => Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Mention Member'),
                                      content: SizedBox(
                                        width: 300,
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: members.length,
                                          itemBuilder: (context, index) {
                                            final m = members[index];
                                            return CheckboxListTile(
                                              title: Text(m.name),
                                              value: _selectedMentionIds
                                                  .contains(m.id),
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedMentionIds.add(
                                                      m.id,
                                                    );
                                                  } else {
                                                    _selectedMentionIds.remove(
                                                      m.id,
                                                    );
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Done'),
                                        ),
                                      ],
                                    ),
                                  ).then(
                                    (_) =>
                                        (context as Element).markNeedsBuild(),
                                  );
                                },
                                icon: const Icon(
                                  Icons.alternate_email,
                                  size: 16,
                                ),
                                label: const Text('Mention'),
                              ),
                              ..._selectedMentionIds.map((id) {
                                final name = members
                                    .firstWhere((m) => m.id == id)
                                    .name;
                                return Chip(
                                  label: Text(
                                    name,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  onDeleted: () {
                                    setState(
                                      () => _selectedMentionIds.remove(id),
                                    );
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_commentController.text.trim().isEmpty) return;

                            final authProvider = context.read<AuthProvider>();
                            final comment = CommentModel(
                              id: '',
                              groupId: widget.group.id,
                              authorName:
                                  authProvider.currentUser?.email ?? 'Admin',
                              authorRole: 'Staff',
                              content: _commentController.text.trim(),
                              mentionedVendorIds: _selectedMentionIds,
                              createdAt: DateTime.now(),
                            );

                            runWithLoading(context, task: () async {
                              await commentProvider.addComment(comment);
                              _commentController.clear();
                              _selectedMentionIds = [];
                              (context as Element).markNeedsBuild();
                            }, successMessage: 'Comment posted.');
                          },
                          child: const Text('Post Comment'),
                        ),
                      ],
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
                    return InkWell(
                      onTap: () => _showCommentDetailsDialog(comment, members),
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
                                if (comment.authorRole != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      comment.authorRole!,
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  _formatDate(comment.createdAt),
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
                            if (comment.mentionedVendorIds.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                children: comment.mentionedVendorIds.map((id) {
                                  final name =
                                      members
                                          .where((m) => m.id == id)
                                          .firstOrNull
                                          ?.name ??
                                      'Unknown';
                                  return Text(
                                    '@$name',
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
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

  Widget _buildSavingsSection(ThemeData theme, List<VendorModel> members) {
    final vendorProvider = context.watch<VendorProvider>();
    final groupMembers = vendorProvider.vendors
        .where((m) => m.groupId == widget.group.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group Savings Plan',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            title: Text(
              '${groupMembers.length} Members Enrolled',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('View contribution details'),
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupMembers.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, index) {
                  final member = groupMembers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.withOpacity(0.1),
                      child: const Icon(
                        Icons.savings,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Frequency: ${member.savingsFrequency ?? 'Monthly'} • Starts: ${member.savingsStartDate?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
                    ),
                    trailing: Text(
                      'R ${member.savingsAmount?.toStringAsFixed(2) ?? '0.00'}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VendorProfileScreen(vendor: member),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDesktop, List<VendorModel> members) {
    final leftSide = Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: theme.primaryColor.withOpacity(0.1),
          child: Icon(Icons.group, size: 36, color: theme.primaryColor),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_center != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business, size: 10, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        _center!.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _currentName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 28 : 22,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (AccessControlService.canEditData(
                    context.read<AuthProvider>().userProfile,
                  ))
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: _showEditDialog,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REF: ${widget.group.referenceNumber}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.group.creatorName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Created by ${widget.group.creatorName}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildLeadershipBadges(theme)),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final rightSide = Column(
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          'REGISTRATION DATE',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        Text(
          widget.group.createdAt.toString().substring(0, 10),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _downloadGroupStatement(members),
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Statement'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(flex: 3, child: leftSide),
                const Spacer(),
                rightSide,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [leftSide, const SizedBox(height: 24), rightSide],
            ),
    );
  }

  Widget _buildLeadershipBadges(ThemeData theme) {
    if (_leaders.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      children: _leaders.map((leader) {
        Color badgeColor;
        switch (leader.role) {
          case 'Chairperson':
            badgeColor = Colors.blue;
            break;
          case 'Secretary':
            badgeColor = Colors.green;
            break;
          case 'Treasurer':
            badgeColor = Colors.orange;
            break;
          default:
            badgeColor = theme.primaryColor;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.5), width: 0.5),
          ),
          child: Text(
            '${leader.role.substring(0, 1)}: ${leader.vendorName ?? ''}',
            style: TextStyle(
              color: badgeColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummarySection(ThemeData theme, bool isTablet, List<VendorModel> members) {
    double totalLoaned = _loans.fold(0, (sum, item) => sum + item.amount);
    final paymentProvider = context.watch<PaymentProvider>();
    final allPayments = paymentProvider.payments;
    final loanIds = _loans.map((loan) => loan.id).toSet();
    final groupPayments = allPayments
        .where((payment) => loanIds.contains(payment.loanId))
        .toList();

    double totalPaid = groupPayments.fold<double>(
      0,
      (sum, p) => sum + p.amountPaid,
    );

    // Calculate total balance by summing individual loan balances (correctly handling fees and capping at 0)
    double balance = 0;
    for (final loan in _loans) {
      final loanPayments = groupPayments
          .where((p) => p.loanId == loan.id)
          .toList();
      balance += LoanCalculationService.calculateBalance(loan, loanPayments);
    }
    final groupMembers = members;

    final totalSavings = groupMembers.fold(
      0.0,
      (sum, m) => sum + (m.savingsAmount ?? 0.0),
    );

    return Row(
      children: [
        _buildStatCard(
          'Members',
          groupMembers.length.toString(),
          Icons.people,
          theme.primaryColor,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Loans',
          _loans.length.toString(),
          Icons.account_balance,
          Colors.blueAccent,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Total Value',
          'R ${totalLoaned.toStringAsFixed(0)}',
          Icons.payments,
          Colors.greenAccent,
          subtitle: 'Bal: R ${balance.toStringAsFixed(0)}',
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'Savings',
          'R ${totalSavings.toStringAsFixed(0)}',
          Icons.savings,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList(ThemeData theme, List<VendorModel> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Group Members',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _showGroupCommunicationDialog(members),
                  icon: const Icon(Icons.send, size: 18, color: AppTheme.primaryGold),
                  label: const Text('Message Group'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showAddMemberDialog(members),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Member'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = members[index];
              return ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.role != null && member.role != 'Member') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          member.role!.toUpperCase(),
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(member.phone ?? 'No Phone'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendorProfileScreen(vendor: member),
                    ),
                  );
                },
                trailing: AccessControlService.canEditData(
                  context.read<AuthProvider>().userProfile,
                )
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () => _showEditMemberDialog(member),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _showDeleteMemberConfirm(member),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoansList(ThemeData theme, List<VendorModel> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Group Loans',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
             Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (AccessControlService.canProcessPayments(
                  context.read<AuthProvider>().userProfile,
                )) ...[
                  TextButton.icon(
                    onPressed: () => _showRecordGroupPaymentDialog(members),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Group Payment'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showAddLoanDialog(members),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Loan'),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: _loans.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No loans found for this group.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _loans.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final loan = _loans[index];
                    return ListTile(
                      title: Text('Loan R ${loan.amount}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.vendorName ?? 'Unknown Member',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryGold.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Status: ${loan.status} • Term: ${loan.durationMonths} Months',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoanDetailsScreen(loan: loan),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'R ${loan.monthlyPayment}/mo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (AccessControlService.canProcessPayments(
                            context.read<AuthProvider>().userProfile,
                          ))
                            IconButton(
                            icon: const Icon(
                              Icons.payment,
                              size: 20,
                              color: Colors.greenAccent,
                            ),
                            onPressed: () => _showRecordPaymentDialog(loan),
                            tooltip: 'Record Payment',
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

  void _showEditDialog() {
    final controller = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Edit Group Name',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          decoration: const InputDecoration(
            labelText: 'Group Name',
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              final name = controller.text;
              final state = this;
              runWithLoadingAfterPop(
                context,
                task: () async {
                  await context.read<GroupProvider>().updateGroup(
                    widget.group.id,
                    name,
                  );
                  state.setState(() => state._currentName = name);
                },
                successMessage: 'Group name updated.',
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(VendorModel member) {
    final nameController = TextEditingController(text: member.name);
    final phoneController = TextEditingController(text: member.phone);
    final idController = TextEditingController(text: member.idNumber);
    final businessController = TextEditingController(text: member.businessType);
    final dfController = TextEditingController(text: member.dfName);
    final whatsappController = TextEditingController(
      text: member.whatsappNumber,
    );
    final addressController = TextEditingController(text: member.address);
    final savingsAmountController = TextEditingController(
      text: member.savingsAmount?.toString() ?? '0',
    );
    String selectedGender = member.gender ?? 'F';
    String selectedRole = member.role ?? 'Member';
    String selectedFrequency = member.savingsFrequency ?? 'Monthly';
    DateTime selectedSavingsDate = member.savingsStartDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Edit Member',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: idController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'ID Number',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
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
                              setState(() => selectedRole = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('M')),
                            DropdownMenuItem(value: 'F', child: Text('F')),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedGender = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: whatsappController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextField(
                    controller: businessController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Business Type',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextField(
                    controller: dfController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'DF Name',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextField(
                    controller: addressController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
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
                      'Savings Plan',
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
                            labelText: 'Savings Amount (R)',
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
                  if (nameController.text.trim().isEmpty) return;
                  final dialogCtx = context;
                  final vendorData = {
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'id_number': idController.text,
                    'gender': selectedGender,
                    'business_type': businessController.text,
                    'df_name': dfController.text,
                    'whatsapp_number': whatsappController.text,
                    'address': addressController.text,
                    'role': 'Member',
                    'savings_amount':
                        double.tryParse(savingsAmountController.text) ?? 0,
                    'savings_frequency': selectedFrequency,
                    'savings_start_date': selectedSavingsDate.toIso8601String(),
                  };
                  runWithLoadingAfterPop(
                    dialogCtx, task: () async {
                      await dialogCtx.read<VendorProvider>().updateVendor(
                        member.id,
                        vendorData,
                      );
                      final supabase = Supabase.instance.client;
                      if (selectedRole == 'Member') {
                        await supabase
                            .from('leadership')
                            .delete()
                            .eq('vendor_id', member.id);
                      } else {
                        await supabase
                            .from('leadership')
                            .delete()
                            .eq('vendor_id', member.id);
                        await supabase.from('leadership').insert({
                          'group_id': widget.group.id,
                          'vendor_id': member.id,
                          'role': selectedRole,
                        });
                      }
                      _loadData();
                    },
                    successMessage: 'Member updated.',
                  );
                },
                child: const Text('Save'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddLoanDialog(List<VendorModel> members) {
    final amountController = TextEditingController();
    final termController = TextEditingController(text: '6');
    final monthlyController = TextEditingController();
    final customRateController = TextEditingController();
    final gracePeriodController = TextEditingController(text: '3');
    DateTime selectedFirstDate = DateTime.now().add(const Duration(days: 30));

    String? selectedVendorId;
    Map<String, dynamic>? interestBreakdown;
    double? selectedRate;
    bool useCustomRate = false;
    bool rateLocked = false;
    bool monthlyManuallySet = false;
    bool gracePeriodEnabled = false;

    void recalc(StateSetter setState, {double? rateOverride}) {
      final breakdown = _recalculateLoan(
        setState,
        amountController,
        termController,
        monthlyController,
        userRate: rateOverride,
        manualMonthly: monthlyManuallySet,
      );
      interestBreakdown = breakdown;
      if (rateOverride == null && !rateLocked) {
        selectedRate = breakdown['rate'] as double?;
      }
    }

    void recalcWithRate(StateSetter setState, double rate) {
      rateLocked = true;
      selectedRate = rate;
      useCustomRate = false;
      customRateController.text = (rate * 100).toStringAsFixed(2);
      recalc(setState, rateOverride: rate);
    }

    Widget buildRateSelector(StateSetter setState) {
      final available = LoanInterestService.getRatesForDuration(int.tryParse(termController.text) ?? 6);
      if (!useCustomRate && available.isNotEmpty) {
        return DropdownButtonFormField<double>(
          value: selectedRate,
          isDense: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 13,
          ),
          decoration: const InputDecoration(
            labelText: 'Interest Rate',
            labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          items: [
            ...available.map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(
                '${(entry.key * 100).toStringAsFixed(2)}% (R${entry.value})',
                style: const TextStyle(fontSize: 12),
              ),
            )),
            const DropdownMenuItem(
              value: -1.0,
              child: Text('Custom rate…', style: TextStyle(color: Colors.amber, fontSize: 12)),
            ),
          ],
          onChanged: (val) {
            if (val == -1.0) {
              setState(() => useCustomRate = true);
            } else if (val != null) {
              recalcWithRate(setState, val);
            }
          },
        );
      }
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: customRateController,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                labelText: 'Interest Rate (%)',
                labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                final r = double.tryParse(customRateController.text);
                if (r != null && r > 0) {
                  rateLocked = true;
                  selectedRate = r / 100;
                  recalc(setState, rateOverride: selectedRate);
                }
              },
            ),
          ),
          if (available.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() {
                useCustomRate = false;
                rateLocked = false;
                selectedRate = null;
                recalc(setState);
              }),
              child: const Text('Presets', style: TextStyle(fontSize: 10)),
            ),
          ],
        ],
      );
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Create Loan',
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        final isWide = MediaQuery.of(context).size.width > 600;

        // Trigger initial calculation so preview cards are visible immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          recalc(setState);
        });

        return StatefulBuilder(
          builder: (context, setState) {
            final rateLabel = interestBreakdown?['rateLabel'] as String?;
            final interestAmount = interestBreakdown?['interestAmount'] as double?;
            final totalRepayment = interestBreakdown?['totalRepayment'] as double?;
            final desc = interestBreakdown?['description'] as String?;

            final term = int.tryParse(termController.text) ?? 6;
            final amount = double.tryParse(amountController.text) ?? 0;
            final monthly = double.tryParse(monthlyController.text) ?? 0;

            final grandTotal = amount > 0
                ? ((monthly + 65) * term + 150).toStringAsFixed(0)
                : '--';

            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text(
                'Create New Loan',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 700 : MediaQuery.of(context).size.width * 0.85,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Row 1: Member + Amount ──
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedVendorId,
                                dropdownColor: Theme.of(context).cardColor,
                                                  style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Select Member',
                                  labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                items: members.map((member) {
                                  return DropdownMenuItem(
                                    value: member.id,
                                    child: Text(member.name, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => selectedVendorId = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                                  style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Loan Amount (R)',
                                  labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => recalc(setState),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          value: selectedVendorId,
                          dropdownColor: Theme.of(context).cardColor,
                                      style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Select Member',
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          items: members.map((member) {
                            return DropdownMenuItem(
                              value: member.id,
                              child: Text(member.name, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => selectedVendorId = val),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountController,
                                      style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Loan Amount (R)',
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => recalc(setState),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // ── Row 2: Duration + Interest Rate ──
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: termController,
                                                  style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Duration (Months)',
                                  labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => recalc(setState),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: buildRateSelector(setState)),
                          ],
                        )
                      else ...[
                        TextField(
                          controller: termController,
                                      style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Duration (Months)',
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => recalc(setState),
                        ),
                        const SizedBox(height: 10),
                        buildRateSelector(setState),
                      ],

                      if (interestBreakdown != null) ...[
                        const SizedBox(height: 10),

                        // ── Summary Cards ──
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildInterestCard(context, rateLabel, interestAmount, totalRepayment, desc)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildFeesCard(context)),
                            ],
                          )
                        else ...[
                          _buildInterestCard(context, rateLabel, interestAmount, totalRepayment, desc),
                          const SizedBox(height: 8),
                          _buildFeesCard(context),
                        ],

                        const SizedBox(height: 10),

                        // ── Monthly Payment ──
                        TextField(
                          controller: monthlyController,
                                      style: TextStyle(
                            color: monthlyManuallySet
                                ? Theme.of(context).textTheme.bodyMedium?.color
                                : Colors.grey[400],
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Monthly Payment (R)',
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                            helperText: monthlyManuallySet
                                ? 'Manually set'
                                : 'Auto-calculated',
                            helperStyle: TextStyle(color: AppTheme.primaryGold, fontSize: 9),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            setState(() => monthlyManuallySet = true);
                          },
                        ),

                        const SizedBox(height: 8),

                        // ── Total Loan Repayment ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryGold.withOpacity(0.15),
                                AppTheme.primaryGold.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.assignment, color: AppTheme.primaryGold, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Total Loan Repayment',
                                    style: TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _interestRow('Monthly Instalment', 'R${monthly.toStringAsFixed(0)}', Colors.white),
                              _interestRow('Monthly + Admin (R65)', 'R${(monthly + 65).toStringAsFixed(0)}', Colors.blueAccent),
                              _interestRow('Duration', '$term months', Colors.grey[400]!),
                              _interestRow('Initiation Fee (once-off)', 'R150.00', Colors.orangeAccent),
                              const Divider(color: Colors.white12, height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Grand Total',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'R$grandTotal',
                                    style: TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '(${monthly.toStringAsFixed(0)} + 65) × $term + 150 = R$grandTotal${desc != null && rateLabel != null ? '\n$rateLabel interest on principal' : ''}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 9),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Penalty (R59) only charged if a payment is overdue.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 8),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ── Grace Period ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        decoration: BoxDecoration(
                          color: gracePeriodEnabled
                              ? Colors.amber.withOpacity(0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: gracePeriodEnabled
                                ? Colors.amber.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.hourglass_empty,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Grace Period',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: gracePeriodEnabled,
                                  activeColor: AppTheme.primaryGold,
                                  onChanged: (val) => setState(() {
                                    gracePeriodEnabled = val;
                                    // Re-anchor the first-payment date
                                    final gp = int.tryParse(gracePeriodController.text) ?? 3;
                                    selectedFirstDate = DateTime.now()
                                        .add(Duration(days: 30 * (val ? gp : 1)));
                                  }),
                                ),
                              ],
                            ),
                            if (gracePeriodEnabled) ...[
                              const SizedBox(height: 6),
                              TextField(
                                controller: gracePeriodController,
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Grace Period Duration (months)',
                                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                  isDense: true,
                                  helperText: 'Min 1, max 12. Client only pays R150 init during grace.',
                                  helperStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  final gp = int.tryParse(gracePeriodController.text);
                                  if (gp != null && gp >= 1 && gp <= 12) {
                                    setState(() {
                                      selectedFirstDate = DateTime.now()
                                          .add(Duration(days: 30 * gp));
                                    });
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── First Instalment / First Payment Date ──
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          gracePeriodEnabled
                              ? 'First Payment Date (end of grace)'
                              : 'First Instalment Date',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        subtitle: Text(
                          '${selectedFirstDate.toLocal()}'.split(' ')[0],
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryGold, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedFirstDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setState(() => selectedFirstDate = picked);
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
                    final amount_ = double.tryParse(amountController.text) ?? 0;
                    final term_ = int.tryParse(termController.text) ?? 6;
                    final monthly_ = double.tryParse(monthlyController.text) ?? 0;
                    final rate = interestBreakdown?['rate'] as double?;

                    if (amount_ > 0 && selectedVendorId != null) {
                      setState(() => amountController.text = 'Submitting...');
                      try {
                        // Grace period validation
                        int? graceMonths;
                        if (gracePeriodEnabled) {
                          final parsed = int.tryParse(gracePeriodController.text);
                          if (parsed == null || parsed < 1 || parsed > 12) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Grace Period must be between 1 and 12 months.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setState(() => amountController.text = amount_.toString());
                            return;
                          }
                          graceMonths = parsed;
                        }

                        final newLoan = await context.read<LoanProvider>().addLoan(
                          LoanModel(
                            id: '',
                            groupId: widget.group.id,
                            vendorId: selectedVendorId,
                            amount: amount_,
                            durationMonths: term_,
                            monthlyPayment: monthly_,
                            initiationFee: 150,
                            monthlyAdminFee: 65,
                            penaltyFee: 59,
                            interestRate: rate,
                            status: 'Active',
                            firstInstalmentDate: selectedFirstDate,
                            firstPaymentDate: selectedFirstDate,
                            gracePeriodEnabled: gracePeriodEnabled,
                            gracePeriodMonths: graceMonths,
                            createdAt: DateTime.now(),
                          ),
                        );

                        this.setState(() {
                          _loans.insert(0, newLoan);
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Loan created successfully')),
                          );
                        }
                      } catch (e) {
                        setState(() => amountController.text = amount_.toString());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } else if (selectedVendorId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a member first')),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInterestCard(
    BuildContext context,
    String? rateLabel,
    double? interestAmount,
    double? totalRepayment,
    String? desc,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 13),
              const SizedBox(width: 5),
              Text('Interest Preview', style: TextStyle(color: Colors.amber.shade200, fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              Tooltip(
                message: desc ?? '',
                child: Icon(Icons.help_outline, color: Colors.grey[500], size: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _interestRow('Interest Rate', rateLabel ?? '--', Colors.amber),
          _interestRow('Interest Amount', 'R${interestAmount?.toStringAsFixed(2) ?? '--'}', Colors.amber.shade200),
          _interestRow('Principal + Interest', 'R${totalRepayment?.toStringAsFixed(2) ?? '--'}', Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildFeesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.blueGrey, size: 13),
              const SizedBox(width: 5),
              Text('Fees Breakdown', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          _interestRow('Initiation Fee (once-off)', 'R150.00', Colors.orangeAccent),
          _interestRow('Monthly Admin Fee', 'R65.00', Colors.blueAccent),
          _interestRow('Penalty (only if overdue)', 'R59.00', Colors.redAccent.withOpacity(0.6)),
          const Divider(color: Colors.white12, height: 6),
          _interestRow('Total Fees / Month', 'R65.00', Colors.white),
        ],
      ),
    );
  }

  Widget _interestRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Recalculates loan terms using the user-selected (or auto-detected)
  /// interest rate and updates the monthly controller. Returns the computed
  /// breakdown for the interest preview panel.
  Map<String, dynamic> _recalculateLoan(
    StateSetter setState,
    TextEditingController amountController,
    TextEditingController termController,
    TextEditingController monthlyController, {
    double? userRate,
    bool manualMonthly = false,
  }) {
    final amount = double.tryParse(amountController.text) ?? 0;
    final term = int.tryParse(termController.text) ?? 0;

    if (amount <= 0 || term <= 0) {
      if (!manualMonthly) {
        setState(() {
          monthlyController.text = '';
        });
      }
      return {};
    }

    const adminFee = 65.0;

    final rate = userRate ?? LoanInterestService.getRate(amount, term);
    if (rate == null || rate <= 0) {
      if (!manualMonthly) {
        setState(() {
          monthlyController.text = (amount / term).toStringAsFixed(0);
        });
      }
      return {};
    }

    final interestAmount = LoanInterestService.calculateInterestAmount(amount, rate);
    final totalRepayment = LoanInterestService.calculateTotalRepayment(amount, rate);
    final baseMonthly = totalRepayment / term;
    final totalMonthly = baseMonthly + adminFee;

    if (!manualMonthly) {
      setState(() {
        monthlyController.text = totalMonthly.toStringAsFixed(0);
      });
    }

    final isFromTable = LoanInterestService.getExactRate(amount, term) == rate;
    final desc = isFromTable
        ? 'Rate of ${(rate * 100).toStringAsFixed(2)}% applies to '
            'R${amount.toStringAsFixed(0)} over $term months.'
        : 'Using $rate% (user-selected or custom rate) '
            'for R${amount.toStringAsFixed(0)} over $term months.';

    return {
      'rate': rate,
      'rateLabel': '${(rate * 100).toStringAsFixed(2)}%',
      'interestAmount': interestAmount,
      'totalRepayment': totalRepayment,
      'baseMonthly': baseMonthly,
      'exact': LoanInterestService.isExactMatch(amount, term),
      'description': desc,
    };
  }

  void _showRecordPaymentDialog(LoanModel loan) {
    final monthlyAdminFee = LoanCalculationService.effectiveAdminFee(loan);
    final defaultAmount = (loan.monthlyPayment + monthlyAdminFee).toStringAsFixed(0);
    final amountController = TextEditingController(text: defaultAmount);
    String selectedType = 'Cash';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Record Payment',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recording payment for Loan R ${loan.amount}',
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
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: InputDecoration(
                  prefixText: 'R ',
                  prefixStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  helperText:
                      'R ${loan.monthlyPayment.toStringAsFixed(0)} monthly + R ${monthlyAdminFee.toStringAsFixed(0)} admin',
                  helperStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Date',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        selectedDate.toLocal().toString().split(' ')[0],
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
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
                if (amount <= 0) return;
                final dialogCtx = context;
                final payProvider = context.read<PaymentProvider>();
                runWithLoadingAfterPop(
                  dialogCtx, task: () async {
                    await payProvider.addPayment(
                      PaymentModel(
                        id: '',
                        loanId: loan.id,
                        amountPaid: amount,
                        paymentMethod: selectedType,
                        datePaid: selectedDate,
                        createdAt: DateTime.now(),
                      ),
                      loan: loan,
                    );
                  },
                  successMessage: 'Payment recorded successfully!',
                );
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMemberDialog(List<VendorModel> members) async {
    final supabase = Supabase.instance.client;
    final dfResponse = await supabase.from('profiles').select().eq('role', 'Development Facilitator');
    final dfProfiles = dfResponse as List;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final idController = TextEditingController();
    final businessController = TextEditingController();
    final whatsappController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final savingsAmountController = TextEditingController(text: '0');
    String selectedGender = 'F';
    String selectedRole = 'Member';
    String selectedFrequency = 'Monthly';
    DateTime selectedSavingsDate = DateTime.now();
    String? selectedDfId;
    String? selectedDfName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Add New Member',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: idController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'ID Number',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
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
                              setState(() => selectedRole = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('M')),
                            DropdownMenuItem(value: 'F', child: Text('F')),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedGender = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            labelStyle: TextStyle(color: Colors.grey),
                          ),
                          onChanged: (val) {
                            if (whatsappController.text.isEmpty)
                              whatsappController.text = val;
                          },
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: whatsappController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextField(
                    controller: emailController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextField(
                    controller: businessController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Business Type',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedDfId,
                    isExpanded: true,
                    hint: const Text('Select DF'),
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'DF Name',
                      labelStyle: TextStyle(color: Colors.grey),
                    ),
                    items: dfProfiles
                        .map((p) => DropdownMenuItem(
                              value: p['id'] as String,
                              child: Text(p['full_name'] ?? p['email'] ?? 'Unknown'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedDfId = val;
                        selectedDfName = val != null
                            ? (dfProfiles.firstWhere((p) => p['id'] == val)['full_name'] ??
                                dfProfiles.firstWhere((p) => p['id'] == val)['email'] ??
                                'Unknown')
                            : null;
                      });
                    },
                  ),
                  TextField(
                    controller: addressController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: const InputDecoration(
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
                      'Savings Plan',
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
                            labelText: 'Savings Amount (R)',
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
                if (nameController.text.isEmpty) return;
                final vendorProvider = context.read<VendorProvider>();
                final duplicate = await vendorProvider.checkDuplicateVendor(
                  idNumber: idController.text,
                  phone: phoneController.text,
                );

                if (duplicate != null && context.mounted) {
                  _showDuplicateAlert(
                    duplicate,
                    idController.text,
                    phoneController.text,
                  );
                  return;
                }

                final dialogCtx = context;
                final vendor = VendorModel(
                  id: '',
                  groupId: widget.group.id,
                  name: nameController.text,
                  phone: phoneController.text,
                  idNumber: idController.text,
                  gender: selectedGender,
                  businessType: businessController.text,
                  dfId: selectedDfId,
                  dfName: selectedDfName,
                  whatsappNumber: whatsappController.text,
                  email: emailController.text,
                  address: addressController.text,
                  role: selectedRole,
                  savingsAmount:
                      double.tryParse(savingsAmountController.text) ?? 0,
                  savingsFrequency: selectedFrequency,
                  savingsStartDate: selectedSavingsDate,
                  referenceNumber: widget.group.name
                      .substring(0, 3)
                      .toUpperCase(),
                  createdAt: DateTime.now(),
                );
                runWithLoadingAfterPop(
                  dialogCtx, task: () async {
                    await vendorProvider.addVendor(vendor);
                    _loadData();
                  },
                  successMessage: 'Member added successfully.',
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordGroupPaymentDialog(List<VendorModel> members) {
    final activeLoans = _loans.where((l) => l.status == 'Active').toList();
    if (activeLoans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active loans found in this group.')),
      );
      return;
    }

    double totalExpected = activeLoans.fold(
      0.0,
      (sum, l) => sum + l.monthlyPayment + LoanCalculationService.effectiveAdminFee(l),
    );
    bool isSubmitting = false;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: AppTheme.primaryGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Record Group Payment',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will record individual monthly payments for all members with active loans in this group.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Active Loans',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '${activeLoans.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Aggregated Amount',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'R ${totalExpected.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Breakdown:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeLoans.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final loan = activeLoans[index];
                      final member = members.firstWhere(
                        (m) => m.id == loan.vendorId,
                        orElse: () => VendorModel(
                          id: '',
                          groupId: '',
                          name: 'Unknown',
                          createdAt: DateTime.now(),
                        ),
                      );
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          member.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          'R ${loan.monthlyPayment}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Payment Date', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          selectedDate.toLocal().toString().split(' ')[0],
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      try {
                        final paymentProvider = context.read<PaymentProvider>();
                        List<PaymentModel> memberPayments = activeLoans.map((
                          loan,
                        ) {
                          final loanPayments = paymentProvider.payments
                              .where((p) => p.loanId == loan.id)
                              .toList();
                          final currentBalance =
                              LoanCalculationService.calculateBalance(
                                loan,
                                loanPayments,
                              );
                          // Cap payment at remaining balance
                          final amountToPay =
                              loan.monthlyPayment > currentBalance
                              ? currentBalance
                              : loan.monthlyPayment;

                          return PaymentModel(
                            id: '',
                            loanId: loan.id,
                            amountPaid: amountToPay,
                             datePaid: selectedDate,
                             createdAt: DateTime.now(),
                          );
                        }).toList();

                        await context.read<PaymentProvider>().addGroupPayment(
                          widget.group.id,
                          memberPayments,
                          loans: activeLoans,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Group payment recorded successfully!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Group Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDuplicateAlert(
    VendorModel duplicate,
    String inputId,
    String inputPhone,
  ) {
    final idMatch =
        inputId.trim().isNotEmpty &&
        duplicate.idNumber?.trim() == inputId.trim();
    final matchField = idMatch ? 'ID Number' : 'Phone Number';
    final matchValue = idMatch
        ? (duplicate.idNumber ?? '')
        : (duplicate.phone ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Duplicate Member Detected',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A member with this $matchField ($matchValue) already exists: ${duplicate.name}',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMemberConfirm(VendorModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Delete Member',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove ${member.name} from this group?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final ctx = context;
              runWithLoadingAfterPop(
                ctx, task: () async {
                  await ctx.read<VendorProvider>().deleteVendor(member.id);
                  _loadData();
                },
                successMessage: 'Member deleted.',
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
  }

  Future<void> _downloadGroupStatement(List<VendorModel> members) async {
    runWithLoading(context, task: () async {
      final commentProvider = context.read<CommentProvider>();
      final paymentProvider = context.read<PaymentProvider>();
      final allPayments = paymentProvider.payments;
      final loanIds = _loans.map((loan) => loan.id).toSet();
      final groupPayments = allPayments
          .where((payment) => loanIds.contains(payment.loanId))
          .toList();
      double totalLiability = 0;
      for (final loan in _loans) {
        final loanPayments = groupPayments
            .where((p) => p.loanId == loan.id)
            .toList();
        totalLiability += loan.openingAmount != null
            ? loan.openingAmount! + LoanCalculationService.calculateAppliedPenalty(loan, loanPayments)
            : (loan.monthlyPayment + LoanCalculationService.effectiveAdminFee(loan)) * loan.durationMonths +
            LoanCalculationService.effectiveInitiationFee(loan) +
            LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);
      }
      final totalPaid = groupPayments.fold<double>(
        0,
        (sum, p) => sum + p.amountPaid,
      );
      final balance = totalLiability - totalPaid;
      final totalSavings = members.fold(
        0.0,
        (sum, m) => sum + (m.savingsAmount ?? 0.0),
      );

      final logo = await PdfBranding.loadLogo();
      final pdf = pw.Document();
      final generatedDate = _formatDate(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, height: 50),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Group Statement Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Reference: ${widget.group.referenceNumber}'),
                  pw.Text('Date: $generatedDate'),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          build: (_) {
            final sortedPayments = [...groupPayments]
              ..sort((a, b) => b.datePaid.compareTo(a.datePaid));

            // Calculate running balances for each loan
            final ascPayments = [...groupPayments]
              ..sort((a, b) => a.datePaid.compareTo(b.datePaid));
            final Map<String, double> paymentBalances = {};
            final Map<String, double> loanInitialLiability = {};

            for (final loan in _loans) {
              final loanPayments = groupPayments
                  .where((p) => p.loanId == loan.id)
                  .toList();
              loanInitialLiability[loan.id] = loan.openingAmount != null
                  ? loan.openingAmount! + LoanCalculationService.calculateAppliedPenalty(loan, loanPayments)
                  : (loan.monthlyPayment + LoanCalculationService.effectiveAdminFee(loan)) * loan.durationMonths +
                  LoanCalculationService.effectiveInitiationFee(loan) +
                  LoanCalculationService.calculateAppliedPenalty(
                    loan,
                    loanPayments,
                  );
            }

            final Map<String, double> runningLoanBalances = Map.from(
              loanInitialLiability,
            );
            for (var p in ascPayments) {
              runningLoanBalances[p.loanId] =
                  (runningLoanBalances[p.loanId] ?? 0) - p.amountPaid;
              paymentBalances[p.id] = runningLoanBalances[p.loanId]!;
            }

            return [
              pw.SizedBox(height: 20),
              pw.Text(
                'Group Information',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
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
                        _pdfInfoRow('Group Name', widget.group.name),
                        _pdfInfoRow('Reference', widget.group.referenceNumber),
                        _pdfInfoRow(
                          'Created On',
                          _formatDate(widget.group.createdAt),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoRow(
                          'Total Members',
                          members.length.toString(),
                        ),
                        _pdfInfoRow('Total Loans', _loans.length.toString()),
                        _pdfInfoRow('Generated On', generatedDate),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Financial Summary',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStatItem(
                    'Total Liability',
                    _formatCurrency(totalLiability),
                  ),
                  _pdfStatItem('Total Paid', _formatCurrency(totalPaid)),
                  _pdfStatItem('Outstanding', _formatCurrency(balance)),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Group Members',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              members.isEmpty
                  ? pw.Text(
                      'No members found.',
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
                            _pdfCell('Name', isBold: true),
                            _pdfCell('Phone', isBold: true),
                            _pdfCell('Business', isBold: true),
                          ],
                        ),
                        ...members.map(
                          (member) => pw.TableRow(
                            children: [
                              _pdfCell(member.name),
                              _pdfCell(member.phone ?? '-'),
                              _pdfCell(member.businessType ?? '-'),
                            ],
                          ),
                        ),
                      ],
                    ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Savings Plan Summary',
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
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      _pdfCell('Member Name', isBold: true),
                      _pdfCell('Savings Amount', isBold: true),
                      _pdfCell('Frequency', isBold: true),
                      _pdfCell('Start Date', isBold: true),
                    ],
                  ),
                  ...members.map(
                    (member) => pw.TableRow(
                      children: [
                        _pdfCell(member.name),
                        _pdfCell(
                          'R ${member.savingsAmount?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                        _pdfCell(member.savingsFrequency ?? 'Monthly'),
                        _pdfCell(
                          member.savingsStartDate != null
                              ? _formatDate(member.savingsStartDate!)
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    children: [
                      _pdfCell('Total Group Savings', isBold: true),
                      _pdfCell(_formatCurrency(totalSavings), isBold: true),
                      _pdfCell(''),
                      _pdfCell(''),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 32),

              // Group Comments Section
              if (commentProvider.comments.isNotEmpty) ...[
                pw.Text(
                  'Group Comments & Timeline',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 10),
                ...commentProvider.comments.map((comment) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${comment.authorName} (${comment.authorRole ?? "Staff"})',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              _formatDate(comment.createdAt),
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.black,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          comment.content,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        if (comment.mentionedVendorIds.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Mentioned: ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Text(
                                comment.mentionedVendorIds
                                    .map((id) {
                                      return members
                                              .where((m) => m.id == id)
                                              .firstOrNull
                                              ?.name ??
                                          'Unknown';
                                    })
                                    .join(', '),
                                  style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 24),
              ],

              pw.Text(
                'Loan History',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _loans.isEmpty
                  ? pw.Text(
                      'No loans found.',
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
                            _pdfCell('Member', isBold: true),
                            _pdfCell('Amount', isBold: true),
                            _pdfCell('Duration', isBold: true),
                            _pdfCell('Monthly', isBold: true),
                            _pdfCell('Status', isBold: true),
                          ],
                        ),
                        ..._loans.map(
                          (loan) => pw.TableRow(
                            children: [
                              _pdfCell(_memberNameById(loan.vendorId, members)),
                              _pdfCell('R ${loan.amount.toStringAsFixed(0)}'),
                              _pdfCell('${loan.durationMonths} Months'),
                              _pdfCell(
                                'R ${loan.monthlyPayment.toStringAsFixed(0)}',
                              ),
                              _pdfCell(loan.status),
                            ],
                          ),
                        ),
                      ],
                    ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Payment History',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              sortedPayments.isEmpty
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
                            _pdfCell('Loan', isBold: true),
                            _pdfCell('Balance', isBold: true),
                          ],
                        ),
                        ...sortedPayments.map(
                          (payment) => pw.TableRow(
                            children: [
                              _pdfCell(_formatDate(payment.datePaid)),
                              _pdfCell(_formatCurrency(payment.amountPaid)),
                              _pdfCell(payment.paymentMethod ?? 'Manual'),
                              _pdfCell(_loanLabelById(payment.loanId)),
                              _pdfCell(
                                _formatCurrency(
                                  paymentBalances[payment.id] ?? 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ];
          },
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              '-- ${context.pageNumber} of ${context.pagesCount} --',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name:
            'Group_Statement_${widget.group.referenceNumber}_${DateTime.now().toString().substring(0, 10)}',
      );
    }, successMessage: 'Group statement generated.');
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.SizedBox(
              width: 84,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _pdfStatItem(String label, String value) {
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

  String _memberNameById(String? vendorId, List<VendorModel> members) {
    if (vendorId == null) return 'Unknown';
    for (final member in members) {
      if (member.id == vendorId) return member.name;
    }
    return 'Unknown';
  }

  String _loanLabelById(String loanId) {
    for (final loan in _loans) {
      if (loan.id == loanId) {
        return 'R ${loan.amount.toStringAsFixed(0)}';
      }
    }
    return '-';
  }

  String _formatCurrency(double amount) => 'R ${amount.toStringAsFixed(2)}';

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Helper widget used inside the duplicate-detection alert dialog.
  Widget _dupRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.redAccent),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete the group "$_currentName"? This will permanently remove the group record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final groupId = widget.group.id;
              final groupName = _currentName;
              final ctx = context;
              final deleted = await runWithLoadingAfterPop(
                ctx, task: () async {
                  await ctx.read<GroupProvider>().deleteGroup(groupId);
                  await Future.wait<void>([
                    ctx.read<LoanProvider>().fetchLoans(forceRefresh: true),
                    ctx.read<VendorProvider>().fetchVendors(
                      forceRefresh: true,
                    ),
                    ctx.read<PaymentProvider>().fetchPayments(
                      forceRefresh: true,
                    ),
                  ]);
                },
                successMessage:
                    'Group "$groupName" and all associated data deleted',
              );
              if (deleted != null && ctx.mounted) {
                Navigator.pop(ctx); // Return to groups screen
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(ThemeData theme) {
    final docProvider = context.watch<DocumentProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Supporting Documents',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
                                groupId: widget.group.id,
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
              label: Text(
                docProvider.isLoading ? 'Uploading...' : 'Upload Documents',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
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
                          if (AccessControlService.canEditData(
                            context.read<AuthProvider>().userProfile,
                          ))
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

  void _showCommentDetailsDialog(CommentModel comment, List<VendorModel> members) {
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
                      _formatDate(comment.createdAt),
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
                if (comment.mentionedVendorIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Mentions:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: comment.mentionedVendorIds.map((id) {
                      final name =
                          members.where((m) => m.id == id).firstOrNull?.name ??
                          'Unknown';
                      return Chip(
                        label: Text(name, style: const TextStyle(fontSize: 11)),
                        backgroundColor: theme.primaryColor.withOpacity(0.05),
                      );
                    }).toList(),
                  ),
                ],
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
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Comment deleted')),
                              );
                            }
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
                  final text = _editController.text.trim();
                  final ctx = context;
                  runWithLoadingAfterPop(
                    ctx, task: () async {
                      await commentProvider.updateComment(comment.id, text);
                    },
                    successMessage: 'Comment updated',
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

  void _showGroupCommunicationDialog(List<VendorModel> members) {
    showDialog(
      context: context,
      builder: (context) => GroupCommunicationDialog(
        group: widget.group,
        members: members,
      ),
    );
  }
}
