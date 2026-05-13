import 'package:flutter/material.dart';

class MarketingAnalyticsView extends StatelessWidget {
  const MarketingAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = const Color(0xFFD4AF37);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Marketing Performance',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          // KPI Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.5,
            children: const [
              _KPICard(label: 'Total Reach', value: '42,850', icon: Icons.groups_outlined),
              _KPICard(label: 'Avg. Open Rate', value: '24.5%', icon: Icons.mark_email_read_outlined, color: Colors.green),
              _KPICard(label: 'Avg. Click Rate', value: '5.2%', icon: Icons.mouse_outlined, color: Colors.blue),
              _KPICard(label: 'Marketing ROI', value: '3.8x', icon: Icons.trending_up_outlined, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _ChartPlaceholder(title: 'Engagement Over Time', height: 300),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _ChartPlaceholder(title: 'Conversion by Source', height: 300),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _RecentActivityTable(),
        ],
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _KPICard({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color ?? Colors.grey, size: 20),
                const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String title;
  final double height;

  const _ChartPlaceholder({required this.title, required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor.withOpacity(0.5),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Center(
              child: Icon(Icons.insert_chart_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Performing Campaigns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 20),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: ['Campaign', 'Reach', 'Engagements', 'ROI'].map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(h, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
                ...List.generate(3, (i) => TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Winter Savings Promo', style: TextStyle(fontSize: 13))),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('12.5k')),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('3.2k')),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('4.5x', style: TextStyle(color: Colors.green))),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
