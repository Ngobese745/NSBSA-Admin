import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../core/app_breakpoints.dart';
import '../services/excel_export_service.dart';

class DFCentreReportsScreen extends StatefulWidget {
  const DFCentreReportsScreen({super.key});

  @override
  State<DFCentreReportsScreen> createState() => _DFCentreReportsScreenState();
}

class _DFCentreReportsScreenState extends State<DFCentreReportsScreen> {
  DateTimeRange? _selectedDateRange;
  String? _selectedDF;
  String? _selectedCentre;
  String? _selectedLoanType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final centerProvider = context.watch<CenterProvider>();
    final isTablet = MediaQuery.of(context).size.width >= AppBreakpoints.contentTabletMin;
    final loanProvider = context.watch<LoanProvider>();
    final loanTypes = loanProvider.loans.map((l) => l.loanType ?? 'Standard').toSet().toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(theme, analyticsProvider, centerProvider, loanTypes),
          const SizedBox(height: 32),
          _buildSummaryCards(theme, analyticsProvider),
          const SizedBox(height: 32),
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDFPerformanceChart(theme, analyticsProvider)),
                const SizedBox(width: 24),
                Expanded(child: _buildCentreLoanChart(theme, analyticsProvider, centerProvider)),
              ],
            )
          else
            Column(
              children: [
                _buildDFPerformanceChart(theme, analyticsProvider),
                const SizedBox(height: 24),
                _buildCentreLoanChart(theme, analyticsProvider, centerProvider),
              ],
            ),
          const SizedBox(height: 32),
          _buildCollectionTrend(theme, analyticsProvider),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, AnalyticsProvider analytics, CenterProvider centers, List<String> loanTypes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildFilterDropdown(
            'DF Facilitator',
            _selectedDF,
            analytics.dfMonthlyDisbursed.keys.toList(),
            (val) => setState(() => _selectedDF = val),
          ),
          _buildFilterDropdown(
            'Centre',
            _selectedCentre,
            centers.centers.map((c) => c.name).toList(),
            (val) => setState(() => _selectedCentre = val),
          ),
          _buildFilterDropdown(
            'Loan Type',
            _selectedLoanType,
            loanTypes,
            (val) => setState(() => _selectedLoanType = val),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDateRange = picked);
            },
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(
              _selectedDateRange == null
                  ? 'Date Range'
                  : '${_selectedDateRange!.start.toString().substring(0, 10)} - ${_selectedDateRange!.end.toString().substring(0, 10)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (_selectedDF != null || _selectedCentre != null || _selectedLoanType != null || _selectedDateRange != null)
            TextButton(
              onPressed: () => setState(() {
                _selectedDF = null;
                _selectedCentre = null;
                _selectedLoanType = null;
                _selectedDateRange = null;
              }),
              child: const Text('Reset', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.download_for_offline, color: AppTheme.primaryGold),
            onPressed: () => _exportToExcel(analytics),
            tooltip: 'Export to Excel',
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(AnalyticsProvider analytics) async {
    final List<List<String>> data = [
      ['DF Performance Report'],
      ['Generated on: ${DateTime.now().toString().substring(0, 16)}'],
      [],
      ['DF Name', 'Total Disbursed', 'Collection Rate', 'Active Loans'],
    ];

    for (var df in analytics.dfMonthlyDisbursed.keys) {
      final performance = analytics.dfPerformance[df] ?? {};
      data.add([
        df,
        'R ${analytics.dfMonthlyDisbursed[df]?.values.fold(0.0, (a, b) => (a ?? 0) + (b ?? 0))?.toStringAsFixed(0) ?? '0'}',
        '${(performance['collectionRate'] ?? 0.0).toStringAsFixed(1)}%',
        (performance['activeLoans'] ?? 0).toString(),
      ]);
    }

    await ExcelExportService.exportTableReport(
      title: 'DF_Performance_Report',
      data: data,
    );
  }

  Widget _buildFilterDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, AnalyticsProvider analytics) {
    // Top Performing DF
    String topDF = 'N/A';
    double maxPerformance = -1;
    analytics.dfCollectionPerformance.forEach((name, rate) {
      if (rate > maxPerformance) {
        maxPerformance = rate;
        topDF = name;
      }
    });

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            'Top Performing DF',
            topDF,
            '${maxPerformance.toStringAsFixed(1)}% Collection',
            Icons.star_outline,
            AppTheme.primaryGold,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildStatCard(
            theme,
            'Active DFs',
            analytics.dfMonthlyDisbursed.length.toString(),
            'Across all centres',
            Icons.badge_outlined,
            Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, String value, String subtitle, IconData icon, Color color) {
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
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDFPerformanceChart(ThemeData theme, AnalyticsProvider analytics) {
    final dfData = analytics.dfCollectionPerformance;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DF Collection Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          ...dfData.entries.take(5).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12)),
                    Text('${e.value.toStringAsFixed(1)}%', style: TextStyle(color: _getPerformanceColor(e.value), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: e.value / 100,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation(_getPerformanceColor(e.value)),
                  minHeight: 6,
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _getPerformanceColor(double rate) {
    if (rate >= 95) return Colors.greenAccent;
    if (rate >= 80) return AppTheme.primaryGold;
    return Colors.redAccent;
  }

  Widget _buildCentreLoanChart(ThemeData theme, AnalyticsProvider analytics, CenterProvider centers) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Loans Disbursed per Centre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: analytics.centerTotalLoans.entries.map((e) {
                  final center = centers.centers.firstWhere((c) => c.id == e.key, orElse: () => centers.centers.first);
                  return PieChartSectionData(
                    value: e.value,
                    title: center.name,
                    color: Colors.primaries[analytics.centerTotalLoans.keys.toList().indexOf(e.key) % Colors.primaries.length],
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionTrend(ThemeData theme, AnalyticsProvider analytics) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DF Monthly Disbursement Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        if (value >= 0 && value < 12) return Text(months[value.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey));
                        return const Text('');
                      },
                    ),
                  ),
                ),
                lineBarsData: analytics.dfMonthlyDisbursed.entries.map((e) {
                  final monthMap = e.value;
                  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  return LineChartBarData(
                    spots: List.generate(12, (i) => FlSpot(i.toDouble(), monthMap[months[i]] ?? 0)),
                    isCurved: true,
                    color: Colors.primaries[analytics.dfMonthlyDisbursed.keys.toList().indexOf(e.key) % Colors.primaries.length],
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
