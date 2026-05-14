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

    if (!groupProvider.isLoading &&
        !loanProvider.isLoading &&
        !paymentProvider.isLoading &&
        !vendorProvider.isLoading) {
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
                if (isTablet)
                  Row(
                    children: [
                      Expanded(
                        child: _buildPremiumStatCard(
                          context,
                          'Groups',
                          totalGroups.toString(),
                          Icons.group_outlined,
                          [const Color(0xFFD4AF37), const Color(0xFFB8860B)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumStatCard(
                          context,
                          'Interest Generated',
                          'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.interest).toStringAsFixed(0)}',
                          Icons.trending_up_outlined,
                          [const Color(0xFFC5A028), const Color(0xFF8B6B01)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumStatCard(
                          context,
                          'Admin Fees',
                          'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.adminFees).toStringAsFixed(0)}',
                          Icons.admin_panel_settings_outlined,
                          [const Color(0xFFE5B942), const Color(0xFF996515)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumStatCard(
                          context,
                          'Disbursed',
                          'R ${totalDisbursed.toStringAsFixed(0)}',
                          Icons.account_balance_outlined,
                          [const Color(0xFFFDC830), const Color(0xFFF37335)],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildPremiumStatCard(
                        context,
                        'Total Groups',
                        totalGroups.toString(),
                        Icons.group_outlined,
                        [const Color(0xFFD4AF37), const Color(0xFFB8860B)],
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumStatCard(
                        context,
                        'Interest Generated',
                        'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.interest).toStringAsFixed(0)}',
                        Icons.trending_up_outlined,
                        [const Color(0xFFC5A028), const Color(0xFF8B6B01)],
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumStatCard(
                        context,
                        'Admin Fees',
                        'R ${analyticsProvider.monthlyTrend.fold(0.0, (sum, t) => sum + t.adminFees).toStringAsFixed(0)}',
                        Icons.admin_panel_settings_outlined,
                        [const Color(0xFFE5B942), const Color(0xFF996515)],
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumStatCard(
                        context,
                        'Disbursed',
                        'R ${totalDisbursed.toStringAsFixed(0)}',
                        Icons.account_balance_outlined,
                        [const Color(0xFFF1C40F), const Color(0xFFF39C12)],
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Charts Section
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildChartCard(
                          theme,
                          'Expected vs Actual Collections',
                          _buildCollectionsBarChart(analyticsProvider.monthlyTrend),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildChartCard(
                          theme,
                          'Loan Disbursement Trend',
                          _buildDisbursementLineChart(analyticsProvider.monthlyTrend),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildChartCard(
                        theme,
                        'Expected vs Actual Collections',
                        _buildCollectionsBarChart(analyticsProvider.monthlyTrend),
                      ),
                      _buildChartCard(
                        theme,
                        'Loan Disbursement Trend',
                        _buildDisbursementLineChart(analyticsProvider.monthlyTrend),
                      ),
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
                      Expanded(
                        flex: 2,
                        child: _buildStaffPerformanceTable(theme, staffProvider.staffPerformances),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: _buildRecentActivityFeed(theme),
                      ),
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

  Widget _buildPremiumStatCard(BuildContext context, String title, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(icon, color: Colors.white.withOpacity(0.2), size: 48),
        ],
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, String title, Widget chartWidget) {
    return Container(
      height: 350,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff Operational Performance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (staffMetrics.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No staff data available.'),
            ))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                columns: const [
                  DataColumn(label: Text('Staff Member')),
                  DataColumn(label: Text('Groups')),
                  DataColumn(label: Text('Loans Handled')),
                  DataColumn(label: Text('Disbursed (R)')),
                  DataColumn(label: Text('Collection Rate')),
                  DataColumn(label: Text('Total Arrears (R)')),
                ],
                rows: staffMetrics.map((staff) {
                  return DataRow(
                    cells: [
                      DataCell(Text(staff.staffName, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(staff.groupsCreated.toString())),
                      DataCell(Text(staff.loansDisbursedCount.toString())),
                      DataCell(Text('R ${staff.loansDisbursedValue.toStringAsFixed(0)}')),
                      DataCell(
                        Row(
                          children: [
                            Icon(
                              staff.collectionRate >= 90 ? Icons.check_circle : Icons.warning,
                              color: staff.collectionRate >= 90 ? Colors.green : Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text('${staff.collectionRate.toStringAsFixed(1)}%'),
                          ],
                        )
                      ),
                      DataCell(
                        Text(
                          'R ${staff.totalArrears.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: staff.totalArrears > 0 ? Colors.redAccent : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityFeed(ThemeData theme) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent System Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingLogs 
              ? const Center(child: CircularProgressIndicator())
              : _recentLogs.isEmpty
                ? const Center(child: Text('No recent activity.', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _recentLogs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final log = _recentLogs[index];
                      final dateStr = DateFormat('MMM d, HH:mm').format(log.timestamp);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                          child: const Icon(Icons.history, color: AppTheme.primaryGold, size: 18),
                        ),
                        title: Text(
                          log.actionType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(log.description, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
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
