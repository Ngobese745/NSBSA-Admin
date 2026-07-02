import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/providers.dart';
import '../services/access_control_service.dart';
import '../models/center.dart';
import '../models/leadership.dart';
import '../models/group.dart';

class CenterManagementScreen extends StatefulWidget {
  const CenterManagementScreen({super.key});

  @override
  State<CenterManagementScreen> createState() => _CenterManagementScreenState();
}

class _CenterManagementScreenState extends State<CenterManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CenterProvider>().fetchCenters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final centerProvider = context.watch<CenterProvider>();
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
                'Centers',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCenterDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Center'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: centerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: centerProvider.centers.length,
                    itemBuilder: (context, index) {
                      final center = centerProvider.centers[index];
                      final groupsInCenter = groupProvider.groups
                          .where((g) => g.centerId == center.id)
                          .toList();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          leading: Icon(
                            Icons.business,
                            color: theme.primaryColor,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                center.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (center.name != 'Main Center' && AccessControlService.canEditData(
                                context.read<AuthProvider>().userProfile,
                              ))
                                IconButton(
                                  onPressed: () => _deleteCenter(
                                    context,
                                    center,
                                    groupsInCenter.length,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  tooltip: 'Delete Center',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                'Ref: ${center.referenceNumber} • ${groupsInCenter.length} Groups',
                              ),
                              const SizedBox(width: 8),
                              if (center.dfName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'DF: ${center.dfName}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () =>
                                    _showAssignDFDialog(context, center),
                                icon: const Icon(Icons.person_outline, size: 14),
                                label: Text(
                                  center.dfName == null
                                      ? 'Assign DF'
                                      : 'Change DF',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Leadership',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showAssignLeaderDialog(
                                              context,
                                              center.id,
                                            ),
                                        icon: const Icon(
                                          Icons.person_add,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Assign Leader',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _LeadershipSection(centerId: center.id),
                                  const Divider(height: 32),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Groups under this Center',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          _buildCapacityIndicator(
                                            groupsInCenter.length,
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () =>
                                                _showAssignGroupDialog(
                                                  context,
                                                  center.id,
                                                ),
                                            icon: const Icon(
                                              Icons.add_link,
                                              size: 18,
                                            ),
                                            tooltip:
                                                'Link Group to this Center',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (groupsInCenter.isEmpty)
                                    const Text(
                                      'No groups linked to this center.',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: groupsInCenter
                                          .map(
                                            (g) => Chip(
                                              label: Text(
                                                g.name,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              backgroundColor: theme
                                                  .primaryColor
                                                  .withOpacity(0.05),
                                              onDeleted: () =>
                                                  _removeGroupFromCenter(
                                                    context,
                                                    g,
                                                  ),
                                              deleteIcon: const Icon(
                                                Icons.close,
                                                size: 12,
                                                color: Colors.red,
                                              ),
                                              deleteButtonTooltipMessage:
                                                  'Remove from Center',
                                            ),
                                          )
                                          .toList(),
                                    ),
                                ],
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

  void _showAssignGroupDialog(BuildContext context, String centerId) {
    String? selectedGroupId;
    final groupProvider = context.read<GroupProvider>();
    final availableGroups = groupProvider.groups
        .where((g) => g.centerId != centerId)
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Link Group to Center'),
          content: DropdownButtonFormField<String>(
            value: selectedGroupId,
            hint: const Text('Select Group'),
            items: availableGroups
                .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
                .toList(),
            onChanged: (val) => setState(() => selectedGroupId = val),
            decoration: const InputDecoration(labelText: 'Group'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedGroupId == null
                  ? null
                  : () async {
                      final group = availableGroups.firstWhere(
                        (g) => g.id == selectedGroupId,
                      );
                      await context.read<GroupProvider>().updateGroup(
                        selectedGroupId!,
                        group.name,
                        centerId: centerId,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeGroupFromCenter(BuildContext context, GroupModel group) async {
    final centerProvider = context.read<CenterProvider>();
    final groupProvider = context.read<GroupProvider>();

    // Find the "Main Center" to act as a fallback
    final mainCenter = centerProvider.centers.firstWhere(
      (c) => c.name == 'Main Center',
      orElse: () => centerProvider.centers.first,
    );

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Center'),
        content: Text(
          'Are you sure you want to remove "${group.name}" from this center? it will be reassigned to "${mainCenter.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await groupProvider.updateGroup(
        group.id,
        group.name,
        centerId: mainCenter.id,
      );
    }
  }

  void _deleteCenter(
    BuildContext context,
    CenterModel center,
    int groupCount,
  ) async {
    if (groupCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Center'),
          content: Text(
            'The center "${center.name}" contains $groupCount groups. Please reassign or remove all groups before deleting the center.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Center'),
        content: Text(
          'Are you sure you want to delete the center "${center.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<CenterProvider>().deleteCenter(center.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Center "${center.name}" deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting center: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAssignDFDialog(BuildContext context, CenterModel center) async {
    String? selectedProfileId = center.dfId;
    // Fetch profiles with DF role
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('role', 'Development Facilitator');
    final profiles = response as List;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Assign DF to ${center.name}'),
          content: DropdownButtonFormField<String>(
            value: selectedProfileId,
            hint: const Text('Select Development Facilitator'),
            items: profiles
                .map((p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['full_name'] ?? p['email'] ?? 'Unknown'),
                    ))
                .toList(),
            onChanged: (val) => setState(() => selectedProfileId = val),
            decoration: const InputDecoration(labelText: 'Facilitator'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedProfileId == null
                  ? null
                  : () async {
                      final profile = profiles.firstWhere(
                        (p) => p['id'] == selectedProfileId,
                      );
                      await context.read<CenterProvider>().updateCenterDF(
                            center.id,
                            selectedProfileId,
                            profile['full_name'] ?? profile['email'],
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityIndicator(int count) {
    Color color = Colors.red;
    String text = 'Low Capacity (<3)';
    if (count >= 3 && count <= 10) {
      color = Colors.green;
      text = 'Ideal (3-10)';
    } else if (count > 10) {
      color = Colors.orange;
      text = 'Over Capacity (>10)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAssignLeaderDialog(BuildContext context, String centerId) {
    String? selectedVendorId;
    String selectedRole = 'Chairperson';
    final vendorProvider = context.read<VendorProvider>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Center Leader'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
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
                onChanged: (val) => setState(() => selectedRole = val!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedVendorId,
                hint: const Text('Select Vendor'),
                items: vendorProvider.vendors
                    .map(
                      (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedVendorId = val),
                decoration: const InputDecoration(labelText: 'Vendor'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedVendorId == null
                  ? null
                  : () async {
                      await context.read<CenterProvider>().assignLeadership(
                        centerId: centerId,
                        vendorId: selectedVendorId!,
                        role: selectedRole,
                      );
                      if (context.mounted) Navigator.pop(context);
                      setState(() {}); // Refresh parent
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCenterDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Center'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Center Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final ref =
                    'CTR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                await context.read<CenterProvider>().createCenter(
                  nameController.text,
                  ref,
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _LeadershipSection extends StatelessWidget {
  final String centerId;
  const _LeadershipSection({required this.centerId});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();

    return FutureBuilder<List<LeadershipModel>>(
      future: centerProvider.fetchLeadership(centerId: centerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final leaders = snapshot.data!;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _LeaderBadge(
              role: 'Chairperson',
              name: _findLeader(leaders, 'Chairperson'),
            ),
            _LeaderBadge(
              role: 'Secretary',
              name: _findLeader(leaders, 'Secretary'),
            ),
            _LeaderBadge(
              role: 'Treasurer',
              name: _findLeader(leaders, 'Treasurer'),
            ),
          ],
        );
      },
    );
  }

  String _findLeader(List<LeadershipModel> leaders, String role) {
    try {
      return leaders.firstWhere((l) => l.role == role).vendorName ??
          'Unassigned';
    } catch (_) {
      return 'Unassigned';
    }
  }
}

class _LeaderBadge extends StatelessWidget {
  final String role;
  final String name;
  const _LeaderBadge({required this.role, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          role,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: name == 'Unassigned'
                ? Colors.grey.withOpacity(0.1)
                : theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: name == 'Unassigned' ? Colors.grey : theme.primaryColor,
              width: 0.5,
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: name == 'Unassigned' ? Colors.grey : theme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
