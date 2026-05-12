import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/group_provider.dart';
import '../providers/payment_provider.dart';
import '../models/group.dart';
import '../core/app_breakpoints.dart';
import '../theme/app_theme.dart';
import 'group_details_screen.dart';
import '../services/loan_calculation_service.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoanProvider>().fetchLoans();
      context.read<GroupProvider>().fetchGroups();
      context.read<PaymentProvider>().fetchPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loanProvider = context.watch<LoanProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    
    // Group loans by Group ID
    final Map<String, List<dynamic>> groupedLoans = {};
    for (var loan in loanProvider.loans) {
      groupedLoans.putIfAbsent(loan.groupId, () => []).add(loan);
    }

    final sortedGroupIds = groupedLoans.keys.toList();

    final isMobile = MediaQuery.of(context).size.width <
        AppBreakpoints.contentTabletMin;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Text(
                'Group Loan Tracking',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 20 : 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: (loanProvider.isLoading || groupProvider.isLoading)
                ? const Center(child: CircularProgressIndicator())
                : groupedLoans.isEmpty
                  ? const Center(child: Text('No active loan groups found.', style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: sortedGroupIds.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                      itemBuilder: (context, index) {
                        final groupId = sortedGroupIds[index];
                        final loans = groupedLoans[groupId]!;
                        final group = groupProvider.groups.firstWhere(
                          (g) => g.id == groupId,
                          orElse: GroupModel.unknown,
                        );
 
                        // Aggregated data
                        double totalAmount = loans.fold(0, (sum, l) => sum + l.amount);
                        double totalMonthly = loans.fold(0, (sum, l) => sum + l.monthlyPayment);
                        
                        // Calculate total paid for this group's loans
                        final loanIds = loans.map((l) => l.id).toSet();
                        double totalPaid = paymentProvider.payments
                            .where((p) => loanIds.contains(p.loanId))
                            .fold(0, (sum, p) => sum + p.amountPaid);

                        // Calculate total balance by summing individual loan balances
                        double balance = 0;
                        for (final loan in loans) {
                          final loanPayments = paymentProvider.payments.where((p) => p.loanId == loan.id).toList();
                          balance += LoanCalculationService.calculateBalance(loan, loanPayments);
                        }
 
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          leading: isMobile ? null : CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.groups, color: AppTheme.primaryGold, size: 14),
                          ),
                          title: Text(
                            group.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${loans.length} Loans • Status: Active', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSmallStat('Value: R ${totalAmount.toStringAsFixed(0)}', Colors.grey),
                                  _buildSmallStat('Paid: R ${totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                                  _buildSmallStat('Bal: R ${balance.toStringAsFixed(0)}', Colors.amberAccent),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupDetailsScreen(group: group),
                              ),
                            );
                          },
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'R ${totalMonthly.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryGold),
                              ),
                              const Text('/month', style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
