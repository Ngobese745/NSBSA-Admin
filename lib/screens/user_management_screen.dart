import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../services/access_control_service.dart';
import '../services/account_management_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nsbsa_loading_overlay.dart';

/// A small status badge for active/blocked.
class _StatusBadge extends StatelessWidget {
  final bool isBlocked;
  const _StatusBadge({required this.isBlocked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBlocked
            ? Colors.red.withOpacity(0.08)
            : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isBlocked
              ? Colors.red.withOpacity(0.15)
              : Colors.green.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        isBlocked ? 'Blocked' : 'Active',
        style: TextStyle(
          fontSize: 11,
          color: isBlocked ? Colors.red.shade400 : Colors.green.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Inline action buttons for a user row.
class _UserActions extends StatelessWidget {
  final bool canManage;
  final bool canAdminister;
  final bool isCurrentUser;
  final bool isBlocked;
  final VoidCallback onEdit;
  final VoidCallback onRole;
  final VoidCallback onToggleBlock;
  final VoidCallback onDelete;

  const _UserActions({
    required this.canManage,
    required this.canAdminister,
    required this.isCurrentUser,
    required this.isBlocked,
    required this.onEdit,
    required this.onRole,
    required this.onToggleBlock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit details',
          enabled: canManage,
          onPressed: onEdit,
        ),
        _ActionButton(
          icon: Icons.admin_panel_settings_outlined,
          tooltip: 'Change role',
          enabled: canAdminister && !isCurrentUser,
          onPressed: onRole,
        ),
        _ActionButton(
          icon: isBlocked ? Icons.lock_open : Icons.block,
          tooltip: isBlocked ? 'Unblock user' : 'Block user',
          enabled: canAdminister && !isCurrentUser,
          onPressed: onToggleBlock,
        ),
        _ActionButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete user',
          enabled: canAdminister && !isCurrentUser,
          color: Colors.redAccent,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color? color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = color ?? theme.textTheme.bodySmall?.color;
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        icon: Icon(icon, size: 16),
        tooltip: enabled
            ? tooltip
            : 'Only Super Admins can perform this action.',
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        color: enabled
            ? fgColor
            : (fgColor?.withOpacity(0.25)),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

/// A compact icon button for the header.
class _UserHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _UserHeaderAction({
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
    final operatorEmail =
        context.read<AuthProvider>().currentUser?.email ?? 'Unknown';
    if (!mounted) return;
    runWithLoading(context, task: () async {
      await AccountManagementService.updateStaffProfile(
        userId: profile.id,
        fullName: profile.fullName ?? '',
        email: profile.email ?? '',
        department: profile.department ?? '',
        role: newRole,
        status: profile.status,
        operatorEmail: operatorEmail,
        canChangeCriticalFields: true,
      );
      await _fetchProfiles();
    }, successMessage: '${profile.fullName ?? profile.email ?? 'User'} role updated to $newRole');
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
                  Icons.manage_accounts,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'User Management',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (canAdminister)
                  _UserHeaderAction(
                    icon: Icons.person_add,
                    tooltip: 'Add Staff',
                    onPressed: () => _showCreateStaffDialog(context),
                  ),
                const SizedBox(width: 4),
                _UserHeaderAction(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onPressed: () {
                    if (_tabController.index == 0) _fetchProfiles();
                    if (_tabController.index == 1) _fetchPendingResets();
                    if (_tabController.index == 2) _fetchAuditLog();
                  },
                ),
              ],
            ),
          ),
          // ─── Tab bar ───
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryGold,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppTheme.primaryGold,
              unselectedLabelColor:
                  theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: theme.textTheme.bodyMedium,
              dividerHeight: 0,
              tabs: [
                const Tab(text: 'Staff Directory'),
                Tab(
                  child: Row(
                    children: [
                      const Text('Pending Resets'),
                      if (_pendingResets.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(10),
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
          // ─── Tab content ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(theme, canManage, canAdminister, authProvider),
                _buildPendingResetsTab(theme, canAdminister, authProvider),
                _buildAuditLogTab(theme),
              ],
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Role Summary ───
          Text(
            'Role Overview',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildRoleSummaryGrid(theme),
          const SizedBox(height: 28),

          // ─── Users List ───
          Row(
            children: [
              Text(
                'System Users',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_profiles.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.12),
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _profiles.isEmpty
                ? _buildEmptyUsers(theme)
                : Column(
                    children: _profiles.asMap().entries.map((entry) {
                      final profile = entry.value;
                      final config = _roleConfig[profile.role] ??
                          _roleConfig['Development Facilitator']!;
                      final isLast = entry.key == _profiles.length - 1;
                      final isCurrentUser =
                          profile.id == authProvider.currentUser?.id;
                      final isBlocked = profile.status == 'Blocked';

                      return _buildUserRow(
                        theme, profile, config, isLast,
                        isCurrentUser, isBlocked,
                        canManage, canAdminister, authProvider,
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 28),

          // ─── Role Capability Reference ───
          Text(
            'Role Capabilities',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildCapabilityTable(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyUsers(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 36,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No users yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Users must log in once to create their profile.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(
    ThemeData theme,
    ProfileModel profile,
    Map<String, dynamic> config,
    bool isLast,
    bool isCurrentUser,
    bool isBlocked,
    bool canManage,
    bool canAdminister,
    AuthProvider authProvider,
  ) {
    final roleColor = config['color'] as Color;
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            // ─── Avatar ───
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                config['icon'] as IconData,
                color: roleColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // ─── Name + Email ───
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.fullName ?? 'Unknown',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.email ?? 'No email',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // ─── Role badge ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                profile.role,
                style: TextStyle(
                  fontSize: 11,
                  color: roleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ─── Status badge ───
            _StatusBadge(isBlocked: isBlocked),
            const SizedBox(width: 10),
            // ─── Actions ───
            _UserActions(
              canManage: canManage,
              canAdminister: canAdminister,
              isCurrentUser: isCurrentUser,
              isBlocked: isBlocked,
              onEdit: () => _showEditUserDialog(profile, canAdminister),
              onRole: () => _showRoleDialog(profile),
              onToggleBlock: () => isBlocked
                  ? _unblockUser(profile, authProvider)
                  : _confirmBlockUser(profile, authProvider),
              onDelete: () => _confirmDeleteUser(profile, authProvider),
            ),
          ],
        ),
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
          title: Text('Edit ${profile.fullName ?? 'User'}'),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
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
                    controller: departmentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: canAdminister
                        ? (v) => setDialogState(() => selectedRole = v!)
                        : null,
                  ),
                  if (!canAdminister)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Only Super Admins can change roles.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Only Super Admins can block or unblock accounts.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
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
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
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
                  final operatorEmail =
                      context.read<AuthProvider>().currentUser?.email ?? 'Unknown';
                  runWithLoadingAfterPop(
                    dialogCtx, task: () async {
                      await AccountManagementService.updateStaffProfile(
                        userId: profile.id,
                        fullName: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        department: departmentCtrl.text.trim(),
                        role: selectedRole,
                        status: selectedStatus,
                        operatorEmail: operatorEmail,
                        canChangeCriticalFields: canAdminister,
                      );
                      await _fetchProfiles();
                    },
                    successMessage: 'User details updated.',
                  );
                },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
        title: Text('Block ${profile.fullName ?? 'User'}'),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.email ?? 'Unknown user',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for blocking',
                  hintText: 'Required',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block User'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final operatorEmail = authProvider.currentUser?.email ?? 'Unknown';
    runWithLoading(context, task: () async {
      await AccountManagementService.blockUser(
        userId: profile.id,
        targetEmail: profile.email ?? 'Unknown',
        operatorEmail: operatorEmail,
        reason: reasonCtrl.text.trim().isEmpty
            ? 'No reason provided'
            : reasonCtrl.text.trim(),
      );
      await _fetchProfiles();
    }, successMessage: 'User blocked successfully.');
  }

  Future<void> _unblockUser(
    ProfileModel profile,
    AuthProvider authProvider,
  ) async {
    final operatorEmail = authProvider.currentUser?.email ?? 'Unknown';
    runWithLoading(context, task: () async {
      await AccountManagementService.unblockUser(
        userId: profile.id,
        targetEmail: profile.email ?? 'Unknown',
        operatorEmail: operatorEmail,
      );
      await _fetchProfiles();
    }, successMessage: 'User unblocked successfully.');
  }

  Future<void> _confirmDeleteUser(
    ProfileModel profile,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${profile.fullName ?? 'User'}?'),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(profile.email ?? 'Unknown user'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone. All data associated with this account will be permanently removed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final operatorEmail = authProvider.currentUser?.email ?? 'Unknown';
    runWithLoading(context, task: () async {
      await AccountManagementService.deleteUserAccount(
        userId: profile.id,
        targetEmail: profile.email ?? 'Unknown',
        operatorEmail: operatorEmail,
      );
      await _fetchProfiles();
    }, successMessage: 'User deleted successfully.');
  }

  Widget _buildRoleSummaryGrid(ThemeData theme) {
    final roleCounts = <String, int>{};
    for (final p in _profiles) {
      roleCounts[p.role] = (roleCounts[p.role] ?? 0) + 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _roles.map((role) {
          final config = _roleConfig[role]!;
          final count = roleCounts[role] ?? 0;
          final color = config['color'] as Color;
          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(config['icon'] as IconData, color: color, size: 16),
                    const Spacer(),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  role,
                  style: TextStyle(fontSize: 10, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.12),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            theme.scaffoldBackgroundColor,
          ),
          headingRowHeight: 40,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 34,
          horizontalMargin: 16,
          columnSpacing: 20,
          columns: [
            DataColumn(
              label: Text(
                'Capability',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ..._roles.map((role) {
              final config = _roleConfig[role]!;
              return DataColumn(
                label: Text(
                  role == 'Development Facilitator' ? 'Field Agent' : role,
                  style: TextStyle(
                    fontSize: 10,
                    color: config['color'] as Color,
                    fontWeight: FontWeight.w600,
                  ),
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
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                ..._roles.map((role) {
                  final hasAccess = cap[role] as bool;
                  return DataCell(
                    Center(
                      child: Icon(
                        hasAccess
                            ? Icons.check_circle
                            : Icons.horizontal_rule,
                        color: hasAccess
                            ? Colors.green
                            : theme.textTheme.bodySmall?.color?.withOpacity(0.2),
                        size: 14,
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
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
              size: 36,
              color: Colors.green.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No pending password reset requests.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: _pendingResets.length,
      itemBuilder: (context, index) {
        final req = _pendingResets[index];
        final email = req['user_email'];
        final date = DateTime.parse(
          req['created_at'],
        ).toLocal().toString().substring(0, 16);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.12),
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requested on $date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final reasonCtrl = TextEditingController();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Reject Reset Request'),
                              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              content: TextField(
                                controller: reasonCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Reason for rejection',
                                  hintText: 'e.g. Identity could not be verified',
                                ),
                                maxLines: 3,
                              ),
                              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                  ),
                                  child: const Text('Reject Request'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            final operatorEmail =
                                authProvider.currentUser?.email ?? 'Unknown';
                            runWithLoading(context, task: () async {
                              await AccountManagementService.rejectPasswordReset(
                                requestId: req['id'],
                                targetEmail: email,
                                operatorEmail: operatorEmail,
                                reason: reasonCtrl.text.trim().isEmpty
                                    ? null
                                    : reasonCtrl.text.trim(),
                              );
                              _fetchPendingResets();
                            }, successMessage: 'Password reset request rejected.');
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Approve Reset Request?'),
                              content: Text(
                                'A secure temporary password will be generated and sent to $email.',
                              ),
                              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Approve & Send'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final operatorEmail =
                                authProvider.currentUser?.email ?? 'Unknown';
                            runWithLoading(context, task: () async {
                              await AccountManagementService.approvePasswordReset(
                                requestId: req['id'],
                                targetEmail: email,
                                operatorEmail: operatorEmail,
                              );
                              _fetchPendingResets();
                            }, successMessage: 'Reset approved. Temporary credentials sent to user.');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Approve'),
                      ),
                    ],
                  )
                else
                  Text(
                    'Requires Admin',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogTab(ThemeData theme) {
    return Column(
      children: [
        // ─── Filters ───
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.12),
                width: 0.5,
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _auditFilterEvent.isEmpty ? null : _auditFilterEvent,
                    decoration: const InputDecoration(
                      hintText: 'Event Type',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    isExpanded: true,
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
                SizedBox(
                  width: 240,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by email',
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 16),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (val) {
                      _auditFilterEmail = val;
                      _fetchAuditLog();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ─── Log entries ───
        Expanded(
          child: _isLoadingAudit
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 36,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No audit logs found.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _auditLogs.length,
                  itemBuilder: (context, index) {
                    final log = _auditLogs[index];
                    final date = DateTime.parse(
                      log['created_at'],
                    ).toLocal().toString().substring(0, 16);

                    final (icon, color) = switch (log['event_type']) {
                      'account_created' => (Icons.person_add, Colors.blue),
                      'password_set' => (Icons.lock, Colors.green),
                      'reset_requested' => (Icons.help_outline, Colors.orange),
                      'reset_approved' => (Icons.check_circle, Colors.green),
                      'reset_rejected' => (Icons.cancel, Colors.red),
                      'user_updated' => (Icons.manage_accounts, Colors.blue),
                      'user_blocked' => (Icons.block, Colors.red),
                      'user_unblocked' => (Icons.lock_open, Colors.green),
                      'user_deleted' => (Icons.delete, Colors.redAccent),
                      _ => (Icons.info, Colors.grey),
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${log['event_type'].toString().replaceAll('_', ' ')} — ${log['target_email']}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'By ${log['operator_email'] ?? 'Self-Service'} • $date',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                icon: const Icon(Icons.code, size: 14),
                                tooltip: 'View metadata',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Audit Metadata'),
                                      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                                      content: Text(
                                        log['metadata']?.toString() ??
                                            'No metadata',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
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
          title: const Text('Add Staff Member'),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
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
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
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
                  final operatorEmail =
                      context.read<AuthProvider>().currentUser?.email ?? 'Unknown';
                  runWithLoadingAfterPop(
                    dialogCtx, task: () async {
                      await AccountManagementService.createStaffAccount(
                        email: emailCtrl.text.trim(),
                        fullName: nameCtrl.text.trim(),
                        role: selectedRole,
                        operatorEmail: operatorEmail,
                      );
                      _fetchProfiles();
                    },
                    successMessage: 'Account created successfully! User notified via email.',
                  );
                },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }
}
