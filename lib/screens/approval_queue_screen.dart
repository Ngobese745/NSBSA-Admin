import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../services/access_control_service.dart';
import '../theme/app_theme.dart';

class ApprovalQueueScreen extends StatefulWidget {
  const ApprovalQueueScreen({super.key});

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _canApprove {
    final auth = context.read<AuthProvider>();
    return AccessControlService.canApproveRecords(auth.userProfile);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canApprove) {
      return Scaffold(
        appBar: AppBar(title: const Text('Approval Queue')),
        body: const Center(
          child: Text('You do not have permission to access this page.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Queue'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Vendors', icon: Icon(Icons.people)),
            Tab(text: 'Groups', icon: Icon(Icons.groups)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingVendorsTab(),
          _PendingGroupsTab(),
        ],
      ),
    );
  }
}

// ── Pending Vendors Tab ──

class _PendingVendorsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vendorProvider = context.watch<VendorProvider>();
    final pending = vendorProvider.vendors.where((v) => v.isPending).toList();

    if (pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No pending vendors.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vendorProvider.fetchVendors(forceRefresh: true),
      child: ListView.builder(
        itemCount: pending.length,
        itemBuilder: (context, index) {
          final vendor = pending[index];
          return _VendorApprovalCard(vendor: vendor);
        },
      ),
    );
  }
}

class _VendorApprovalCard extends StatelessWidget {
  final dynamic vendor;
  const _VendorApprovalCard({required this.vendor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
          child: const Icon(Icons.person, color: AppTheme.primaryGold),
        ),
        title: Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${vendor.idNumber ?? vendor.phone ?? 'N/A'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () => _approve(context, vendor),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Reject',
              onPressed: () => _reject(context, vendor),
            ),
          ],
        ),
      ),
    );
  }

  void _approve(BuildContext context, dynamic vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Vendor'),
        content: Text('Approve "${vendor.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<VendorProvider>().approveVendor(vendor.id);
    }
  }

  void _reject(BuildContext context, dynamic vendor) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Vendor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<VendorProvider>().approveVendor(
        vendor.id,
        rejectionReason: reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'No reason provided',
      );
    }
  }
}

// ── Pending Groups Tab ──

class _PendingGroupsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final pending = groupProvider.groups.where((g) => g.isPending).toList();

    if (pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No pending groups.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => groupProvider.fetchGroups(forceRefresh: true),
      child: ListView.builder(
        itemCount: pending.length,
        itemBuilder: (context, index) {
          final group = pending[index];
          return _GroupApprovalCard(group: group);
        },
      ),
    );
  }
}

class _GroupApprovalCard extends StatelessWidget {
  final dynamic group;
  const _GroupApprovalCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
          child: const Icon(Icons.groups, color: AppTheme.primaryGold),
        ),
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(group.referenceNumber),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Approve',
              onPressed: () => _approve(context, group),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              tooltip: 'Reject',
              onPressed: () => _reject(context, group),
            ),
          ],
        ),
      ),
    );
  }

  void _approve(BuildContext context, dynamic group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Group'),
        content: Text('Approve group "${group.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GroupProvider>().approveGroup(group.id);
    }
  }

  void _reject(BuildContext context, dynamic group) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GroupProvider>().approveGroup(
        group.id,
        rejectionReason: reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'No reason provided',
      );
    }
  }
}
