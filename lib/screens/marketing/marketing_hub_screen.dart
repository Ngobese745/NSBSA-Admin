import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import 'marketing_vendors_view.dart';
import 'campaigns_view.dart';
import 'templates_view.dart';
import 'leads_view.dart';
import 'marketing_analytics_view.dart';
import 'marketing_reports_view.dart';

class MarketingHubScreen extends StatefulWidget {
  const MarketingHubScreen({super.key});

  @override
  State<MarketingHubScreen> createState() => _MarketingHubScreenState();
}

class _MarketingHubScreenState extends State<MarketingHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = context.read<MarketingProvider>();
      m.fetchCampaigns();
      m.fetchTemplates();
      m.fetchLeads();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = const Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: gold,
            labelColor: gold,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Vendors'),
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Campaigns'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
              Tab(icon: Icon(Icons.description_outlined), text: 'Templates'),
              Tab(icon: Icon(Icons.person_add_alt_1_outlined), text: 'Leads'),
              Tab(icon: Icon(Icons.assessment_outlined), text: 'Reports'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MarketingVendorsView(),
          CampaignsView(),
          MarketingAnalyticsView(),
          TemplatesView(),
          LeadsView(),
          MarketingReportsView(),
        ],
      ),
    );
  }
}
