import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_breakpoints.dart';
import '../core/app_assets.dart';
import '../core/pdf_branding.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/group_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/analytics_provider.dart';
import '../models/group.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'df_centre_reports_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchAndCalculate();
  }

  Future<void> _fetchAndCalculate() async {
    final groupProvider = context.read<GroupProvider>();
    final vendorProvider = context.read<VendorProvider>();
    final loanProvider = context.read<LoanProvider>();
    final paymentProvider = context.read<PaymentProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();

    await Future.wait([
      groupProvider.fetchGroups(),
      vendorProvider.fetchVendors(),
      loanProvider.fetchLoans(),
      paymentProvider.fetchPayments(),
    ]);

    analyticsProvider.calculateAnalytics(
      groups: groupProvider.groups,
      vendors: vendorProvider.vendors,
      loans: loanProvider.loans,
      payments: paymentProvider.payments,
    );

    if (mounted) {
      setState(() => _isDataLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final vendorProvider = context.watch<VendorProvider>();

    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.wideContentMin;
    final isTablet =
        MediaQuery.of(context).size.width >= AppBreakpoints.contentTabletMin;

    if (!_isDataLoaded || analyticsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: TabBar(
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Business Intelligence'),
                Tab(text: 'DF & Centre Reports'),
              ],
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: TabBarView(
            children: [
              // ── Tab 1: Business Intelligence ───────────────────────────
              SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(theme, analyticsProvider),
                    const SizedBox(height: 32),
                    // Top Section (Summary, Pie, Top Groups)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildSummaryCard(
                              'No of Members',
                              vendorProvider.vendors.length.toString(),
                              'Total Registered',
                              Icons.people_outline,
                              theme,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildFinancialMixPie(analyticsProvider, theme),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildTopGroupsChart(analyticsProvider, theme),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildSummaryCard(
                            'No of Members',
                            vendorProvider.vendors.length.toString(),
                            'Total Registered',
                            Icons.people_outline,
                            theme,
                            height: 220,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFinancialMixPie(
                                  analyticsProvider,
                                  theme,
                                  height: 250,
                                ),
                              ),
                              if (isTablet) ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTopGroupsChart(
                                    analyticsProvider,
                                    theme,
                                    height: 250,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!isTablet) ...[
                            const SizedBox(height: 16),
                            _buildTopGroupsChart(analyticsProvider, theme, height: 250),
                          ],
                        ],
                      ),
                    const SizedBox(height: 24),
                    // Bottom Section (Trend Chart, Risk Map)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildSmoothTrendChart(analyticsProvider, theme),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildRiskGrid(
                              analyticsProvider,
                              groupProvider.groups,
                              theme,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildSmoothTrendChart(analyticsProvider, theme),
                          const SizedBox(height: 16),
                          _buildRiskGrid(
                            analyticsProvider,
                            groupProvider.groups,
                            theme,
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // ── Tab 2: DF & Centre Reports ─────────────────────────────
              const DFCentreReportsScreen(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildHeader(ThemeData theme, AnalyticsProvider analyticsProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Intelligence',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: isMobile ? 24 : 32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time operational and financial health metrics',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _exportAnalyticsToPDF(analyticsProvider),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF Export'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    ThemeData theme, {
    double height = 180,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialMixPie(
    AnalyticsProvider provider,
    ThemeData theme, {
    double height = 220,
  }) {
    final totalExpected = provider.globalTotalExpected;
    final totalPaid = provider.globalTotalPaid;
    final totalOutstanding = totalExpected > totalPaid ? totalExpected - totalPaid : 0.0;
    
    double collectedPercentage = 0;
    double outstandingPercentage = 0;

    if (totalExpected > 0) {
      collectedPercentage = (totalPaid / totalExpected) * 100;
      outstandingPercentage = (totalOutstanding / totalExpected) * 100;
    } else {
      collectedPercentage = 100;
      outstandingPercentage = 0;
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portfolio Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const Spacer(),
                _buildPieLegend('Collected', theme.colorScheme.primary),
                const SizedBox(height: 8),
                _buildPieLegend(
                  'Outstanding',
                  theme.colorScheme.primary.withOpacity(0.2),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: collectedPercentage > 0 ? collectedPercentage : 1, // Prevent division by zero errors in chart
                    color: theme.colorScheme.primary,
                    radius: 25,
                    showTitle: true,
                    title: totalExpected > 0 ? '${collectedPercentage.toStringAsFixed(0)}%' : 'N/A',
                    titleStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                  if (totalExpected > 0)
                    PieChartSectionData(
                      value: outstandingPercentage,
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      radius: 25,
                      showTitle: true,
                      title: '${outstandingPercentage.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTopGroupsChart(
    AnalyticsProvider provider,
    ThemeData theme, {
    double height = 220,
  }) {
    final topGroups = provider.topGroups;
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Performing Groups',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: topGroups.length > 5 ? 5 : topGroups.length,
              itemBuilder: (context, index) {
                final group = topGroups[index];
                final maxValue = topGroups.first.collected;
                final percentage = maxValue > 0 ? group.collected / maxValue : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'R ${(group.collected / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percentage,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSmoothTrendChart(AnalyticsProvider provider, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Collection Velocity vs Profit',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              Text(
                'Last 6 months',
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10000,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
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
                        if (index >= 0 && index < provider.monthlyTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              provider.monthlyTrend[index].month,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10000,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Text(
                        '${(value / 1000).toInt()}k',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: provider.monthlyTrend
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.collected))
                        .toList(),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.2),
                          theme.colorScheme.primary.withOpacity(0.0),
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
      ),
    );
  }

  Widget _buildRiskGrid(
    AnalyticsProvider provider,
    List<GroupModel> groups,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Heat Map',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: groups.length > 9 ? 9 : groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final score = provider.groupRiskScores[group.id] ?? 100.0;
              Color riskColor = score > 85
                  ? Colors.green
                  : (score > 60 ? Colors.orange : Colors.red);
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportAnalyticsToPDF(AnalyticsProvider provider) async {
    final pdf = pw.Document();
    final groups = context.read<GroupProvider>().groups;

    final logo = await PdfBranding.loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(logo, height: 50),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Advanced Analytics Report',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}'),
              ],
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 20),
          pw.Text(
            'Key Performance Indicators',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text('Avg Repayment Rate'),
                  pw.Text(
                    '94.2%',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Default Ratio'),
                  pw.Text(
                    '2.8%',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text('Savings Growth'),
                  pw.Text(
                    '+12.4%',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Group Risk Assessment',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Group Name',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Risk Score',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Status',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...groups.map((group) {
                final score = provider.groupRiskScores[group.id] ?? 0.0;
                String status = score > 85
                    ? 'Stable'
                    : (score > 60 ? 'Warning' : 'Critical');
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(group.name),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${score.toStringAsFixed(1)}%'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(status),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'NSBSA_Analytics_Report',
    );
  }
}
