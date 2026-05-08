import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'groups_screen.dart';
import 'vendors_screen.dart';
import 'loans_screen.dart';
import 'payments_screen.dart';
import 'import_screen.dart';
import 'reports_screen.dart';
import 'group_details_screen.dart';
import 'loan_details_screen.dart';
import '../providers/search_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'vendor_profile_screen.dart';
import 'user_profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _isSidebarVisible = true;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final TextEditingController _searchController = TextEditingController();

  final List<Widget> _screens = [
    const DashboardScreen(),
    const GroupsScreen(),
    const VendorsScreen(),
    const LoansScreen(),
    const PaymentsScreen(),
    const ReportsScreen(),
    const ImportScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Group Management',
    'Vendors',
    'Loan Tracking',
    'Payments',
    'Financial Reports',
    'Import Data',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: Text(_titles[_selectedIndex])),
      drawer: isDesktop ? null : _buildDrawer(theme),
      body: Column(
        children: [
          if (isDesktop)
            Container(
              height: 70, // Increased height for a more premium feel
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20), // More horizontal padding
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
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
                    // Menu toggle
                    IconButton(
                      tooltip: _isSidebarVisible ? 'Hide sidebar' : 'Show sidebar',
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
                    const SizedBox(width: 12),
                    // Header Logo (INCREASED SIZE)
                    Image.asset(
                      'assets/images/NSBSA Logo (1).png',
                      height: 50, // Increased from 40 to 50
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 20),
                    // Divider and Title
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.white24,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _titles[_selectedIndex].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Search Bar
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search groups, vendors or loans...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    context.read<SearchProvider>().clearSearch();
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (value) {
                          String contextType = 'global';
                          switch (_selectedIndex) {
                            case 1: contextType = 'groups'; break;
                            case 2: contextType = 'vendors'; break;
                            case 3: contextType = 'loans'; break;
                            case 4: contextType = 'payments'; break;
                          }
                          context.read<SearchProvider>().search(value, contextType: contextType);
                          if (value.isNotEmpty) {
                            _showOverlay(context);
                          } else {
                            _hideOverlay();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Notifications (Visual Placeholder for professional look)
                    Stack(
                      children: [
                        const Icon(Icons.notifications_none, color: Colors.white70, size: 24),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                            child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // Profile Button
                    PopupMenuButton<String>(
                      offset: const Offset(0, 50),
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Administrator',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Colane',
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.primaryColor.withOpacity(0.2),
                            child: const Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                        ],
                      ),
                      onSelected: (value) {
                        if (value == 'logout') {
                          context.read<AuthProvider>().logout();
                        } else if (value == 'preferences') {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
                        } else if (value == 'theme') {
                          context.read<ThemeProvider>().toggleTheme();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'preferences',
                          child: ListTile(
                            leading: Icon(Icons.manage_accounts, color: theme.iconTheme.color),
                            title: Text('Account Preferences', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'theme',
                          child: ListTile(
                            leading: Icon(Icons.palette, color: theme.iconTheme.color),
                            title: Text('Toggle Theme', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'logout',
                          child: ListTile(
                            leading: const Icon(Icons.logout, color: Colors.redAccent),
                            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
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
          Expanded(
            child: Row(
              children: [
                if (isDesktop && _isSidebarVisible) _buildSidebar(theme),
                Expanded(child: _screens[_selectedIndex]),
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
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? theme.primaryColor : theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: _buildNavigationContent(theme),
    );
  }

  Widget _buildNavigationContent(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildNavItem(Icons.dashboard, 'Dashboard', 0),
              _buildNavItem(Icons.group, 'Groups', 1),
              _buildNavItem(Icons.person, 'Vendors', 2),
              _buildNavItem(Icons.account_balance, 'Loans', 3),
              _buildNavItem(Icons.payment, 'Payments', 4),
              _buildNavItem(Icons.assessment, 'Reports', 5),
              _buildNavItem(Icons.upload_file, 'Import Data', 6),
            ],
          ),
        ),
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

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // In Light mode, sidebar is gold, so we need strong black contrast.
    final activeColor = isLight ? Colors.black : theme.primaryColor;
    final inactiveColor = isLight ? Colors.black87 : Colors.grey;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        icon,
        size: 18,
        color: isSelected ? activeColor : inactiveColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: isSelected ? activeColor : inactiveColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedTileColor: isLight ? Colors.white.withOpacity(0.3) : theme.primaryColor.withOpacity(0.08),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        if (MediaQuery.of(context).size.width < 800) {
          Navigator.pop(context); // Close drawer
        }
      },
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
                              Navigator.push(
                                context,
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
                              Navigator.push(
                                context,
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
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                        ...searchProvider.loanResults.map(
                          (loan) => ListTile(
                            title: Text('Loan: R ${loan.amount}'),
                            subtitle: Text('Status: ${loan.status}'),
                            leading: const Icon(Icons.account_balance, color: Colors.grey),
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              searchProvider.clearSearch();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoanDetailsScreen(loan: loan),
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
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                        ...searchProvider.paymentResults.map(
                          (payment) => ListTile(
                            title: Text('Payment: R ${payment.amountPaid}'),
                            subtitle: Text('Method: ${payment.paymentMethod ?? 'Unknown'} • Date: ${payment.datePaid.toString().substring(0, 10)}'),
                            leading: const Icon(Icons.payment, color: Colors.grey),
                            onTap: () {
                              _hideOverlay();
                              _searchController.clear();
                              searchProvider.clearSearch();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Navigate to loan via Payments tab to view details.')),
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
