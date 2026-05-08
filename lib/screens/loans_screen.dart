import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/group_provider.dart';
import '../providers/payment_provider.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';
import 'group_details_screen.dart';

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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Group Loan Tracking',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.account_balance, size: 16),
                label: const Text('New Loan Group'),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                          orElse: () => GroupModel(id: '', name: 'Unknown Group', referenceNumber: '', createdAt: DateTime.now()),
                        );
 
                        // Aggregated data
                        double totalAmount = loans.fold(0, (sum, l) => sum + l.amount);
                        double totalMonthly = loans.fold(0, (sum, l) => sum + l.monthlyPayment);
                        
                        // Calculate total paid for this group's loans
                        final loanIds = loans.map((l) => l.id).toSet();
                        double totalPaid = paymentProvider.payments
                            .where((p) => loanIds.contains(p.loanId))
                            .fold(0, (sum, p) => sum + p.amountPaid);
                        
                        double balance = totalAmount - totalPaid;
 
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.groups, color: AppTheme.primaryGold, size: 14),
                          ),
                          title: Text(
                            group.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text('${loans.length} Loans • Status: Active', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildSmallStat('Value: R ${totalAmount.toStringAsFixed(0)}', Colors.grey),
                                  const SizedBox(width: 8),
                                  _buildSmallStat('Paid: R ${totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                                  const SizedBox(width: 8),
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
