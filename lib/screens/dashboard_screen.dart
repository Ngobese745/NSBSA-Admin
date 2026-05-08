import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/group_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';
import '../screens/loan_details_screen.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.watch<GroupProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final paymentProvider = context.watch<PaymentProvider>();

    final totalGroups = groupProvider.groups.length;
    final totalDisbursed = loanProvider.loans.fold(0.0, (sum, loan) => sum + loan.amount);
    final totalCollected = paymentProvider.payments.fold(0.0, (sum, p) => sum + p.amountPaid);
    final overdueCount = loanProvider.loans.where((loan) => loan.status == 'Overdue').length;
    final groupRisks = _calculateGroupRisks(groupProvider, loanProvider);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Overview',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildPremiumStatCard(context, 'Total Groups', totalGroups.toString(), Icons.group_outlined, [const Color(0xFFD4AF37), const Color(0xFFB8860B)])),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPremiumStatCard(context, 'Total Disbursed', 'R ${totalDisbursed.toStringAsFixed(0)}', Icons.account_balance_outlined, [const Color(0xFFC5A028), const Color(0xFF8B6B01)])),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPremiumStatCard(context, 'Total Collected', 'R ${totalCollected.toStringAsFixed(0)}', Icons.payments_outlined, [const Color(0xFFE5B942), const Color(0xFF996515)])),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.8,
            ),
            delegate: SliverChildListDelegate([
              _buildChartCard(theme, 'Collection Performance', _buildLineChart(totalDisbursed, totalCollected)),
              _buildRecentActivityCard(theme, loanProvider),
              _buildRiskHeatmapCard(theme, groupRisks),
              _buildCreditProfileCard(theme, groupRisks),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatCard(BuildContext context, String title, String value, IconData icon, List<Color> gradient) {
    final theme = Theme.of(context);
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: gradient[0].withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 60, color: Colors.black.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
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
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(double disbursed, double collected) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 0),
              FlSpot(1, disbursed * 0.4),
              FlSpot(2, disbursed * 0.7),
              FlSpot(3, disbursed),
            ],
            isCurved: true,
            color: const Color(0xFFE35D5B),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFFE35D5B).withOpacity(0.1)),
          ),
          LineChartBarData(
            spots: [
              const FlSpot(0, 0),
              FlSpot(1, collected * 0.3),
              FlSpot(2, collected * 0.6),
              FlSpot(3, collected),
            ],
            isCurved: true,
            color: const Color(0xFF38EF7D),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF38EF7D).withOpacity(0.1)),
          ),
        ],
      ),
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
            Text('Recent Loan Activity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: loanProvider.isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: loanProvider.loans.take(5).length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                    itemBuilder: (context, index) {
                      final loan = loanProvider.loans[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppTheme.primaryGold.withOpacity(0.1),
                          child: const Icon(Icons.add_card, color: AppTheme.primaryGold, size: 14),
                        ),
                        title: Text('New Loan: R ${loan.amount}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(loan.createdAt.toString().substring(0, 10), style: theme.textTheme.bodySmall),
                        trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color?.withOpacity(0.5), size: 16),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LoanDetailsScreen(loan: loan))),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  List<_GroupRiskData> _calculateGroupRisks(GroupProvider gp, LoanProvider lp) {
    List<_GroupRiskData> risks = [];
    for (var group in gp.groups) {
      final groupLoans = lp.loans.where((l) => l.groupId == group.id).toList();
      if (groupLoans.isEmpty) {
        risks.add(_GroupRiskData(group.name, 0.0, 100));
        continue;
      }

      int overdueCount = 0;
      double totalPoints = 0;

      for (var loan in groupLoans) {
        if (loan.status.toLowerCase() == 'overdue') {
          overdueCount++;
          totalPoints += 20;
        } else if (loan.status.toLowerCase() == 'paid') {
          totalPoints += 100;
        } else {
          totalPoints += 80;
        }
      }

      double ratio = overdueCount / groupLoans.length;
      int score = (totalPoints / groupLoans.length).round();
      risks.add(_GroupRiskData(group.name, ratio, score));
    }
    
    risks.sort((a, b) => b.trustScore.compareTo(a.trustScore));
    return risks;
  }

  Widget _buildRiskHeatmapCard(ThemeData theme, List<_GroupRiskData> risks) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan Risk Heatmap', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: risks.isEmpty 
                ? const Center(child: Text('No group data available'))
                : ListView.separated(
                    itemCount: risks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final risk = risks[index];
                      // To make the bar slightly visible even at 0%, we can clamp it or just use the exact ratio
                      final ratio = risk.overdueRatio == 0.0 ? 0.02 : risk.overdueRatio;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  risk.groupName, 
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(risk.overdueRatio * 100).toStringAsFixed(0)}% Overdue',
                                style: TextStyle(color: risk.riskColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: risk.riskColor.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(risk.riskColor),
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

  Widget _buildCreditProfileCard(ThemeData theme, List<_GroupRiskData> risks) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credit Profile Scores', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: risks.isEmpty 
                ? const Center(child: Text('No group data available'))
                : ListView.separated(
                    itemCount: risks.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                    itemBuilder: (context, index) {
                      final risk = risks[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(risk.groupName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text('Trust Score: ${risk.trustScore}/100', style: theme.textTheme.bodySmall),
                        trailing: CircleAvatar(
                          radius: 16,
                          backgroundColor: risk.riskColor.withOpacity(0.1),
                          child: Text(
                            risk.letterGrade,
                            style: TextStyle(color: risk.riskColor, fontWeight: FontWeight.bold, fontSize: 14),
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

class _GroupRiskData {
  final String groupName;
  final double overdueRatio;
  final int trustScore;

  _GroupRiskData(this.groupName, this.overdueRatio, this.trustScore);

  String get letterGrade {
    if (trustScore >= 90) return 'A';
    if (trustScore >= 75) return 'B';
    if (trustScore >= 60) return 'C';
    return 'D';
  }

  Color get riskColor {
    if (overdueRatio == 0) return Colors.greenAccent;
    if (overdueRatio < 0.3) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
