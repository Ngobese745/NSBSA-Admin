import 'package:flutter/material.dart';

import '../core/pdf_branding.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/vendor_provider.dart';
import '../providers/group_provider.dart';
import '../providers/center_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vendor.dart';
import '../models/group.dart';
import 'vendor_profile_screen.dart';
import '../widgets/communication/communication_dialog.dart';
import '../widgets/communication/group_communication_dialog.dart';
import '../services/vendor_pdf_service.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';

import 'package:shared_preferences/shared_preferences.dart';

class _VendorHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _VendorHeaderAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
      ),
    );
  }
}

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _loadViewState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().fetchVendors();
      context.read<GroupProvider>().fetchGroups();
      context.read<LoanProvider>().fetchLoans();
    });
  }

  Future<void> _loadViewState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isGridView = prefs.getBool('vendors_view_is_grid') ?? false;
      });
    }
  }

  Future<void> _toggleView() async {
    final newState = !_isGridView;
    setState(() => _isGridView = newState);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vendors_view_is_grid', newState);
  }

  Future<void> _generateVendorListPDF(BuildContext context) async {
    final provider = context.read<VendorProvider>();
    final groupProvider = context.read<GroupProvider>();
    final pdf = pw.Document();

    final logo = await PdfBranding.loadLogo();

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
                    'NSBSA Member Directory',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Export Date: ${DateTime.now().toString().substring(0, 10)}',
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Name', isBold: true),
                    _pdfCell('Ref Number', isBold: true),
                    _pdfCell('Group', isBold: true),
                    _pdfCell('Phone', isBold: true),
                    _pdfCell('ID Number', isBold: true),
                    _pdfCell('Business', isBold: true),
                  ],
                ),
                ...provider.vendors.map((vendor) {
                  final group = groupProvider.groups
                      .where((g) => g.id == vendor.groupId)
                      .firstOrNull;
                  return pw.TableRow(
                    children: [
                      _pdfCell(vendor.name),
                      _pdfCell(vendor.referenceNumber ?? '-'),
                      _pdfCell(group?.name ?? '-'),
                      _pdfCell(vendor.phone ?? '-'),
                      _pdfCell(vendor.idNumber ?? '-'),
                      _pdfCell(vendor.businessType ?? '-'),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'NSBSA_Member_Directory_${DateTime.now().toString().substring(0, 10)}',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ───
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Members',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _VendorHeaderAction(
                  icon: _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
                  tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                  onPressed: _toggleView,
                ),
                if (isSmall) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    tooltip: 'More Actions',
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onSelected: (value) {
                      if (value == 'message') {
                        final provider = context.read<VendorProvider>();
                        showDialog(
                          context: context,
                          builder: (context) => GroupCommunicationDialog(
                            members: provider.vendors,
                            customTitle: 'General Announcement',
                          ),
                        );
                      } else if (value == 'export') {
                        _generateVendorListPDF(context);
                      } else if (value == 'add') {
                        _showAddMemberDialog(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'message',
                        child: ListTile(
                          leading: Icon(Icons.send_rounded, size: 18, color: AppTheme.primaryGold),
                          title: Text('Message All'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: Icon(Icons.download, size: 18),
                          title: Text('Export PDF'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add',
                        child: ListTile(
                          leading: Icon(Icons.person_add, size: 18),
                          title: Text('Add Member'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  _VendorHeaderAction(
                    icon: Icons.send_rounded,
                    tooltip: 'Message All',
                    onPressed: () {
                      final provider = context.read<VendorProvider>();
                      showDialog(
                        context: context,
                        builder: (context) => GroupCommunicationDialog(
                          members: provider.vendors,
                          customTitle: 'General Announcement',
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _VendorHeaderAction(
                    icon: Icons.download_rounded,
                    tooltip: 'Export PDF',
                    onPressed: () => _generateVendorListPDF(context),
                  ),
                  const SizedBox(width: 4),
                  _VendorHeaderAction(
                    icon: Icons.person_add,
                    tooltip: 'Add Member',
                    onPressed: () => _showAddMemberDialog(context),
                  ),
                ],
              ],
            ),
          ),

          // ─── Body ───
          Expanded(
            child: Consumer<VendorProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.vendors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No members found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => _showAddMemberDialog(context),
                          child: const Text('Add Member'),
                        ),
                      ],
                    ),
                  );
                }

                if (_isGridView) {
                  return _buildGridView(provider.vendors, theme);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${provider.vendors.length} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.5),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Table(
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            columnWidths: {
                              0: const FlexColumnWidth(2.2),
                              1: const FlexColumnWidth(1.3),
                              2: const FlexColumnWidth(1.5),
                              3: const FlexColumnWidth(1.3),
                              4: const FlexColumnWidth(1.3),
                              5: const FlexColumnWidth(1.5),
                              6: FlexColumnWidth(isSmall ? 1 : 1.2),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: theme.dividerColor.withOpacity(0.15),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                children: [
                                  _th('Member Name'),
                                  _th('Ref Number'),
                                  _th('Group'),
                                  _th('Phone'),
                                  _th('ID Number'),
                                  _th('Business'),
                                  _th(''),
                                ],
                              ),
                              ...provider.vendors.map((vendor) {
                                final group = context.read<GroupProvider>().groups
                                    .where((g) => g.id == vendor.groupId)
                                    .firstOrNull;
                                return TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.dividerColor.withOpacity(0.06),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                VendorProfileScreen(vendor: vendor),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: vendor.avatarUrl != null && vendor.avatarUrl!.isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Image.network(
                                                        vendor.avatarUrl!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.person,
                                                      size: 14,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                vendor.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _td(vendor.referenceNumber ?? '-'),
                                    _td(group?.name ?? '-'),
                                    _td(vendor.phone ?? '-'),
                                    _td(vendor.idNumber ?? '-'),
                                    _td(vendor.businessType ?? '-'),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _actionIcon(
                                            icon: Icons.message,
                                            color: Colors.green,
                                            tooltip: 'Send Message',
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    CommunicationDialog(vendor: vendor),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          _actionIcon(
                                            icon: Icons.chevron_right,
                                            color: (theme.textTheme.bodySmall?.color ?? Colors.grey).withOpacity(0.4),
                                            tooltip: 'View Profile',
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      VendorProfileScreen(vendor: vendor),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _td(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildGridView(List<VendorModel> vendors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 160,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: vendors.length,
        itemBuilder: (context, index) {
          final vendor = vendors[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VendorProfileScreen(vendor: vendor),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: vendor.avatarUrl != null && vendor.avatarUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              vendor.avatarUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    vendor.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vendor.referenceNumber ?? 'N/A',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _actionIcon(
                        icon: Icons.message,
                        color: Colors.green,
                        tooltip: 'Send Message',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CommunicationDialog(vendor: vendor),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _actionIcon(
                        icon: Icons.download_rounded,
                        color: AppTheme.primaryGold,
                        tooltip: 'Download Profile PDF',
                        onPressed: () {
                          final loanProvider = context.read<LoanProvider>();
                          final groupProvider = context.read<GroupProvider>();

                          final vendorLoans = loanProvider.loans
                              .where((l) => l.vendorId == vendor.id)
                              .toList();

                          final group = groupProvider.groups.firstWhere(
                            (g) => g.id == vendor.groupId,
                            orElse: () => GroupModel.unknown(),
                          );

                          VendorPdfService.generateProfilePDF(
                            context: context,
                            vendor: vendor,
                            group: group,
                            loans: vendorLoans,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();

    final nameController = TextEditingController();
    final idNumberController = TextEditingController();
    final phoneController = TextEditingController();
    final whatsappController = TextEditingController();
    final emailController = TextEditingController();
    final businessController = TextEditingController();
    final addressController = TextEditingController();
    final newGroupNameController = TextEditingController();

    String? selectedGroupId;
    String? selectedCenterId;
    String selectedGender = 'F';
    String selectedRole = 'Member';
    bool isNewGroup = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);

            return AlertDialog(
              title: const Text('Add New Member'),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'GROUP'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: isNewGroup
                                ? TextField(
                                    controller: newGroupNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'New Group Name',
                                      hintText: 'Enter group name',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: selectedGroupId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Existing Group',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    items: groupProvider.groups
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g.id,
                                            child: Text(g.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => selectedGroupId = val),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => isNewGroup = !isNewGroup),
                            icon: Icon(
                              isNewGroup
                                  ? Icons.list
                                  : Icons.add_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              isNewGroup ? 'Existing Group' : 'New Group',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (isNewGroup) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedCenterId,
                          hint: const Text('Assign to Center'),
                          items: context
                              .read<CenterProvider>()
                              .centers
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedCenterId = val),
                          decoration: const InputDecoration(
                            labelText: 'Assigned Center',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SectionLabel(label: 'MEMBER INFORMATION'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: idNumberController,
                              decoration: const InputDecoration(
                                labelText: 'ID Number',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: DropdownButtonFormField<String>(
                              value: selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'M', child: Text('M')),
                                DropdownMenuItem(value: 'F', child: Text('F')),
                              ],
                              onChanged: (val) =>
                                  setState(() => selectedGender = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              onChanged: (val) {
                                if (whatsappController.text.isEmpty) {
                                  whatsappController.text = val;
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: whatsappController,
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp Number',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: businessController,
                        decoration: const InputDecoration(
                          labelText: 'Business Type',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Home Address',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    if (isNewGroup && newGroupNameController.text.isEmpty) {
                      _showError(context, 'Please enter a group name');
                      return;
                    }
                    if (!isNewGroup && selectedGroupId == null) {
                      _showError(context, 'Please select a group');
                      return;
                    }
                    if (nameController.text.isEmpty) {
                      _showError(context, 'Full name is required');
                      return;
                    }

                    try {
                      final vendorProvider = context.read<VendorProvider>();

                      final duplicate = await vendorProvider
                          .checkDuplicateVendor(
                            idNumber: idNumberController.text,
                            phone: phoneController.text,
                          );

                      if (duplicate != null && context.mounted) {
                        _showError(
                          context,
                          'A member with this ID or Phone already exists: ${duplicate.name}',
                        );
                        return;
                      }

                      String groupId = selectedGroupId ?? '';
                      String ref = '';

                      if (isNewGroup) {
                        if (selectedCenterId == null) {
                          _showError(
                            context,
                            'Please select a Center for the new group',
                          );
                          return;
                        }
                        final newRef =
                            'GRP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                        final authProvider = context.read<AuthProvider>();
                        final newGroup = await groupProvider
                            .addGroupWithMembers(
                              newGroupNameController.text,
                              newRef,
                              selectedCenterId!,
                              [],
                              creatorId: authProvider.userProfile?.id,
                              creatorName: authProvider.userProfile?.fullName,
                            );
                        groupId = newGroup.id;
                        ref = newRef;
                      } else {
                        final group = groupProvider.groups.firstWhere(
                          (g) => g.id == groupId,
                        );
                        ref = group.referenceNumber;
                      }

                      final newVendor = VendorModel(
                        id: '',
                        groupId: groupId,
                        name: nameController.text,
                        idNumber: idNumberController.text,
                        phone: phoneController.text,
                        whatsappNumber: whatsappController.text,
                        email: emailController.text,
                        gender: selectedGender,
                        businessType: businessController.text,
                        address: addressController.text,
                        role: selectedRole,
                        referenceNumber: ref,
                        createdAt: DateTime.now(),
                      );

                      await vendorProvider.addVendor(newVendor);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Member added successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted)
                        _showError(context, 'Error adding member: $e');
                    }
                  },
                  child: const Text('Save Member'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
