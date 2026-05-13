import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../models/vendor.dart';

class MarketingVendorsView extends StatefulWidget {
  const MarketingVendorsView({super.key});

  @override
  State<MarketingVendorsView> createState() => _MarketingVendorsViewState();
}

class _MarketingVendorsViewState extends State<MarketingVendorsView> {
  String _searchQuery = '';
  String? _selectedGroup;
  String? _selectedCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendorProvider = context.watch<VendorProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final centerProvider = context.watch<CenterProvider>();

    final filteredVendors = vendorProvider.vendors.where((v) {
      final matchesSearch = v.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGroup = _selectedGroup == null || v.groupId == _selectedGroup;
      // Note: Vendor model might not have centerId directly, usually inferred from group
      return matchesSearch && matchesGroup;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendor Engagement',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Direct promotions and audience segmentation',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showBulkPromoDialog(context, filteredVendors),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Promo to Filtered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search vendors...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedGroup,
                    hint: const Text('All Groups', style: TextStyle(color: Colors.grey)),
                    dropdownColor: theme.cardColor,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Groups')),
                      ...groupProvider.groups.map((g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.name),
                          )),
                    ],
                    onChanged: (v) => setState(() => _selectedGroup = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              color: theme.cardColor.withOpacity(0.5),
              child: ListView.separated(
                itemCount: filteredVendors.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, index) {
                  final vendor = filteredVendors[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
                      child: const Icon(Icons.person, color: Color(0xFFD4AF37)),
                    ),
                    title: Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Ref: ${vendor.referenceNumber ?? "N/A"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _EngagementBadge(label: '95% Engagement', color: Colors.green),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.mail_outline, size: 20, color: Colors.grey),
                          onPressed: () => _sendDirectPromo(context, vendor, 'email'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_outlined, size: 20, color: Colors.grey),
                          onPressed: () => _sendDirectPromo(context, vendor, 'whatsapp'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkPromoDialog(BuildContext context, List<VendorModel> targets) {
    // Bulk promo implementation
  }

  void _sendDirectPromo(BuildContext context, VendorModel target, String type) {
    // Direct promo implementation
  }
}

class _EngagementBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _EngagementBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
