import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../services/access_control_service.dart';
import '../services/account_management_service.dart';
import '../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<ProfileModel> _profiles = [];
  List<Map<String, dynamic>> _pendingResets = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  bool _isLoadingResets = false;
  bool _isLoadingAudit = false;
  bool _missingPasswordResetTableHintShown = false;
  bool _missingAccountAuditLogTableHintShown = false;
  late TabController _tabController;

  /// PostgREST PGRST205: table not in API schema (usually never migrated).
  static bool _isPgrst205MissingTable(Object e, String tableName) {
    final s = e.toString();
    return s.contains('PGRST205') && s.contains(tableName);
  }

  // Audit log filters
  String _auditFilterEvent = '';
  String _auditFilterEmail = '';

  static const List<String> _roles = [
    'Super Admin',
    'Admin',
    'Finance',
    'Marketing',
    'Development Facilitator',
    'Verifying Operator',
  ];

  static const Map<String, Map<String, dynamic>> _roleConfig = {
    'Super Admin': {
      'icon': Icons.security,
      'color': Color(0xFFD4AF37),
      'description': 'Full system access',
    },
    'Admin': {
      'icon': Icons.admin_panel_settings,
      'color': Color(0xFF4FC3F7),
      'description': 'High-level operational control',
    },
    'Finance': {
      'icon': Icons.account_balance_wallet,
      'color': Color(0xFF81C784),
      'description': 'Financial operations',
    },
    'Marketing': {
      'icon': Icons.campaign,
      'color': Color(0xFFBA68C8),
      'description': 'Communication & outreach',
    },
    'Development Facilitator': {
      'icon': Icons.person_search,
      'color': Color(0xFFFFB74D),
      'description': 'Portfolio-specific, view-only',
    },
    'Verifying Operator': {
      'icon': Icons.verified_user,
      'color': Color(0xFF4DB6AC),
      'description': 'Verification-focused',
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _pendingResets.isEmpty)
        _fetchPendingResets();
      if (_tabController.index == 2 && _auditLogs.isEmpty) _fetchAuditLog();
    });
    _fetchProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('created_at');
      setState(() {
        _profiles = (data as List)
            .map((e) => ProfileModel.fromJson(e))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPendingResets() async {
    setState(() => _isLoadingResets = true);
    try {
      final data = await AccountManagementService.fetchPendingResets();
      setState(() => _pendingResets = data);
    } catch (e) {
      if (!mounted) return;
      if (_isPgrst205MissingTable(e, 'password_reset_requests')) {
        setState(() => _pendingResets = []);
        if (!_missingPasswordResetTableHintShown) {
          _missingPasswordResetTableHintShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Create the password reset table: Supabase → SQL Editor → run '
                'supabase/migrations/20250512120000_password_reset_requests.sql '
                'from this project, then reload the app.',
              ),
              backgroundColor: Colors.deepOrange,
              duration: Duration(seconds: 12),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching reset requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingResets = false);
    }
  }

  Future<void> _fetchAuditLog() async {
    setState(() => _isLoadingAudit = true);
    try {
      final data = await AccountManagementService.fetchAuditLog(
        eventType: _auditFilterEvent.isEmpty ? null : _auditFilterEvent,
        targetEmail: _auditFilterEmail.isEmpty ? null : _auditFilterEmail,
      );
      setState(() => _auditLogs = data);
    } catch (e) {
      if (!mounted) return;
      if (_isPgrst205MissingTable(e, 'account_audit_log')) {
        setState(() => _auditLogs = []);
        if (!_missingAccountAuditLogTableHintShown) {
          _missingAccountAuditLogTableHintShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Create the audit log table: Supabase → SQL Editor → run '
                'supabase/migrations/20250512120001_account_audit_log.sql '
                'from this project, then reload the app.',
              ),
              backgroundColor: Colors.deepOrange,
              duration: Duration(seconds: 12),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching audit log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAudit = false);
    }
  }

  Future<void> _updateUserRole(ProfileModel profile, String newRole) async {
    try {
      await AccountManagementService.updateStaffProfile(
        userId: profile.id,
        fullName: profile.fullName ?? '',
        email: profile.email ?? '',
        department: profile.department ?? '',
        role: newRole,
        status: profile.status,
        operatorEmail:
            context.read<AuthProvider>().currentUser?.email ?? 'Unknown',
        canChangeCriticalFields: true,
      );
      await _fetchProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${profile.fullName ?? profile.email ?? 'User'} role updated to $newRole',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRoleDialog(ProfileModel profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.manage_accounts, color: AppTheme.primaryGold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Update Role for ${profile.fullName ?? profile.email ?? 'User'}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _roles.map((role) {
            final config = _roleConfig[role]!;
            final isSelected = profile.role == role;
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: (config['color'] as Color).withOpacity(0.15),
                child: Icon(
                  config['icon'] as IconData,
                  color: config['color'] as Color,
                  size: 16,
                ),
              ),
              title: Text(
                role,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? config['color'] as Color : null,
                ),
              ),
              subtitle: Text(
                config['description'] as String,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: config['color'] as Color,
                      size: 18,
                    )
                  : null,
              tileColor: isSelected
                  ? (config['color'] as Color).withOpacity(0.06)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                if (role != profile.role) _updateUserRole(profile, role);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final canManage = AccessControlService.canManageUsers(
      authProvider.userProfile,
    );
    final canAdminister = AccessControlService.canAdministerUsers(
      authProvider.userProfile,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (canAdminister)
            ElevatedButton.icon(
              onPressed: () => _showCreateStaffDialog(context),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Staff'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) _fetchProfiles();
              if (_tabController.index == 1) _fetchPendingResets();
              if (_tabController.index == 2) _fetchAuditLog();
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: Colors.grey,
          tabs: [
            const Tab(text: 'Staff Directory'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending Resets'),
                  if (_pendingResets.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_pendingResets.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Audit Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(theme, canManage, canAdminister, authProvider),
          _buildPendingResetsTab(theme, canAdminister, authProvider),
          _buildAuditLogTab(theme),
        ],
      ),
    );
  }

  Widget _buildUsersTab(
    ThemeData theme,
    bool canManage,
    bool canAdminister,
    AuthProvider authProvider,
  ) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Summary Cards
          Text(
            'Role Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildRoleSummaryGrid(theme),
          const SizedBox(height: 32),

          // Users Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Users',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_profiles.length} accounts',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: _profiles.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No user profiles found.\nUsers must log in once to create their profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: _profiles.asMap().entries.map((entry) {
                      final profile = entry.value;
                      final config =
                          _roleConfig[profile.role] ??
                          _roleConfig['Development Facilitator']!;
                      final isLast = entry.key == _profiles.length - 1;
                      final isCurrentUser =
                          profile.id == authProvider.currentUser?.id;
                      final isBlocked = profile.status == 'Blocked';

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: (config['color'] as Color)
                                  .withOpacity(0.12),
                              child: Icon(
                                config['icon'] as IconData,
                                color: config['color'] as Color,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  profile.fullName ??
                                      profile.email ??
                                      'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGold.withOpacity(
                                        0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryGold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              [
                                profile.email ?? 'No email',
                                if ((profile.department ?? '').isNotEmpty)
                                  profile.department!,
                              ].join(' • '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBlocked
                                        ? Colors.red.withOpacity(0.12)
                                        : Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isBlocked
                                          ? Colors.redAccent.withOpacity(0.4)
                                          : Colors.green.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    profile.status,
                                    style: TextStyle(
                                      color: isBlocked
                                          ? Colors.redAccent
                                          : Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (config['color'] as Color)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (config['color'] as Color)
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    profile.role,
                                    style: TextStyle(
                                      color: config['color'] as Color,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  color: canManage
                                      ? Colors.grey
                                      : Colors.grey.withOpacity(0.35),
                                  tooltip: canManage
                                      ? 'Edit user details'
                                      : 'Only Admins can edit user details.',
                                  onPressed: canManage
                                      ? () => _showEditUserDialog(
                                          profile,
                                          canAdminister,
                                        )
                                      : null,
                                ),
                                _restrictedIconButton(
                                  icon: Icons.admin_panel_settings,
                                  tooltip: 'Change role',
                                  enabled: canAdminister && !isCurrentUser,
                                  onPressed: () => _showRoleDialog(profile),
                                ),
                                _restrictedIconButton(
                                  icon: isBlocked
                                      ? Icons.lock_open
                                      : Icons.block,
                                  tooltip: isBlocked
                                      ? 'Unblock user'
                                      : 'Block user',
                                  enabled: canAdminister && !isCurrentUser,
                                  onPressed: () => isBlocked
                                      ? _unblockUser(profile, authProvider)
                                      : _confirmBlockUser(
                                          profile,
                                          authProvider,
                                        ),
                                ),
                                _restrictedIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Delete user',
                                  enabled: canAdminister && !isCurrentUser,
                                  color: Colors.redAccent,
                                  onPressed: () =>
                                      _confirmDeleteUser(profile, authProvider),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              color: theme.dividerColor.withOpacity(0.5),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),

          // Role Capability Reference
          Text(
            'Role Capabilities',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCapabilityTable(theme),
        ],
      ),
    );
  }

  Widget _restrictedIconButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: enabled ? tooltip : 'Only Super Admins can perform this action.',
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: enabled ? (color ?? Colors.grey) : Colors.grey.withOpacity(0.35),
        onPressed: enabled ? onPressed : null,
      ),
    );
  }

  void _showEditUserDialog(ProfileModel profile, bool canAdminister) {
    final nameCtrl = TextEditingController(text: profile.fullName ?? '');
    final emailCtrl = TextEditingController(text: profile.email ?? '');
    final departmentCtrl = TextEditingController(
      text: profile.department ?? '',
    );
    String selectedRole = profile.role;
    String selectedStatus = profile.status;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Edit User Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: departmentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: _roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: canAdminister
                      ? (v) => setDialogState(() => selectedRole = v!)
                      : null,
                ),
                if (!canAdminister)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Only Super Admins can change roles.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.verified_user),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Blocked', child: Text('Blocked')),
                  ],
                  onChanged: canAdminister
                      ? (v) => setDialogState(() => selectedStatus = v!)
                      : null,
                ),
                if (!canAdminister)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Only Super Admins can block or unblock accounts.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          !emailCtrl.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid name and email.',
                            ),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await AccountManagementService.updateStaffProfile(
                          userId: profile.id,
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          department: departmentCtrl.text.trim(),
                          role: selectedRole,
                          status: selectedStatus,
                          operatorEmail:
                              context.read<AuthProvider>().currentUser?.email ??
                              'Unknown',
                          canChangeCriticalFields: canAdminister,
                        );
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        await _fetchProfiles();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User details updated.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating user: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlockUser(
    ProfileModel profile,
    AuthProvider authProvider,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure you want to block this user?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.email ?? profile.fullName ?? 'Unknown user'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block User'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AccountManagementService.blockUser(
        userId: profile.id,
        targetEmail: profile.email ?? 'Unknown',
        operatorEmail: authProvider.currentUser?.email ?? 'Unknown',
        reason: reasonCtrl.text.trim().isEmpty
            ? 'No reason provided'
            : reasonCtrl.text.trim(),
      );
      await _fetchProfiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error blocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(
    ProfileModel profile,
    AuthProvider authProvider,
  ) async {
    try {
      await AccountManagementService.unblockUser(
        userId: profile.id,
        targetEmail: profile.email ?? 'Unknown',
        operatorEmail: authProvider.currentUser?.email ?? 'Unknown',
      );
      await _fetchProfiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unblocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser(
    ProfileModel profile,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user permanently?'),
        content: Text(
          'This will permanently delete ${profile.email ?? profile.fullName ?? 'this user'} and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AccountManagementService.deleteUserAccount(
        userId: profile.id,
        targetEmail: profile.email ?? 'Unknown',
        operatorEmail: authProvider.currentUser?.email ?? 'Unknown',
      );
      await _fetchProfiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRoleSummaryGrid(ThemeData theme) {
    final roleCounts = <String, int>{};
    for (final p in _profiles) {
      roleCounts[p.role] = (roleCounts[p.role] ?? 0) + 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 6
            : (constraints.maxWidth > 600 ? 3 : 2);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: _roles.map((role) {
            final config = _roleConfig[role]!;
            final count = roleCounts[role] ?? 0;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (config['color'] as Color).withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    config['icon'] as IconData,
                    color: config['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: config['color'] as Color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCapabilityTable(ThemeData theme) {
    final capabilities = [
      {
        'capability': 'Full system access',
        'Super Admin': true,
        'Admin': false,
        'Finance': false,
        'Marketing': false,
        'Development Facilitator': false,
        'Verifying Operator': false,
      },
      {
        'capability': 'User management',
        'Super Admin': true,
        'Admin': true,
        'Finance': false,
        'Marketing': false,
        'Development Facilitator': false,
        'Verifying Operator': false,
      },
      {
        'capability': 'Process payments',
        'Super Admin': true,
        'Admin': true,
        'Finance': true,
        'Marketing': false,
        'Development Facilitator': false,
        'Verifying Operator': false,
      },
      {
        'capability': 'Financial reports',
        'Super Admin': true,
        'Admin': true,
        'Finance': true,
        'Marketing': false,
        'Development Facilitator': false,
        'Verifying Operator': true,
      },
      {
        'capability': 'Audit logs',
        'Super Admin': true,
        'Admin': false,
        'Finance': false,
        'Marketing': false,
        'Development Facilitator': false,
        'Verifying Operator': false,
      },
      {
        'capability': 'Announcements',
        'Super Admin': true,
        'Admin': true,
        'Finance': false,
        'Marketing': true,
        'Development Facilitator': false,
        'Verifying Operator': false,
      },
      {
        'capability': 'Edit data',
        'Super Admin': true,
        'Admin': true,
        'Finance': true,
        'Marketing': false,
        'Development Facilitator': false,
        'Verifying Operator': true,
      },
      {
        'capability': 'View portfolio',
        'Super Admin': true,
        'Admin': true,
        'Finance': true,
        'Marketing': false,
        'Development Facilitator': true,
        'Verifying Operator': true,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 800.0;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minTableWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  theme.dividerColor.withOpacity(0.1),
                ),
                columns: [
                  const DataColumn(
                    label: Text(
                      'Capability',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ..._roles.map((role) {
                    final config = _roleConfig[role]!;
                    return DataColumn(
                      label: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            config['icon'] as IconData,
                            color: config['color'] as Color,
                            size: 14,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role.replaceAll(' ', '\n'),
                            style: TextStyle(
                              fontSize: 9,
                              color: config['color'] as Color,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                rows: capabilities.map((cap) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          cap['capability'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ..._roles.map((role) {
                        final hasAccess = cap[role] as bool;
                        return DataCell(
                          Center(
                            child: Icon(
                              hasAccess ? Icons.check_circle : Icons.remove,
                              color: hasAccess
                                  ? Colors.green
                                  : Colors.grey.withOpacity(0.3),
                              size: 16,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingResetsTab(
    ThemeData theme,
    bool canManage,
    AuthProvider authProvider,
  ) {
    if (_isLoadingResets)
      return const Center(child: CircularProgressIndicator());
    if (_pendingResets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pending password reset requests.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _pendingResets.length,
      itemBuilder: (context, index) {
        final req = _pendingResets[index];
        final email = req['user_email'];
        final date = DateTime.parse(
          req['created_at'],
        ).toLocal().toString().substring(0, 16);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              child: const Icon(Icons.lock_reset, color: Colors.orange),
            ),
            title: Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Requested on: $date',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: canManage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        label: const Text(
                          'Reject',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        onPressed: () async {
                          await AccountManagementService.rejectPasswordReset(
                            requestId: req['id'],
                            targetEmail: email,
                            operatorEmail:
                                authProvider.currentUser?.email ?? 'Unknown',
                          );
                          _fetchPendingResets();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.black),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          await AccountManagementService.approvePasswordReset(
                            requestId: req['id'],
                            targetEmail: email,
                            operatorEmail:
                                authProvider.currentUser?.email ?? 'Unknown',
                          );
                          _fetchPendingResets();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reset link sent to user.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  )
                : const Text(
                    'Requires Admin',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _auditFilterEvent.isEmpty ? null : _auditFilterEvent,
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Events')),
                    DropdownMenuItem(
                      value: 'account_created',
                      child: Text('Account Created'),
                    ),
                    DropdownMenuItem(
                      value: 'password_set',
                      child: Text('Password Set'),
                    ),
                    DropdownMenuItem(
                      value: 'reset_requested',
                      child: Text('Reset Requested'),
                    ),
                    DropdownMenuItem(
                      value: 'reset_approved',
                      child: Text('Reset Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'reset_rejected',
                      child: Text('Reset Rejected'),
                    ),
                    DropdownMenuItem(
                      value: 'user_updated',
                      child: Text('User Updated'),
                    ),
                    DropdownMenuItem(
                      value: 'user_blocked',
                      child: Text('User Blocked'),
                    ),
                    DropdownMenuItem(
                      value: 'user_unblocked',
                      child: Text('User Unblocked'),
                    ),
                    DropdownMenuItem(
                      value: 'user_deleted',
                      child: Text('User Deleted'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _auditFilterEvent = val ?? '');
                    _fetchAuditLog();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) {
                    _auditFilterEmail = val;
                    // Debounce in a real app, but direct for now
                    _fetchAuditLog();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingAudit
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
              ? const Center(
                  child: Text(
                    'No audit logs found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: _auditLogs.length,
                  itemBuilder: (context, index) {
                    final log = _auditLogs[index];
                    final date = DateTime.parse(
                      log['created_at'],
                    ).toLocal().toString().substring(0, 16);

                    IconData icon;
                    Color color;
                    switch (log['event_type']) {
                      case 'account_created':
                        icon = Icons.person_add;
                        color = Colors.blue;
                        break;
                      case 'password_set':
                        icon = Icons.lock;
                        color = Colors.green;
                        break;
                      case 'reset_requested':
                        icon = Icons.help_outline;
                        color = Colors.orange;
                        break;
                      case 'reset_approved':
                        icon = Icons.check_circle;
                        color = Colors.green;
                        break;
                      case 'reset_rejected':
                        icon = Icons.cancel;
                        color = Colors.red;
                        break;
                      case 'user_updated':
                        icon = Icons.manage_accounts;
                        color = Colors.blue;
                        break;
                      case 'user_blocked':
                        icon = Icons.block;
                        color = Colors.red;
                        break;
                      case 'user_unblocked':
                        icon = Icons.lock_open;
                        color = Colors.green;
                        break;
                      case 'user_deleted':
                        icon = Icons.delete;
                        color = Colors.redAccent;
                        break;
                      default:
                        icon = Icons.info;
                        color = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.2),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(
                          '${log['event_type'].toString().toUpperCase()} - ${log['target_email']}',
                        ),
                        subtitle: Text(
                          'By: ${log['operator_email'] ?? 'Self-Service'} • At: $date',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.code, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Audit Metadata'),
                                content: Text(
                                  log['metadata']?.toString() ?? 'No metadata',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateStaffDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'Development Facilitator';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Create Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (nameCtrl.text.isEmpty ||
                          emailCtrl.text.isEmpty ||
                          !emailCtrl.text.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields correctly.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await AccountManagementService.createStaffAccount(
                          email: emailCtrl.text.trim(),
                          fullName: nameCtrl.text.trim(),
                          role: selectedRole,
                          operatorEmail:
                              context.read<AuthProvider>().currentUser?.email ??
                              'Unknown',
                        );
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          _fetchProfiles();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account created successfully! User notified via email.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (!mounted) return;
                        final rateLimited =
                            AccountManagementService.isAuthEmailRateLimit(e);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              rateLimited
                                  ? AccountManagementService.staffInviteErrorMessage(
                                      e,
                                    )
                                  : 'Error: ${AccountManagementService.staffInviteErrorMessage(e)}',
                            ),
                            backgroundColor: rateLimited
                                ? Colors.deepOrange
                                : Colors.red,
                            duration: Duration(seconds: rateLimited ? 14 : 6),
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }
}
