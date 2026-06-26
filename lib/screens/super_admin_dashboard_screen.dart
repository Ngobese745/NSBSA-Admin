import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../core/app_breakpoints.dart';
import '../providers/group_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/staff_performance_provider.dart';
import '../theme/app_theme.dart';
import '../services/system_audit_service.dart';
import '../models/system_audit_log_model.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  List<SystemAuditLogModel> _recentLogs = [];
  bool _isLoadingLogs = true;
  bool _analyticsCalculated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroups();
      context.read<LoanProvider>().fetchLoans();
      context.read<PaymentProvider>().fetchPayments();
      context.read<VendorProvider>().fetchVendors();
      _fetchLogs();
    });
  }

  Future<void> _fetchLogs() async {
    final logs = await SystemAuditService.fetchLogs(limit: 50);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _isLoadingLogs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.watch<GroupProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    final vendorProvider = context.watch<VendorProvider>();
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final staffProvider = context.watch<StaffPerformanceProvider>();

    if (!_analyticsCalculated &&
        !groupProvider.isLoading &&
        !loanProvider.isLoading &&
        !paymentProvider.isLoading &&
        !vendorProvider.isLoading) {
      _analyticsCalculated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        analyticsProvider.calculateAnalytics(
          groups: groupProvider.groups,
          vendors: vendorProvider.vendors,
          loans: loanProvider.loans,
          payments: paymentProvider.payments,
        );
        staffProvider.calculatePerformance(
          groups: groupProvider.groups,
          loans: loanProvider.loans,
          payments: paymentProvider.payments,
        );
      });
    }

    final totalGroups = groupProvider.groups.length;
    final totalDisbursed = loanProvider.loans.fold(
      0.0,
      (sum, loan) => sum + loan.amount,
    );

    final isDesktop = MediaQuery.of(context).size.width >= AppBreakpoints.wideContentMin;
    final isTablet = MediaQuery.of(context).size.width >= AppBreakpoints.contentTabletMin;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Admin Overview',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Top Financial Overview Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useExpanded = constraints.maxWidth > 800;
                    if (useExpanded) {
                      return Row(
                        children: [
                          Expanded(child: _buildStatCard(context, 'Groups', totalGroups.toString(), Icons.group_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(context, 'Interest Generated',
                              'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.interest).toStringAsFixed(0)}', Icons.trending_up_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(context, 'Admin Fees',
                              'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.adminFees).toStringAsFixed(0)}', Icons.admin_panel_settings_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard(context, 'Disbursed', 'R ${totalDisbursed.toStringAsFixed(0)}', Icons.account_balance_outlined)),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          SizedBox(width: 220, child: _buildStatCard(context, 'Groups', totalGroups.toString(), Icons.group_outlined)),
                          const SizedBox(width: 12),
                          SizedBox(width: 220, child: _buildStatCard(context, 'Interest Generated',
                              'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.interest).toStringAsFixed(0)}', Icons.trending_up_outlined)),
                          const SizedBox(width: 12),
                          SizedBox(width: 220, child: _buildStatCard(context, 'Admin Fees',
                              'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.adminFees).toStringAsFixed(0)}', Icons.admin_panel_settings_outlined)),
                          const SizedBox(width: 12),
                          SizedBox(width: 220, child: _buildStatCard(context, 'Disbursed', 'R ${totalDisbursed.toStringAsFixed(0)}', Icons.account_balance_outlined)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Charts Section
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildChartCard(theme, 'Expected vs Actual Collections', _buildCollectionsBarChart(analyticsProvider.monthlyTrend))),
                      const SizedBox(width: 24),
                      Expanded(child: _buildChartCard(theme, 'Loan Disbursement Trend', _buildDisbursementLineChart(analyticsProvider.monthlyTrend))),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildChartCard(theme, 'Expected vs Actual Collections', _buildCollectionsBarChart(analyticsProvider.monthlyTrend)),
                      _buildChartCard(theme, 'Loan Disbursement Trend', _buildDisbursementLineChart(analyticsProvider.monthlyTrend)),
                    ],
                  ),
                const SizedBox(height: 24),

                // Staff Performance Section
                Text(
                  'Staff Performance Oversight',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGold,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildStaffPerformanceTable(theme, staffProvider.staffPerformances)),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildRecentActivityFeed(theme)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildStaffPerformanceTable(theme, staffProvider.staffPerformances),
                      const SizedBox(height: 24),
                      _buildRecentActivityFeed(theme),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryGold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, String title, Widget chartWidget) {
    return Container(
      height: 350,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(child: chartWidget),
        ],
      ),
    );
  }

  Widget _buildCollectionsBarChart(List<MonthlyTrend> trend) {
    if (trend.isEmpty) return const Center(child: Text('No data'));
    final avgVariance = trend.fold(0.0, (sum, t) => sum + t.variancePercentage) / trend.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Expected', Colors.blueAccent),
            const SizedBox(width: 16),
            _buildLegendItem('Actual', Colors.greenAccent),
            const SizedBox(width: 16),
            Text(
              'Avg Variance: ${avgVariance.toStringAsFixed(1)}%',
              style: TextStyle(
                color: avgVariance >= 0 ? Colors.greenAccent : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: trend.fold(0.0, (max, t) => t.expectedCollections > max ? t.expectedCollections : max) * 1.2,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= trend.length) return const SizedBox.shrink();
                      return Text(trend[index].month, style: const TextStyle(fontSize: 10, color: Colors.grey));
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text('R${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 9)),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: trend.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY: e.value.expectedCollections, color: Colors.blueAccent, width: 8, borderRadius: BorderRadius.circular(2)),
                    BarChartRodData(toY: e.value.collected, color: Colors.greenAccent, width: 8, borderRadius: BorderRadius.circular(2)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisbursementLineChart(List<MonthlyTrend> trend) {
    if (trend.isEmpty) return const Center(child: Text('No data'));
    final maxDisbursed = trend.fold(0.0, (max, t) => t.disbursed > max ? t.disbursed : max);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxDisbursed > 0 ? maxDisbursed : 1000) * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= trend.length) return const SizedBox.shrink();
                return Text(trend[index].month, style: const TextStyle(fontSize: 10, color: Colors.grey));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text('R${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 9)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.disbursed)).toList(),
            isCurved: true,
            color: AppTheme.primaryGold,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [AppTheme.primaryGold.withOpacity(0.3), AppTheme.primaryGold.withOpacity(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildStaffPerformanceTable(ThemeData theme, List<StaffPerformance> staffMetrics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Staff Operational Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          if (staffMetrics.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No staff data available.'),
            ))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth > 800 ? constraints.maxWidth : 800,
                    ),
                    child: Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.5),
                        5: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
                          children: [
                            _th('Staff Member'), _th('Groups'), _th('Loans Handled'), _th('Disbursed (R)'), _th('Collection Rate'), _th('Total Arrears (R)'),
                          ],
                        ),
                        ...staffMetrics.map((staff) => TableRow(
                          children: [
                            _td(staff.staffName, bold: true),
                            _td(staff.groupsCreated.toString()),
                            _td(staff.loansDisbursedCount.toString()),
                            _td('R ${staff.loansDisbursedValue.toStringAsFixed(0)}'),
                            _buildCollectionRateCell(staff.collectionRate),
                            _td(
                              'R ${staff.totalArrears.toStringAsFixed(0)}',
                              color: staff.totalArrears > 0 ? Colors.redAccent : Colors.green,
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _th(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
    );
  }

  Widget _td(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w600 : FontWeight.normal, color: color)),
    );
  }

  Widget _buildCollectionRateCell(double rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(rate >= 90 ? Icons.check_circle : Icons.warning, color: rate >= 90 ? Colors.green : Colors.orange, size: 14),
          const SizedBox(width: 6),
          Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentActivityFeed(ThemeData theme) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent System Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingLogs 
              ? const Center(child: CircularProgressIndicator())
              : _recentLogs.isEmpty
                ? const Center(child: Text('No recent activity.', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _recentLogs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final log = _recentLogs[index];
                      final dateStr = DateFormat('MMM d, HH:mm').format(log.timestamp);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.history, color: AppTheme.primaryGold, size: 16),
                        ),
                        title: Text(log.actionType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(log.description, style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 2),
                            Text('${log.performedBy} • $dateStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
