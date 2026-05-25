import 'package:flutter/material.dart';

import '../core/pdf_branding.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/group_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';
import '../providers/analytics_provider.dart';
import 'loan_details_screen.dart';
import '../services/loan_calculation_service.dart';
import '../services/excel_export_service.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../models/vendor.dart';
import '../models/group.dart';

class _ReportHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ReportHeaderAction({
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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedLoanId;
  String? _editingFieldKey;
  final Map<String, TextEditingController> _controllers = {};
  int _selectedMonthFilter = DateTime.now().month;

  List<Map<String, dynamic>> _getMonthFilterOptions() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final List<String> monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    List<Map<String, dynamic>> options = [];

    options.add({
      'value': 0,
      'label': 'All Months (Cumulative: Jan - ${monthNames[currentMonth]} $currentYear)',
    });

    for (int m = 1; m <= currentMonth; m++) {
      final isCurrent = m == currentMonth;
      options.add({
        'value': m,
        'label': '${monthNames[m]} $currentYear${isCurrent ? ' (Current)' : ''}',
      });
    }

    return options;
  }

  String _getSelectedPeriodString() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    final List<String> monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (_selectedMonthFilter == 0) {
      return 'Cumulative (Jan - ${monthNames[currentMonth]} $currentYear)';
    } else {
      return '${monthNames[_selectedMonthFilter]} $currentYear';
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onCellTap(String loanId, String fieldName, String initialValue) {
    setState(() {
      _selectedLoanId = loanId;
      _editingFieldKey = "${loanId}_$fieldName";
      _controllers[_editingFieldKey!] = TextEditingController(
        text: initialValue,
      );
    });
  }

  Future<void> _saveEdit(String loanId, String fieldName) async {
    final controller = _controllers[_editingFieldKey];
    if (controller == null) return;

    final newValue = controller.text;
    Map<String, dynamic> updates = {};

    if (fieldName == 'amount')
      updates['amount'] = double.tryParse(newValue) ?? 0.0;
    else if (fieldName == 'durationMonths')
      updates['duration_months'] = int.tryParse(newValue) ?? 0;
    else if (fieldName == 'initiationFee')
      updates['initiation_fee'] = double.tryParse(newValue) ?? 0.0;
    else if (fieldName == 'monthlyAdminFee')
      updates['monthly_admin_fee'] = double.tryParse(newValue) ?? 0.0;
    else if (fieldName == 'penaltyFee')
      updates['penalty_fee'] = double.tryParse(newValue) ?? 0.0;
    else if (fieldName == 'firstInstalmentDate') {
      final parsed = DateTime.tryParse(newValue);
      if (parsed != null) updates['first_instalment_date'] = parsed.toIso8601String();
    }

    if (updates.isNotEmpty) {
      try {
        await context.read<LoanProvider>().updateLoan(loanId, updates);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Update successful'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    setState(() {
      _editingFieldKey = null;
    });
  }

  void _confirmDelete(String loanId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan Record?'),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Are you sure you want to delete this loan record?',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<LoanProvider>().deleteLoan(loanId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loan deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupProvider = context.watch<GroupProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    final vendorProvider = context.watch<VendorProvider>();

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final List<LoanModel> filteredLoans;
    final List<PaymentModel> filteredPayments;
    final List<VendorModel> filteredVendors;

    if (_selectedMonthFilter == 0) {
      filteredLoans = loanProvider.loans.where((l) {
        final date = l.firstInstalmentDate ?? l.createdAt;
        return date.year == currentYear && date.month <= currentMonth;
      }).toList();
      filteredPayments = paymentProvider.payments.where((p) =>
        p.datePaid.year == currentYear && p.datePaid.month <= currentMonth
      ).toList();
      filteredVendors = vendorProvider.vendors;
    } else {
      filteredLoans = loanProvider.loans.where((l) {
        final date = l.firstInstalmentDate ?? l.createdAt;
        return date.year == currentYear && date.month == _selectedMonthFilter;
      }).toList();
      filteredPayments = paymentProvider.payments.where((p) =>
        p.datePaid.year == currentYear && p.datePaid.month == _selectedMonthFilter
      ).toList();
      filteredVendors = vendorProvider.vendors;
    }

    final totalDisbursed = filteredLoans.fold(
      0.0,
      (sum, l) => sum + l.amount,
    );
    final totalCollected = filteredPayments.fold(
      0.0,
      (sum, p) => sum + p.amountPaid,
    );
    double totalOutstanding = 0;
    for (final loan in filteredLoans) {
      final loanPayments = filteredPayments
          .where((p) => p.loanId == loan.id)
          .toList();
      totalOutstanding += LoanCalculationService.calculateBalance(
        loan,
        loanPayments,
      );
    }
    final totalSavings = filteredVendors.fold(
      0.0,
      (sum, v) => sum + (v.savingsAmount ?? 0.0),
    );

    final totalInitiationFees = filteredLoans.fold(
      0.0,
      (sum, l) => sum + (l.initiationFee ?? 0),
    );
    final totalAdminFees = filteredLoans.fold(
      0.0,
      (sum, l) => sum + ((l.monthlyAdminFee ?? 0) * l.durationMonths),
    );
    final totalPenaltyFees = filteredLoans.fold(0.0, (sum, l) {
      final loanPayments = filteredPayments
          .where((p) => p.loanId == l.id)
          .toList();
      return sum +
          LoanCalculationService.calculateAppliedPenalty(l, loanPayments);
    });
    final totalExpectedFees =
        totalInitiationFees + totalAdminFees + totalPenaltyFees;

    double aging30 = 0;
    double aging60 = 0;
    double aging90 = 0;
    double aging90Plus = 0;

    final Map<String, double> breakdownByDF = {};
    final Map<String, double> breakdownByCenter = {};
    final Map<String, double> breakdownByType = {};

    final Map<String, GroupModel> groupMap = {for (var g in groupProvider.groups) g.id: g};

    for (var loan in filteredLoans) {
      final loanPayments = filteredPayments.where((p) => p.loanId == loan.id).toList();
      final balance = LoanCalculationService.calculateBalance(loan, loanPayments);

      if (balance > 0) {
        final group = groupMap[loan.groupId];
        final dfName = group?.dfName ?? 'Unassigned';
        final centerId = group?.centerId ?? 'Unassigned';
        final loanType = loan.loanType ?? 'Standard';

        breakdownByDF[dfName] = (breakdownByDF[dfName] ?? 0) + balance;
        breakdownByCenter[centerId] = (breakdownByCenter[centerId] ?? 0) + balance;
        breakdownByType[loanType] = (breakdownByType[loanType] ?? 0) + balance;

        final arrears = LoanCalculationService.calculateArrears(loan, loanPayments);
        if (arrears > 0) {
          final monthsOverdue = (arrears / (loan.monthlyPayment > 0 ? loan.monthlyPayment : 1)).ceil();
          final daysOverdue = monthsOverdue * 30;

          if (daysOverdue <= 30) {
            aging30 += arrears;
          } else if (daysOverdue <= 60) {
            aging60 += arrears;
          } else if (daysOverdue <= 90) {
            aging90 += arrears;
          } else {
            aging90Plus += arrears;
          }
        }
      }
    }

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
                  Icons.bar_chart_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Financial Reports',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _ReportHeaderAction(
                  icon: Icons.table_view_outlined,
                  tooltip: 'Export Excel',
                  onPressed: () => _exportToExcel(
                    filteredLoans,
                    filteredPayments,
                    vendorProvider,
                    groupProvider,
                  ),
                ),
                const SizedBox(width: 4),
                _ReportHeaderAction(
                  icon: Icons.download_rounded,
                  tooltip: 'Export PDF Report',
                  onPressed: () => _generatePDF(
                    context,
                    totalDisbursed,
                    totalCollected,
                    totalOutstanding,
                    totalExpectedFees,
                    totalSavings,
                    filteredLoans,
                    filteredPayments,
                  ),
                ),
              ],
            ),
          ),

          // ─── Body ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period filter
                  _buildFilterBar(context, theme),
                  const SizedBox(height: 24),

                  // Stats row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.payments_outlined,
                          iconColor: theme.colorScheme.primary,
                          title: 'Total Disbursed',
                          value: 'R ${totalDisbursed.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: Colors.green,
                          title: 'Total Collected',
                          value: 'R ${totalCollected.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.pending_actions,
                          iconColor: Colors.orange,
                          title: 'Outstanding Capital',
                          value: 'R ${totalOutstanding.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.savings_outlined,
                          iconColor: Colors.blue,
                          title: 'Total Savings',
                          value: 'R ${totalSavings.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.fiber_new,
                          iconColor: Colors.teal,
                          title: 'Initiation Fees',
                          value: 'R ${totalInitiationFees.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.admin_panel_settings_outlined,
                          iconColor: Colors.indigo,
                          title: 'Admin & Service Fees',
                          value: 'R ${totalAdminFees.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme: theme,
                          icon: Icons.summarize_outlined,
                          iconColor: Colors.deepPurple,
                          title: 'Total Expected Fees',
                          value: 'R ${totalExpectedFees.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ─── Master Loan Ledger ───
                  _SectionLabel(label: 'MASTER LOAN LEDGER'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detailed Breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(2.5),
                            1: FlexColumnWidth(1.3),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(1.5),
                            5: FlexColumnWidth(0.9),
                            6: FlexColumnWidth(0.6),
                            7: FlexColumnWidth(0.7),
                            8: FlexColumnWidth(0.7),
                            9: FlexColumnWidth(0.7),
                            10: FlexColumnWidth(1),
                            11: FlexColumnWidth(1),
                            12: FlexColumnWidth(1),
                            13: FlexColumnWidth(0.5),
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
                                _th('Member Name'),
                                _th('ID Number'),
                                _th('Phone'),
                                _th('Group'),
                                _th('Business'),
                                _th('Principal'),
                                _th('Term'),
                                _th('Init Fee'),
                                _th('Admin Fee'),
                                _th('Penalty'),
                                _th('Monthly'),
                                _th('Total Paid'),
                                _th('Balance'),
                                _th(''),
                              ],
                            ),
                            ...filteredLoans.map((loan) {
                              final isSelected = loan.id == _selectedLoanId;
                              final vendor = vendorProvider.vendors
                                  .where((v) => v.id == loan.vendorId)
                                  .firstOrNull;
                              final group = groupProvider.groups
                                  .where((g) => g.id == loan.groupId)
                                  .firstOrNull;
                              final loanPayments = filteredPayments
                                  .where((p) => p.loanId == loan.id)
                                  .toList();
                              final totalPaid = loanPayments.fold(
                                0.0,
                                (sum, p) => sum + p.amountPaid,
                              );
                              final appliedPenalty =
                                  LoanCalculationService.calculateAppliedPenalty(
                                    loan,
                                    loanPayments,
                                  );
                              final balance = LoanCalculationService.calculateBalance(
                                loan,
                                loanPayments,
                              );

                              void _goToLoan() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        LoanDetailsScreen(loan: loan),
                                  ),
                                );
                              }

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryGold.withOpacity(0.08)
                                      : null,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: theme.dividerColor.withOpacity(0.08),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                children: [
                                  _td(vendor?.name ?? 'Unknown', isBold: true),
                                  _td(vendor?.idNumber ?? '-'),
                                  _td(vendor?.phone ?? '-'),
                                  _td(group?.name ?? '-'),
                                  _td(vendor?.businessType ?? '-'),
                                  _tdEditable(
                                    loan.id, 'amount',
                                    loan.amount.toStringAsFixed(0),
                                    prefix: 'R ',
                                  ),
                                  _tdEditable(
                                    loan.id, 'durationMonths',
                                    loan.durationMonths.toString(),
                                    suffix: 'm',
                                  ),
                                  _tdEditable(
                                    loan.id, 'initiationFee',
                                    loan.initiationFee?.toStringAsFixed(0) ?? '0',
                                    prefix: 'R ',
                                  ),
                                  _tdEditable(
                                    loan.id, 'monthlyAdminFee',
                                    loan.monthlyAdminFee?.toStringAsFixed(0) ?? '0',
                                    prefix: 'R ',
                                  ),
                                  _tdEditable(
                                    loan.id, 'penaltyFee',
                                    appliedPenalty.toStringAsFixed(0),
                                    prefix: 'R ',
                                  ),
                                  _td(
                                    'R ${loan.monthlyPayment.toStringAsFixed(0)}',
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
                                  _actionsCell(loan.id),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ─── Advanced Insights ───
                  _SectionLabel(label: 'ADVANCED INSIGHTS & AGING ANALYSIS'),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildInsightCard(
                          theme: theme,
                          title: 'Monthly Financial Breakdown',
                          child: _buildMonthlyBreakdownTable(context),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _buildInsightCard(
                          theme: theme,
                          title: 'Arrears Aging Analysis',
                          child: _buildAgingTable(
                            context, aging30, aging60, aging90, aging90Plus,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInsightCard(
                          theme: theme,
                          title: 'Loan Book by Facilitator',
                          child: _buildBreakdownTable(context, 'DF', breakdownByDF),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildInsightCard(
                          theme: theme,
                          title: 'Loan Book by Center',
                          child: _buildBreakdownTable(context, 'Center', breakdownByCenter),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildInsightCard(
                          theme: theme,
                          title: 'Loan Book by Type',
                          child: _buildBreakdownTable(context, 'Type', breakdownByType),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ─── Collection Rate Footer ───
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        'Collection Rate: ${totalDisbursed > 0 ? (totalCollected / totalDisbursed * 100).toStringAsFixed(1) : '0'}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
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

  // ─── Filter Bar ───

  Widget _buildFilterBar(BuildContext context, ThemeData theme) {
    final options = _getMonthFilterOptions();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 18,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REPORTING PERIOD',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              Text(
                _getSelectedPeriodString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonthFilter,
                isDense: true,
                dropdownColor: theme.cardColor,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: theme.textTheme.bodySmall?.color,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedMonthFilter = newValue;
                    });
                  }
                },
                items: options.map<DropdownMenuItem<int>>((option) {
                  return DropdownMenuItem<int>(
                    value: option['value'] as int,
                    child: Text(
                      option['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Card ───

  Widget _buildStatCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Table helpers ───

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: color,
          fontSize: 11,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tdEditable(
    String loanId,
    String fieldName,
    String value, {
    String prefix = '',
    String suffix = '',
  }) {
    final key = "${loanId}_$fieldName";
    final isEditing = _editingFieldKey == key;

    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          height: 32,
          child: TextField(
            controller: _controllers[key],
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
              ),
              prefixText: prefix,
              prefixStyle: const TextStyle(color: AppTheme.primaryGold, fontSize: 9),
              suffixText: suffix,
              suffixStyle: const TextStyle(color: AppTheme.primaryGold, fontSize: 9),
            ),
            onSubmitted: (_) => _saveEdit(loanId, fieldName),
            onTapOutside: (_) => _saveEdit(loanId, fieldName),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _onCellTap(loanId, fieldName, value),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              "$prefix$value$suffix",
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Positioned(
            top: 1,
            right: 1,
            child: Icon(
              Icons.edit_note,
              size: 10,
              color: AppTheme.primaryGold.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCell(String loanId) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 14, color: Colors.grey),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'view') {
          final loan = context.read<LoanProvider>().loans.firstWhere(
            (l) => l.id == loanId,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoanDetailsScreen(loan: loan),
            ),
          );
        } else if (value == 'edit') {
          final loan = context.read<LoanProvider>().loans.firstWhere(
            (l) => l.id == loanId,
          );
          _onCellTap(loanId, 'amount', loan.amount.toStringAsFixed(0));
        } else if (value == 'delete') {
          _confirmDelete(loanId);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: AppTheme.primaryGold),
              SizedBox(width: 8),
              Text('Edit Inline'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 16),
              SizedBox(width: 8),
              Text('View Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Insight Card ───

  Widget _buildInsightCard({
    required ThemeData theme,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─── Monthly Breakdown Table ───

  Widget _buildMonthlyBreakdownTable(BuildContext context) {
    final trend = context.watch<AnalyticsProvider>().monthlyTrend;
    final theme = Theme.of(context);

    final List<String> shortMonths = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: theme.dividerColor.withOpacity(0.3), width: 0.5),
        columnWidths: const {
          0: FixedColumnWidth(70),
          1: FixedColumnWidth(90),
          2: FixedColumnWidth(80),
          3: FixedColumnWidth(80),
          4: FixedColumnWidth(80),
          5: FixedColumnWidth(90),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.08)),
            children: [
              _th('Month'),
              _th('Principal'),
              _th('Interest'),
              _th('Admin Fee'),
              _th('Init Fee'),
              _th('Actual Coll'),
            ],
          ),
          ...trend.map((t) {
            final isSelectedMonth = _selectedMonthFilter > 0 &&
                shortMonths[_selectedMonthFilter] == t.month;

            return TableRow(
              decoration: isSelectedMonth
                  ? BoxDecoration(color: AppTheme.primaryGold.withOpacity(0.1))
                  : null,
              children: [
                _td(
                  t.month,
                  isBold: isSelectedMonth,
                  color: isSelectedMonth ? AppTheme.primaryGold : null,
                ),
                _td('R ${t.disbursed.toStringAsFixed(0)}', isBold: isSelectedMonth),
                _td('R ${t.interest.toStringAsFixed(0)}', isBold: isSelectedMonth),
                _td('R ${t.adminFees.toStringAsFixed(0)}', isBold: isSelectedMonth),
                _td('R ${t.initiationFees.toStringAsFixed(0)}', isBold: isSelectedMonth),
                _td(
                  'R ${t.collected.toStringAsFixed(0)}',
                  color: isSelectedMonth ? AppTheme.primaryGold : Colors.green,
                  isBold: isSelectedMonth,
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // ─── Aging Table ───

  Widget _buildAgingTable(
    BuildContext context,
    double aging30,
    double aging60,
    double aging90,
    double aging90Plus,
  ) {
    final totalArrears = aging30 + aging60 + aging90 + aging90Plus;
    final theme = Theme.of(context);

    return Table(
      border: TableBorder.all(color: theme.dividerColor.withOpacity(0.3), width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.08)),
          children: [
            _th('Aging Bracket'),
            _th('Amount'),
          ],
        ),
        _agingRow('30 Days', aging30, Colors.orange),
        _agingRow('60 Days', aging60, Colors.deepOrange),
        _agingRow('90 Days', aging90, Colors.red),
        _agingRow('90+ Days', aging90Plus, Colors.red.shade900),
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.12)),
          children: [
            _th('Total Arrears'),
            _th('R ${totalArrears.toStringAsFixed(0)}'),
          ],
        ),
      ],
    );
  }

  TableRow _agingRow(String label, double amount, Color color) {
    return TableRow(
      children: [
        _td(label),
        _td('R ${amount.toStringAsFixed(0)}', color: color, isBold: true),
      ],
    );
  }

  // ─── Breakdown Table ───

  Widget _buildBreakdownTable(BuildContext context, String mode, Map<String, double> data) {
    final theme = Theme.of(context);

    return Table(
      border: TableBorder.all(color: theme.dividerColor.withOpacity(0.3), width: 0.5),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.08)),
          children: [
            _th(mode),
            _th('Balance'),
          ],
        ),
        ...data.entries.map((e) => TableRow(
          children: [
            _td(e.key),
            _td('R ${e.value.toStringAsFixed(0)}', isBold: true),
          ],
        )).toList(),
      ],
    );
  }

  // ─── Export ───

  Future<void> _generatePDF(
    BuildContext context,
    double disbursed,
    double collected,
    double outstanding,
    double fees,
    double savings,
    List<LoanModel> filteredLoans,
    List<PaymentModel> filteredPayments,
  ) async {
    final groupProvider = context.read<GroupProvider>();
    final vendorProvider = context.read<VendorProvider>();

    final pdf = pw.Document();

    final logo = await PdfBranding.loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, height: 60),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'NSBSA Financial Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Period: ${_getSelectedPeriodString()}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Exported: ${DateTime.now().toString().substring(0, 10)}',
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 30),
            pw.Text(
              'Executive Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfStat('Total Disbursed', 'R ${disbursed.toStringAsFixed(2)}'),
                _pdfStat('Total Collected', 'R ${collected.toStringAsFixed(2)}'),
                _pdfStat('Outstanding', 'R ${outstanding.toStringAsFixed(2)}'),
                _pdfStat('Total Savings', 'R ${savings.toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Fee Revenue Summary',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Initiation and Admin Fees: R ${fees.toStringAsFixed(2)}',
            ),
            pw.SizedBox(height: 40),

            pw.Text(
              'Master Loan Ledger (Detailed Breakdown)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _pdfCell('Name', isBold: true),
                    _pdfCell('Group', isBold: true),
                    _pdfCell('Principal', isBold: true),
                    _pdfCell('Term', isBold: true),
                    _pdfCell('Init Fee', isBold: true),
                    _pdfCell('Admin', isBold: true),
                    _pdfCell('Monthly', isBold: true),
                    _pdfCell('Paid', isBold: true),
                    _pdfCell('Balance', isBold: true),
                  ],
                ),
                ...filteredLoans.map((loan) {
                  final vendor = vendorProvider.vendors
                      .where((v) => v.id == loan.vendorId)
                      .firstOrNull;
                  final group = groupProvider.groups
                      .where((g) => g.id == loan.groupId)
                      .firstOrNull;
                  final loanPayments = filteredPayments
                      .where((p) => p.loanId == loan.id)
                      .toList();
                  final totalPaid = loanPayments.fold(
                    0.0,
                    (sum, p) => sum + p.amountPaid,
                  );
                  final balance = LoanCalculationService.calculateBalance(
                    loan,
                    loanPayments,
                  );

                  return pw.TableRow(
                    children: [
                      _pdfCell(vendor?.name ?? 'Unknown'),
                      _pdfCell(group?.name ?? '-'),
                      _pdfCell('R ${loan.amount.toStringAsFixed(0)}'),
                      _pdfCell('${loan.durationMonths}m'),
                      _pdfCell(
                        'R ${loan.initiationFee?.toStringAsFixed(0) ?? '0'}',
                      ),
                      _pdfCell(
                        'R ${loan.monthlyAdminFee?.toStringAsFixed(0) ?? '0'}',
                      ),
                      _pdfCell('R ${loan.monthlyPayment.toStringAsFixed(0)}'),
                      _pdfCell('R ${totalPaid.toStringAsFixed(0)}'),
                      _pdfCell('R ${balance.toStringAsFixed(0)}'),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'NSBSA_Master_Ledger_${DateTime.now().toString().substring(0, 10)}',
    );
  }

  pw.Widget _pdfCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _pdfStat(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _exportToExcel(
    List<LoanModel> filteredLoans,
    List<PaymentModel> filteredPayments,
    VendorProvider vendorProvider,
    GroupProvider groupProvider,
  ) async {
    final List<List<String>> data = [
      [
        'Member Name',
        'ID Number',
        'Phone',
        'Group',
        'Business',
        'Principal',
        'Term',
        'Init Fee',
        'Admin Fee',
        'Penalty',
        'Monthly',
        'Total Paid',
        'Balance',
      ],
    ];

    for (var loan in filteredLoans) {
      final vendor = vendorProvider.vendors
          .where((v) => v.id == loan.vendorId)
          .firstOrNull;
      final group = groupProvider.groups
          .where((g) => g.id == loan.groupId)
          .firstOrNull;
      final loanPayments = filteredPayments
          .where((p) => p.loanId == loan.id)
          .toList();
      final totalPaid = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
      final balance = LoanCalculationService.calculateBalance(
        loan,
        loanPayments,
      );
      final penalty = LoanCalculationService.calculateAppliedPenalty(
        loan,
        loanPayments,
      );

      data.add([
        vendor?.name ?? 'Unknown',
        vendor?.idNumber ?? '-',
        vendor?.phone ?? '-',
        group?.name ?? '-',
        vendor?.businessType ?? '-',
        'R ${loan.amount.toStringAsFixed(0)}',
        '${loan.durationMonths}m',
        'R ${loan.initiationFee?.toStringAsFixed(0) ?? '0'}',
        'R ${loan.monthlyAdminFee?.toStringAsFixed(0) ?? '0'}',
        'R ${penalty.toStringAsFixed(0)}',
        'R ${loan.monthlyPayment.toStringAsFixed(0)}',
        'R ${totalPaid.toStringAsFixed(0)}',
        'R ${balance.toStringAsFixed(0)}',
      ]);
    }

    final totalDisbursed = filteredLoans.fold(0.0, (sum, l) => sum + l.amount);
    final totalCollected = filteredPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    double totalOutstanding = 0;
    for (var l in filteredLoans) {
      final lp = filteredPayments.where((p) => p.loanId == l.id).toList();
      totalOutstanding += LoanCalculationService.calculateBalance(l, lp);
    }
    final filteredVendors = vendorProvider.vendors.where((v) =>
      true
    ).toList();

    final totalSavings = filteredVendors.fold(0.0, (sum, v) => sum + (v.savingsAmount ?? 0.0));
    final totalInitFees = filteredLoans.fold(0.0, (sum, l) => sum + (l.initiationFee ?? 0));
    final totalAdminFees = filteredLoans.fold(0.0, (sum, l) => sum + ((l.monthlyAdminFee ?? 0) * l.durationMonths));
    final totalExpectedFees = totalInitFees + totalAdminFees;
    final collectionRate = totalDisbursed > 0 ? (totalCollected / totalDisbursed * 100).toStringAsFixed(1) : '0';

    await ExcelExportService.exportMasterLedger(
      summary: {
        'period': _getSelectedPeriodString(),
        'totalDisbursed': totalDisbursed.toStringAsFixed(0),
        'totalCollected': totalCollected.toStringAsFixed(0),
        'totalOutstanding': totalOutstanding.toStringAsFixed(0),
        'totalSavings': totalSavings.toStringAsFixed(0),
        'totalExpectedFees': totalExpectedFees.toStringAsFixed(0),
        'collectionRate': collectionRate,
      },
      ledgerData: data,
    );
  }
}
