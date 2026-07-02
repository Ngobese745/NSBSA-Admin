import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/center_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/auth_provider.dart';
import '../services/access_control_service.dart';
import 'group_details_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

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
                'Groups',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddGroupDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Group'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Consumer<GroupProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.groups.isEmpty) {
                    return const Center(
                      child: Text(
                        'No groups found.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: provider.groups.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                    itemBuilder: (context, index) {
                      final group = provider.groups[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          group.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'Ref: ${group.referenceNumber} • Created: ${group.createdAt.toString().substring(0, 10)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (AccessControlService.canEditData(
                              context.read<AuthProvider>().userProfile,
                            ))
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                padding: EdgeInsets.zero,
                                onSelected: (val) {
                                  if (val == 'delete') {
                                    _showDeleteConfirmation(context, group);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 14,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(width: 4),
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
                                  GroupDetailsScreen(group: group),
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

  void _showAddGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    List<Map<String, TextEditingController>> memberControllers = [
      {
        'name': TextEditingController(),
        'phone': TextEditingController(),
        'id_number': TextEditingController(),
        'gender': TextEditingController(text: 'F'),
        'business': TextEditingController(),
        'whatsapp': TextEditingController(),
        'email': TextEditingController(),
        'address': TextEditingController(),
        'role': TextEditingController(text: 'Member'),
        'savings_amount': TextEditingController(text: '0'),
        'savings_frequency': TextEditingController(text: 'Monthly'),
      },
    ];

    String? selectedCenterId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final centers = context.read<CenterProvider>().centers;

            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Add New Group',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              content: SizedBox(
                width: 900,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: nameController,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Group Name',
                                labelStyle: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: selectedCenterId,
                              hint: const Text(
                                'Select Center',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              dropdownColor: Theme.of(context).cardColor,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Assigned Center',
                              ),
                              items: centers
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => selectedCenterId = val),
                              validator: (val) =>
                                  val == null ? 'Center is mandatory' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Members',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                memberControllers.add({
                                  'name': TextEditingController(),
                                  'phone': TextEditingController(),
                                  'id_number': TextEditingController(),
                                  'gender': TextEditingController(text: 'F'),
                                  'business': TextEditingController(),
                                  'whatsapp': TextEditingController(),
                                  'email': TextEditingController(),
                                  'address': TextEditingController(),
                                  'role': TextEditingController(text: 'Member'),
                                  'savings_amount': TextEditingController(
                                    text: '0',
                                  ),
                                  'savings_frequency': TextEditingController(
                                    text: 'Monthly',
                                  ),
                                });
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Member'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...memberControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        var controllers = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: controllers['name'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Name',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: controllers['id_number'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'ID Number',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 120,
                                    child: DropdownButtonFormField<String>(
                                      value: controllers['role']!.text,
                                      dropdownColor: Theme.of(
                                        context,
                                      ).cardColor,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                        fontSize: 12,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Role',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
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
                                      onChanged: (val) {
                                        if (val != null)
                                          controllers['role']!.text = val;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 80,
                                    child: DropdownButtonFormField<String>(
                                      value: controllers['gender']!.text,
                                      dropdownColor: Theme.of(
                                        context,
                                      ).cardColor,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Gender',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'M',
                                          child: Text('M'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'F',
                                          child: Text('F'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null)
                                          controllers['gender']!.text = val;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controllers['phone'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Phone',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        if (controllers['whatsapp']!
                                            .text
                                            .isEmpty) {
                                          controllers['whatsapp']!.text = val;
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: controllers['whatsapp'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'WhatsApp',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: controllers['email'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: controllers['business'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Business',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
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
                                    child: TextField(
                                      controller: controllers['address'],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Home Address',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: controllers['savings_amount'],
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Savings (R)',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 120,
                                    child: DropdownButtonFormField<String>(
                                      value: controllers['savings_frequency']!
                                          .text,
                                      dropdownColor: Theme.of(
                                        context,
                                      ).cardColor,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                        fontSize: 12,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Freq',
                                        labelStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
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
                                      onChanged: (val) {
                                        if (val != null)
                                          controllers['savings_frequency']!
                                                  .text =
                                              val;
                                      },
                                    ),
                                  ),
                                  if (memberControllers.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          memberControllers.removeAt(idx);
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
                    if (nameController.text.isNotEmpty &&
                        selectedCenterId != null) {
                      try {
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final provider = Provider.of<GroupProvider>(
                          context,
                          listen: false,
                        );
                        final ref =
                            'GRP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                        List<Map<String, dynamic>> members = [];
                        for (var controllers in memberControllers) {
                          if (controllers['name']!.text.isNotEmpty) {
                            members.add({
                              'name': controllers['name']!.text,
                              'phone': controllers['phone']!.text,
                              'id_number': controllers['id_number']!.text,
                              'gender': controllers['gender']!.text,
                              'business': controllers['business']!.text,
                              'whatsapp': controllers['whatsapp']!.text,
                              'email': controllers['email']!.text,
                              'address': controllers['address']!.text,
                              'role': controllers['role']!.text,
                              'savings_amount':
                                  double.tryParse(
                                    controllers['savings_amount']!.text,
                                  ) ??
                                  0.0,
                              'savings_frequency':
                                  controllers['savings_frequency']!.text,
                              'savings_start_date': DateTime.now()
                                  .toIso8601String(),
                            });
                          }
                        }

                        await provider.addGroupWithMembers(
                          nameController.text,
                          ref,
                          selectedCenterId!,
                          members,
                          creatorId: authProvider.userProfile?.id,
                          creatorName: authProvider.userProfile?.fullName,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding group: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else if (selectedCenterId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a Center.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete the group "${group.name}"? This will permanently remove the group record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final groupId = group.id;
              await context.read<GroupProvider>().deleteGroup(groupId);

              if (context.mounted) {
                // Refresh all providers to remove orphaned records (due to cascade delete)
                await Future.wait<void>([
                  context.read<LoanProvider>().fetchLoans(forceRefresh: true),
                  context.read<VendorProvider>().fetchVendors(
                    forceRefresh: true,
                  ),
                  context.read<PaymentProvider>().fetchPayments(
                    forceRefresh: true,
                  ),
                ]);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Group "${group.name}" and all associated data deleted',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
