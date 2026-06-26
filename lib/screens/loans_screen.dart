import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/group_provider.dart';
import '../providers/payment_provider.dart';
import '../models/group.dart';
import '../theme/app_theme.dart';
import 'group_details_screen.dart';
import '../services/loan_calculation_service.dart';

class _LoanHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _LoanHeaderAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
      ),
    );
  }
}

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

    final Map<String, List<dynamic>> groupedLoans = {};
    for (var loan in loanProvider.loans) {
      groupedLoans.putIfAbsent(loan.groupId, () => []).add(loan);
    }

    final sortedGroupIds = groupedLoans.keys.toList();

    final isSmall = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ───
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Group Loan Tracking',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _LoanHeaderAction(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onPressed: () {
                    context.read<LoanProvider>().fetchLoans();
                    context.read<GroupProvider>().fetchGroups();
                    context.read<PaymentProvider>().fetchPayments();
                  },
                ),
              ],
            ),
          ),

          // ─── Body ───
          Expanded(
            child: (loanProvider.isLoading || groupProvider.isLoading)
                ? const Center(child: CircularProgressIndicator())
                : groupedLoans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 48,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active loan groups found.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${groupedLoans.length} groups with active loans',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.5),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Table(
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              columnWidths: {
                                0: FlexColumnWidth(isSmall ? 1.8 : 2.2),
                                1: FlexColumnWidth(isSmall ? 0.8 : 1),
                                2: FlexColumnWidth(isSmall ? 0.9 : 1.2),
                                3: FlexColumnWidth(isSmall ? 0.9 : 1.1),
                                4: FlexColumnWidth(isSmall ? 0.9 : 1.1),
                                5: FlexColumnWidth(isSmall ? 0.9 : 1.1),
                                6: FlexColumnWidth(isSmall ? 0.7 : 0.8),
                                7: FlexColumnWidth(isSmall ? 0.5 : 0.6),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.dividerColor.withOpacity(0.15),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    _th('Group Name'),
                                    _th('Loans'),
                                    _th('Total Value'),
                                    _th('Monthly'),
                                    _th('Total Paid'),
                                    _th('Balance'),
                                    _th('Status'),
                                    _th(''),
                                  ],
                                ),
                                ...sortedGroupIds.map((groupId) {
                                  final loans = groupedLoans[groupId]!;
                                  final group = groupProvider.groups.firstWhere(
                                    (g) => g.id == groupId,
                                    orElse: GroupModel.unknown,
                                  );

                                  double totalAmount = loans.fold(
                                    0,
                                    (sum, l) => sum + l.amount,
                                  );
                                  double totalMonthly = loans.fold(
                                    0,
                                    (sum, l) => sum + l.monthlyPayment,
                                  );

                                  final loanIds = loans.map((l) => l.id).toSet();
                                  double totalPaid = paymentProvider.payments
                                      .where((p) => loanIds.contains(p.loanId))
                                      .fold(0, (sum, p) => sum + p.amountPaid);

                                  double balance = 0;
                                  for (final loan in loans) {
                                    final loanPayments = paymentProvider.payments
                                        .where((p) => p.loanId == loan.id)
                                        .toList();
                                    balance += LoanCalculationService.calculateBalance(
                                      loan,
                                      loanPayments,
                                    );
                                  }

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: theme.dividerColor.withOpacity(0.06),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  GroupDetailsScreen(group: group),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryGold.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.groups,
                                                  size: 14,
                                                  color: AppTheme.primaryGold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  group.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      _td('${loans.length}'),
                                      _td(
                                        'R ${totalAmount.toStringAsFixed(0)}',
                                        isBold: true,
                                      ),
                                      _td(
                                        'R ${totalMonthly.toStringAsFixed(0)}',
                                        color: AppTheme.primaryGold,
                                      ),
                                      _td(
                                        'R ${totalPaid.toStringAsFixed(0)}',
                                        color: Colors.green,
                                      ),
                                      _td(
                                        'R ${balance.toStringAsFixed(0)}',
                                        color: Colors.orange,
                                      ),
                                      _statusBadge(balance > 0 ? 'Active' : 'Paid'),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 4,
                                        ),
                                        child: _actionIcon(
                                          icon: Icons.chevron_right,
                                          color: (theme.textTheme.bodySmall?.color ?? Colors.grey).withOpacity(0.4),
                                          tooltip: 'View Details',
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    GroupDetailsScreen(group: group),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
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

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _td(
    String text, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: color,
          fontSize: 12,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status == 'Active';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isActive ? Colors.green : Colors.grey).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: (isActive ? Colors.green : Colors.grey).withOpacity(0.3),
          ),
        ),
        child: isActive
            ? const Icon(Icons.play_circle_filled, size: 14, color: Colors.green)
            : Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
      ),
    );
  }
}
