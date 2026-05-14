import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_breakpoints.dart';
import 'dashboard_screen.dart';
import 'groups_screen.dart';
import 'vendors_screen.dart';
import 'loans_screen.dart';
import 'payments_screen.dart';
import 'import_screen.dart';
import 'reports_screen.dart';
import 'group_details_screen.dart';
import 'loan_details_screen.dart';
import 'user_management_screen.dart';
import '../providers/search_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/group_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import 'package:provider/provider.dart';
import 'vendor_profile_screen.dart';
import 'user_profile_screen.dart';
import 'analytics_screen.dart';
import 'developer_management_screen.dart';
import 'center_management_screen.dart';
import '../widgets/sync_status_indicator.dart';
import '../providers/developer_controls_provider.dart';
import '../services/access_control_service.dart';
import '../widgets/feature_disabled_placeholder.dart';
import '../widgets/system_status_banner_strip.dart';
import '../widgets/notification_bell.dart';
import 'marketing/marketing_hub_screen.dart';
import 'notification_history_screen.dart';
import '../providers/shell_navigation_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // We'll use ShellNavigationProvider for the actual index
  String? _dismissedStripBannerId;
  bool _isSidebarVisible = true;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _loadedIndices = {0}; // Dashboard is always loaded

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    14,
    (index) => GlobalKey<NavigatorState>(),
  );

  final List<String> _titles = [
    'Dashboard',
    'Group Management',
    'Vendors',
    'Loan Tracking',
    'Payments',
    'Advanced Analytics',
    'Financial Reports',
    'Import Data',
    'Marketing',
    'Center Management',
    'User Management',
    'Developer Management',
    'Account Preferences',
    'Notification History',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeveloperControlsProvider>().refresh();
    });
  }

  Widget _shellBodyForIndex(int index) {
    switch (index) {
      case 0:
        return const FeatureGuard(featureKey: 'dashboard', child: DashboardScreen());
      case 1:
        return const FeatureGuard(featureKey: 'groups', child: GroupsScreen());
      case 2:
        return const FeatureGuard(featureKey: 'vendors', child: VendorsScreen());
      case 3:
        return const FeatureGuard(featureKey: 'loans', child: LoansScreen());
      case 4:
        return const FeatureGuard(featureKey: 'payments', child: PaymentsScreen());
      case 5:
        return const FeatureGuard(featureKey: 'analytics', child: AnalyticsScreen());
      case 6:
        return const FeatureGuard(featureKey: 'reports', child: ReportsScreen());
      case 7:
        return const FeatureGuard(featureKey: 'import', child: ImportScreen());
      case 8:
        return const FeatureGuard(featureKey: 'marketing', child: MarketingHubScreen());
      case 9:
        return const CenterManagementScreen();
      case 10:
        return const FeatureGuard(featureKey: 'user_management', child: UserManagementScreen());
      case 11:
        return const DeveloperManagementScreen();
      case 12:
        return const UserProfileScreen();
      case 13:
        return const NotificationHistoryScreen();
      default:
        return const FeatureGuard(featureKey: 'dashboard', child: DashboardScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.shellDesktopMin;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Selector<ShellNavigationProvider, int>(
                selector: (_, p) => p.selectedIndex,
                builder: (_, index, __) => Text(_titles[index]),
              ),
            ),
      drawer: isDesktop ? null : _buildDrawer(theme),
      body: Column(
        children: [
          if (isDesktop)
            Container(
              height: 70, // Increased height for a more premium feel
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ), // More horizontal padding
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFF1E1E1E)
                    : theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: isLight ? Colors.white10 : theme.dividerColor,
                  ),
                ),
              ),
              child: CompositedTransformTarget(
                link: _layerLink,
                child: Row(
                  children: [
                    // Left section: Menu and Logo (Aligned to Sidebar width)
                    SizedBox(
                      width:
                          _isSidebarVisible ? 200 : 50, // Dynamic header section width
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: _isSidebarVisible
                                ? 'Collapse sidebar'
                                : 'Expand sidebar',
                            icon: Icon(
                              _isSidebarVisible ? Icons.menu_open : Icons.menu,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSidebarVisible = !_isSidebarVisible;
                              });
                            },
                          ),
                          if (_isSidebarVisible) ...[
                            const SizedBox(width: 8),
                            // Header Logo
                            Image.asset(
                              AppAssets.logo,
                              height: 58,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Divider (Now aligned with the start of the main content)
                    Container(
                      height: 32,
                      width: 1.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Selector<ShellNavigationProvider, int>(
                      selector: (_, p) => p.selectedIndex,
                      builder: (_, index, __) => Text(
                        _titles[index].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SyncStatusIndicator(),
                    IconButton(
                      tooltip: 'Refresh data & system banner',
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => _dismissedStripBannerId = null);
                        context.read<DeveloperControlsProvider>().refresh();
                        context.read<GroupProvider>().fetchGroups(
                          forceRefresh: true,
                        );
                        context.read<VendorProvider>().fetchVendors(
                          forceRefresh: true,
                        );
                        context.read<LoanProvider>().fetchLoans(
                          forceRefresh: true,
                        );
                        context.read<PaymentProvider>().fetchPayments(
                          forceRefresh: true,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Search Bar
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search groups, vendors or loans...',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: Colors.white54,
                          ),
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    context
                                        .read<SearchProvider>()
                                        .clearSearch();
                                    _hideOverlay();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) {
                          String contextType = 'global';
                          final selectedIndex = context.read<ShellNavigationProvider>().selectedIndex;
                          switch (selectedIndex) {
                            case 1:
                              contextType = 'groups';
                              break;
                            case 2:
                              contextType = 'vendors';
                              break;
                            case 3:
                              contextType = 'loans';
                              break;
                            case 4:
                              contextType = 'payments';
                              break;
                          }
                          context.read<SearchProvider>().search(
                            value,
                            contextType: contextType,
                          );
                          if (value.isNotEmpty) {
                            _showOverlay(context);
                          } else {
                            _hideOverlay();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    const NotificationBell(),
                    const SizedBox(width: 24),
                    // Profile Button
                    PopupMenuButton<String>(
                      offset: const Offset(0, 50),
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Builder(
                        builder: (context) {
                          final authProvider = context.watch<AuthProvider>();
                          final profile = authProvider.userProfile;
                          final displayName =
                              profile?.fullName ??
                              authProvider.currentUser?.email
                                  ?.split('@')
                                  .first ??
                              'User';
                          final role = authProvider.userRole;
                          return Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    role,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.primaryColor.withOpacity(
                                  0.2,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white54,
                                size: 18,
                              ),
                            ],
                          );
                        },
                      ),
                      onSelected: (value) {
                        if (value == 'logout') {
                          context.read<AuthProvider>().logout();
                        } else if (value == 'preferences') {
                          context.read<ShellNavigationProvider>().setSelectedIndex(12);
                        } else if (value == 'theme') {
                          context.read<ThemeProvider>().toggleTheme();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'preferences',
                          child: ListTile(
                            leading: Icon(
                              Icons.manage_accounts,
                              color: theme.iconTheme.color,
                            ),
                            title: Text(
                              'Account Preferences',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'theme',
                          child: ListTile(
                            leading: Icon(
                              Icons.palette,
                              color: theme.iconTheme.color,
                            ),
                            title: Text(
                              'Toggle Theme',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'logout',
                          child: ListTile(
                            leading: const Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                            ),
                            title: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Consumer<DeveloperControlsProvider>(
            builder: (context, dev, _) {
              final b = dev.primaryActiveBanner;
              if (b == null) return const SizedBox.shrink();
              if (_dismissedStripBannerId == b.id)
                return const SizedBox.shrink();
              return SystemStatusBannerStrip(
                banner: b,
                onDismiss: () => setState(() => _dismissedStripBannerId = b.id),
              );
            },
          ),
          Expanded(
            child: Row(
              children: [
                if (isDesktop) _buildSidebar(theme),
                Expanded(
                  child: Selector<ShellNavigationProvider, int>(
                    selector: (_, p) => p.selectedIndex,
                    builder: (context, selectedIndex, _) {
                      // Ensure current index is marked as loaded
                      if (!_loadedIndices.contains(selectedIndex)) {
                        _loadedIndices.add(selectedIndex);
                      }

                      return IndexedStack(
                        index: selectedIndex,
                        children: List.generate(_titles.length, (index) {
                          if (!_loadedIndices.contains(index)) {
                            return const SizedBox.shrink();
                          }

                          return Navigator(
                            key: _navigatorKeys[index],
                            onGenerateRoute: (settings) => MaterialPageRoute(
                              builder: (context) => _shellBodyForIndex(index),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(ThemeData theme) {
    return Drawer(child: _buildNavigationContent(theme));
  }

  Widget _buildSidebar(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarVisible ? 220 : 70,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? theme.primaryColor
            : theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: _buildNavigationContent(theme, isCollapsed: !_isSidebarVisible),
    );
  }

  Widget _buildNavigationContent(ThemeData theme, {bool isCollapsed = false}) {
    final isLight = theme.brightness == Brightness.light;
    final profile = context.select<AuthProvider, dynamic>((p) => p.userProfile);
    final navIndex = context.select<ShellNavigationProvider, int>((p) => p.selectedIndex);
    final dev = context.watch<DeveloperControlsProvider>();

    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildNavItem(
                Icons.dashboard,
                'Dashboard',
                0,
                navIndex,
                dev,
                featureKey: 'dashboard',
                isCollapsed: isCollapsed,
              ),
              if (!(profile?.isMarketing ?? false) || (profile?.isSuperAdmin ?? false)) ...[
                _buildNavItem(Icons.group, 'Groups', 1, navIndex, dev, featureKey: 'groups', isCollapsed: isCollapsed),
                _buildNavItem(Icons.person, 'Vendors', 2, navIndex, dev, featureKey: 'vendors', isCollapsed: isCollapsed),
              ],
              if (AccessControlService.canProcessPayments(profile) && (!(profile?.isMarketing ?? false) || (profile?.isSuperAdmin ?? false))) ...[
                _buildNavItem(
                  Icons.account_balance,
                  'Loans',
                  3,
                  navIndex,
                  dev,
                  featureKey: 'loans',
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  Icons.payment,
                  'Payments',
                  4,
                  navIndex,
                  dev,
                  featureKey: 'payments',
                  isCollapsed: isCollapsed,
                ),
              ],
              if (AccessControlService.canViewReports(profile) && (!(profile?.isMarketing ?? false) || (profile?.isSuperAdmin ?? false)))
                _buildNavItem(
                  Icons.insights,
                  'Analytics',
                  5,
                  navIndex,
                  dev,
                  featureKey: 'analytics',
                  isCollapsed: isCollapsed,
                ),
              if (AccessControlService.canViewReports(profile) && (!(profile?.isMarketing ?? false) || (profile?.isSuperAdmin ?? false)))
                _buildNavItem(
                  Icons.assessment,
                  'Reports',
                  6,
                  navIndex,
                  dev,
                  featureKey: 'reports',
                  isCollapsed: isCollapsed,
                ),
              if (!AccessControlService.isFieldAgent(profile) && (!(profile?.isMarketing ?? false) || (profile?.isSuperAdmin ?? false)))
                _buildNavItem(
                  Icons.upload_file,
                  'Import Data',
                  7,
                  navIndex,
                  dev,
                  featureKey: 'import',
                  isCollapsed: isCollapsed,
                ),

              if (profile?.isMarketing ?? false)
                _buildNavItem(
                  Icons.campaign,
                  'Marketing',
                  8,
                  navIndex,
                  dev,
                  featureKey: 'marketing',
                  isCollapsed: isCollapsed,
                ),

              if (!(profile?.isMarketing ?? false) || (profile?.isSuperAdmin ?? false))
                _buildNavItem(Icons.business, 'Centers', 9, navIndex, dev, isCollapsed: isCollapsed),

              if (AccessControlService.canManageUsers(profile)) ...[
                const Divider(
                  height: 24,
                  thickness: 0.3,
                  indent: 16,
                  endIndent: 16,
                ),
                _buildNavItem(
                  Icons.manage_accounts,
                  'User Management',
                  10,
                  navIndex,
                  dev,
                  featureKey: 'user_management',
                  isCollapsed: isCollapsed,
                ),
              ],
              if (AccessControlService.canAccessDeveloperTools(profile)) ...[
                const Divider(
                  height: 24,
                  thickness: 0.3,
                  indent: 16,
                  endIndent: 16,
                ),
                _buildNavItem(Icons.developer_mode, 'Developer Management', 11, navIndex, dev, isCollapsed: isCollapsed),
              ],
            ],
          ),
        ),
        if (!isCollapsed)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Version 1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isLight ? Colors.black54 : Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String title,
    int index,
    int selectedIndex,
    DeveloperControlsProvider dev, {
    String? featureKey,
    bool isCollapsed = false,
  }) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final featureOn = featureKey == null || dev.isFeatureEnabled(featureKey);

    // In Light mode, sidebar is gold, so we need strong black contrast.
    final activeColor = isLight ? Colors.black : theme.primaryColor;
    final inactiveColor = isLight ? Colors.black87 : Colors.grey;
    final baseColor = isSelected ? activeColor : inactiveColor;
    final color = featureOn ? baseColor : baseColor.withOpacity(0.35);

    return Opacity(
      opacity: featureOn ? 1 : 0.45,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: isCollapsed
            ? null
            : Icon(icon, size: 18, color: color),
        title: isCollapsed
            ? Center(child: Icon(icon, size: 20, color: color))
            : Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
        selected: isSelected,
        selectedTileColor: isLight
            ? Colors.white.withOpacity(0.3)
            : theme.primaryColor.withOpacity(0.08),
        onTap: () {
          if (!featureOn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title is currently disabled')),
            );
            return;
          }
          if (selectedIndex == index) {
            // Pop to root if already selected
            _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
          } else {
            context.read<ShellNavigationProvider>().setSelectedIndex(index);
          }
          // Close drawer on mobile if open
          if (MediaQuery.of(context).size.width < AppBreakpoints.shellDesktopMin) {
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.pop(context);
            }
          }
        },
      ),
    );
  }

  void _showOverlay(BuildContext context) {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50), // Position below the search bar
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.1)),
              ),
              child: Consumer<SearchProvider>(
                builder: (context, searchProvider, child) {
                  if (searchProvider.isSearching) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (searchProvider.groupResults.isEmpty &&
                      searchProvider.vendorResults.isEmpty &&
                      searchProvider.loanResults.isEmpty &&
                      searchProvider.paymentResults.isEmpty) {
                    String contextName = searchProvider.currentContext;
                    if (contextName == 'global') contextName = 'all sections';

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No results found in $contextName.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (searchProvider.groupResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Groups',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        ...searchProvider.groupResults.map(
                          (group) => ListTile(
                            title: Text(group.name),
                            subtitle: Text(group.referenceNumber),
                            leading: const Icon(
                              Icons.group,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              searchProvider.clearSearch();
                              context.read<ShellNavigationProvider>().setSelectedIndex(1); // Groups Tab
                              _navigatorKeys[1].currentState?.push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GroupDetailsScreen(group: group),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (searchProvider.vendorResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Vendors / Members',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        ...searchProvider.vendorResults.map(
                          (vendor) => ListTile(
                            title: Text(vendor.name),
                            subtitle: Text(
                              '${vendor.phone ?? ''} • ${vendor.businessType ?? ''}',
                            ),
                            leading: const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              searchProvider.clearSearch();
                              context.read<ShellNavigationProvider>().setSelectedIndex(2); // Vendors Tab
                              _navigatorKeys[2].currentState?.push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      VendorProfileScreen(vendor: vendor),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (searchProvider.loanResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Loans',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        ...searchProvider.loanResults.map(
                          (loan) => ListTile(
                            title: Text('Loan: R ${loan.amount}'),
                            subtitle: Text('Status: ${loan.status}'),
                            leading: const Icon(
                              Icons.account_balance,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              searchProvider.clearSearch();
                              context.read<ShellNavigationProvider>().setSelectedIndex(3); // Loans Tab
                              _navigatorKeys[3].currentState?.push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LoanDetailsScreen(loan: loan),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (searchProvider.paymentResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Payments',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        ...searchProvider.paymentResults.map(
                          (payment) => ListTile(
                            title: Text('Payment: R ${payment.amountPaid}'),
                            subtitle: Text(
                              'Method: ${payment.paymentMethod ?? 'Unknown'} • Date: ${payment.datePaid.toString().substring(0, 10)}',
                            ),
                            leading: const Icon(
                              Icons.payment,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              searchProvider.clearSearch();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Navigate to loan via Payments tab to view details.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class FeatureGuard extends StatelessWidget {
  final String featureKey;
  final Widget child;

  const FeatureGuard({
    super.key,
    required this.featureKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select<DeveloperControlsProvider, bool>(
      (dev) => dev.isFeatureEnabled(featureKey),
    );

    if (!isEnabled) {
      return FeatureDisabledPlaceholder(featureKey: featureKey);
    }

    return child;
  }
}
