import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class LeadsView extends StatefulWidget {
  const LeadsView({super.key});

  @override
  State<LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<LeadsView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketing = context.watch<MarketingProvider>();
    final gold = const Color(0xFFD4AF37);

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
                    'Leads & Conversions',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track potential vendors and measure conversion rates',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddLeadDialog(context),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add Lead'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Conversion Funnel Strip
          const _ConversionFunnelStrip(),
          const SizedBox(height: 24),
          if (marketing.leads.isEmpty)
            const Expanded(child: Center(child: Text('No leads tracked yet', style: TextStyle(color: Colors.grey))))
          else
            Expanded(
              child: Card(
                color: theme.cardColor.withOpacity(0.5),
                child: ListView.separated(
                  itemCount: marketing.leads.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final lead = marketing.leads[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        child: const Icon(Icons.person_outline, color: Colors.white70),
                      ),
                      title: Text(lead['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(lead['source'] ?? 'General Source'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusChip(status: lead['status'] ?? 'new'),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                            onPressed: () {},
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

  void _showAddLeadDialog(BuildContext context) {
    // Implementation
  }
}

class _ConversionFunnelStrip extends StatelessWidget {
  const _ConversionFunnelStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _FunnelItem(label: 'New Leads', value: '124', icon: Icons.person_add_outlined),
          _FunnelItem(label: 'Contacted', value: '86', icon: Icons.phone_callback_outlined),
          _FunnelItem(label: 'Interested', value: '42', icon: Icons.star_border),
          _FunnelItem(label: 'Converted', value: '18', icon: Icons.check_circle_outline, color: Colors.green),
        ],
      ),
    );
  }
}

class _FunnelItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _FunnelItem({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'converted':
        color = Colors.green;
        break;
      case 'interested':
        color = Colors.blue;
        break;
      case 'contacted':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
