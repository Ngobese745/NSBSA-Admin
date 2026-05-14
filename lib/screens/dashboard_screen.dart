import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_breakpoints.dart';
import '../core/group_loan_risk.dart';
import '../providers/group_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/analytics_provider.dart';
import '../theme/app_theme.dart';
import 'loan_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroups();
      context.read<LoanProvider>().fetchLoans();
      context.read<PaymentProvider>().fetchPayments();
      context.read<VendorProvider>().fetchVendors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.watch<GroupProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    final vendorProvider = context.watch<VendorProvider>();
    final analyticsProvider = context.watch<AnalyticsProvider>();

    // Trigger calculation if data is ready
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
      });
    }

    final totalGroups = groupProvider.groups.length;
    final totalDisbursed = loanProvider.loans.fold(
      0.0,
      (sum, loan) => sum + loan.amount,
    );
    final totalCollected = paymentProvider.payments.fold(
      0.0,
      (sum, p) => sum + p.amountPaid,
    );
    final totalSavings = vendorProvider.vendors.fold(
      0.0,
      (sum, m) => sum + (m.savingsAmount ?? 0.0),
    );
    final groupRisks = computeGroupLoanRiskSummaries(
      groups: groupProvider.groups,
      loans: loanProvider.loans,
    );

    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.wideContentMin;
    final isTablet =
        MediaQuery.of(context).size.width >= AppBreakpoints.contentTabletMin;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Overview',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
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
                          'Disbursed',
                          'R ${totalDisbursed.toStringAsFixed(0)}',
                          Icons.account_balance_outlined,
                          [const Color(0xFFC5A028), const Color(0xFF8B6B01)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumStatCard(
                          context,
                          'Collected',
                          'R ${totalCollected.toStringAsFixed(0)}',
                          Icons.payments_outlined,
                          [const Color(0xFFE5B942), const Color(0xFF996515)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumStatCard(
                          context,
                          'Total Savings',
                          'R ${totalSavings.toStringAsFixed(0)}',
                          Icons.savings_outlined,
                          [const Color(0xFFF1C40F), const Color(0xFFF39C12)],
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
                        'Total Disbursed',
                        'R ${totalDisbursed.toStringAsFixed(0)}',
                        Icons.account_balance_outlined,
                        [const Color(0xFFC5A028), const Color(0xFF8B6B01)],
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumStatCard(
                        context,
                        'Total Collected',
                        'R ${totalCollected.toStringAsFixed(0)}',
                        Icons.payments_outlined,
                        [const Color(0xFFE5B942), const Color(0xFF996515)],
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumStatCard(
                        context,
                        'Total Savings',
                        'R ${totalSavings.toStringAsFixed(0)}',
                        Icons.savings_outlined,
                        [const Color(0xFFF1C40F), const Color(0xFFF39C12)],
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 2 : 1,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: isDesktop ? 1.8 : 1.4,
            ),
            delegate: SliverChildListDelegate([
              _buildChartCard(
                theme,
                'Collection Performance',
                _buildLineChart(analyticsProvider.monthlyTrend, totalDisbursed),
              ),
              _buildRecentActivityCard(theme, loanProvider),
              _buildRiskHeatmapCard(theme, groupRisks),
              _buildCreditProfileCard(theme, groupRisks),
            ]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildPremiumStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    List<Color> gradient,
  ) {
    final theme = Theme.of(context);
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -5,
            bottom: -5,
            child: Icon(icon, size: 40, color: Colors.black.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.black45),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, String title, Widget chart) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<MonthlyTrend> trend, double maxDisbursed) {
    const red = Color(0xFFE35D5B);
    const green = Color(0xFF38EF7D);
    const gold = Color(0xFFD4AF37);

    if (trend.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }

    final totalDisbursedYTD = trend.fold(0.0, (sum, t) => sum + t.disbursed);
    final totalCollectedYTD = trend.fold(0.0, (sum, t) => sum + t.collected);

    return Column(
      children: [
        // Summary Header
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChartSummary('Disbursed YTD', 'R ${totalDisbursedYTD.toStringAsFixed(0)}', red),
              _buildChartSummary('Collected YTD', 'R ${totalCollectedYTD.toStringAsFixed(0)}', green),
            ],
          ),
        ),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Disbursed Capital', red),
            const SizedBox(width: 24),
            _buildLegendItem('Payments Received', green),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white.withOpacity(0.03),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= trend.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          trend[index].month,
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxDisbursed > 0 ? maxDisbursed / 4 : 10000,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) => Text(
                      'R ${(value / 1000).toStringAsFixed(0)}k',
                      style: TextStyle(
                        color: Colors.grey.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => const Color(0xFF1A1A1A),
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        'R ${spot.y.toStringAsFixed(0)}',
                        TextStyle(
                          color: spot.bar.color ?? Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: trend.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.disbursed);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.3, // Lower smoothness to prevent dips
                  color: red,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: red,
                      strokeWidth: 1,
                      strokeColor: Colors.black,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        red.withOpacity(0.15),
                        red.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: trend.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.collected);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: green,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: green,
                      strokeWidth: 1,
                      strokeColor: Colors.black,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        green.withOpacity(0.15),
                        green.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartSummary(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard(ThemeData theme, LoanProvider loanProvider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Loan Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loanProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: loanProvider.loans.take(5).length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final loan = loanProvider.loans[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primaryGold.withOpacity(
                              0.1,
                            ),
                            child: const Icon(
                              Icons.add_card,
                              color: AppTheme.primaryGold,
                              size: 14,
                            ),
                          ),
                          title: Text(
                            'New Loan: R ${loan.amount}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loan.vendorName ?? 'Unknown Vendor',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryGold.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                loan.createdAt.toString().substring(0, 10),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.iconTheme.color?.withOpacity(0.5),
                            size: 16,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LoanDetailsScreen(loan: loan),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskHeatmapCard(
    ThemeData theme,
    List<GroupLoanRiskSummary> risks,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Risk Heatmap',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: risks.isEmpty
                  ? const Center(child: Text('No group data available'))
                  : ListView.separated(
                      itemCount: risks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final risk = risks[index];
                        // To make the bar slightly visible even at 0%, we can clamp it or just use the exact ratio
                        final ratio = risk.overdueRatio == 0.0
                            ? 0.02
                            : risk.overdueRatio;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    risk.groupName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(risk.overdueRatio * 100).toStringAsFixed(0)}% Overdue',
                                  style: TextStyle(
                                    color: risk.riskColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: risk.riskColor.withOpacity(
                                  0.15,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  risk.riskColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditProfileCard(
    ThemeData theme,
    List<GroupLoanRiskSummary> risks,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credit Profile Scores',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: risks.isEmpty
                  ? const Center(child: Text('No group data available'))
                  : ListView.separated(
                      itemCount: risks.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final risk = risks[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            risk.groupName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Trust Score: ${risk.trustScore}/100',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: CircleAvatar(
                            radius: 16,
                            backgroundColor: risk.riskColor.withOpacity(0.1),
                            child: Text(
                              risk.letterGrade,
                              style: TextStyle(
                                color: risk.riskColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
