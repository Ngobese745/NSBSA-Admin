import 'package:flutter/material.dart';

class MarketingReportsView extends StatelessWidget {
  const MarketingReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = const Color(0xFFD4AF37);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Marketing Reports',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 2.5,
              children: [
                _ReportTypeCard(
                  title: 'Campaign Performance Report',
                  description: 'Detailed metrics for all promotional campaigns sent.',
                  icon: Icons.analytics_outlined,
                  onDownload: () {},
                ),
                _ReportTypeCard(
                  title: 'Vendor Engagement Summary',
                  description: 'Track how vendors are interacting with your promotions.',
                  icon: Icons.people_outline,
                  onDownload: () {},
                ),
                _ReportTypeCard(
                  title: 'Lead Conversion Report',
                  description: 'Analysis of lead sources and conversion rates.',
                  icon: Icons.trending_up_outlined,
                  onDownload: () {},
                ),
                _ReportTypeCard(
                  title: 'Opt-out & Compliance Report',
                  description: 'List of unsubscribed users and compliance status.',
                  icon: Icons.gavel_outlined,
                  onDownload: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onDownload;

  const _ReportTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFD4AF37), size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.grey),
              onPressed: onDownload,
              tooltip: 'Download PDF',
            ),
          ],
        ),
      ),
    );
  }
}
