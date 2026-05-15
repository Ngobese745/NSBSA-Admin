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

import 'package:shared_preferences/shared_preferences.dart';

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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vendors / Members',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Builder(
                builder: (context) {
                  final isSmall = MediaQuery.of(context).size.width < 800;
                  return Row(
                    children: [
                      IconButton(
                        onPressed: _toggleView,
                        icon: Icon(
                          _isGridView ? Icons.list_rounded : Icons.grid_view_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                        tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
                      ),
                      if (isSmall) ...[
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          tooltip: 'More Actions',
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
                                leading: Icon(Icons.send_rounded, size: 20, color: Color(0xFFD4AF37)),
                                title: Text('Message All'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'export',
                              child: ListTile(
                                leading: Icon(Icons.download, size: 20),
                                title: Text('Export PDF'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'add',
                              child: ListTile(
                                leading: Icon(Icons.person_add, size: 20),
                                title: Text('Add Member'),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
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
                          icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFFD4AF37)),
                          label: const Text('Message All'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _generateVendorListPDF(context),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddMemberDialog(context),
                          icon: const Icon(Icons.person_add, size: 16),
                          label: const Text('Add Member'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Consumer<VendorProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.vendors.isEmpty) {
                    return const Center(
                      child: Text(
                        'No members found.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  }

                  if (_isGridView) {
                    return _buildGridView(provider.vendors, theme);
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: provider.vendors.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final vendor = provider.vendors[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          backgroundImage: vendor.avatarUrl != null && vendor.avatarUrl!.isNotEmpty
                              ? NetworkImage(vendor.avatarUrl!)
                              : null,
                          child: vendor.avatarUrl == null || vendor.avatarUrl!.isEmpty
                              ? Icon(
                                  Icons.person,
                                  color: theme.primaryColor,
                                  size: 14,
                                )
                              : null,
                        ),
                        title: Text(
                          vendor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'Ref: ${vendor.referenceNumber ?? 'N/A'} • ${vendor.phone ?? 'No Phone'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.message,
                                color: Colors.green,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      CommunicationDialog(vendor: vendor),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VendorProfileScreen(vendor: vendor),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<VendorModel> vendors, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 180,
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  backgroundImage: vendor.avatarUrl != null && vendor.avatarUrl!.isNotEmpty
                      ? NetworkImage(vendor.avatarUrl!)
                      : null,
                  child: vendor.avatarUrl == null || vendor.avatarUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          color: theme.primaryColor,
                          size: 30,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  vendor.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vendor.referenceNumber ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.green, size: 18),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => CommunicationDialog(vendor: vendor),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Color(0xFFD4AF37), size: 18),
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
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Group Selection',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
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
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: selectedGroupId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Existing Group',
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
                            ),
                            label: Text(
                              isNewGroup ? 'Existing Group' : 'New Group',
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
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Member Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: idNumberController,
                              decoration: const InputDecoration(
                                labelText: 'ID Number',
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
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
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: businessController,
                        decoration: const InputDecoration(
                          labelText: 'Business Type',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Home Address',
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    // Validation
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

                      // Check for duplicates
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
