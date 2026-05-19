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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedLoanId;
  String? _editingFieldKey; // format: "loanId_fieldName"
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
    
    // Add cumulative option at the top
    options.add({
      'value': 0, // 0 represents cumulative "All Months"
      'label': 'All Months (Cumulative: Jan - ${monthNames[currentMonth]} $currentYear)',
    });

    // Add specific months up to current month
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

    // Map field name to model property
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
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this loan record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
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

    // Filter loans & payments based on selected month
    final List<LoanModel> filteredLoans;
    final List<PaymentModel> filteredPayments;
    final List<VendorModel> filteredVendors;

    if (_selectedMonthFilter == 0) {
      // Cumulative: from start of year up to current month
      filteredLoans = loanProvider.loans.where((l) {
        final date = l.firstInstalmentDate ?? l.createdAt;
        return date.year == currentYear && date.month <= currentMonth;
      }).toList();
      filteredPayments = paymentProvider.payments.where((p) =>
        p.datePaid.year == currentYear && p.datePaid.month <= currentMonth
      ).toList();
      filteredVendors = vendorProvider.vendors;
    } else {
      // Specific month
      filteredLoans = loanProvider.loans.where((l) {
        final date = l.firstInstalmentDate ?? l.createdAt;
        return date.year == currentYear && date.month == _selectedMonthFilter;
      }).toList();
      filteredPayments = paymentProvider.payments.where((p) =>
        p.datePaid.year == currentYear && p.datePaid.month == _selectedMonthFilter
      ).toList();
      filteredVendors = vendorProvider.vendors;
    }

    // Calculate Summary Data
    final totalDisbursed = filteredLoans.fold(
      0.0,
      (sum, l) => sum + l.amount,
    );
    final totalCollected = filteredPayments.fold(
      0.0,
      (sum, p) => sum + p.amountPaid,
    );
    // Calculate Total Outstanding by summing individual loan balances
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

    // Fee Calculations
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

    // Calculate local filtered Arrears Aging
    double aging30 = 0;
    double aging60 = 0;
    double aging90 = 0;
    double aging90Plus = 0;

    // Calculate local filtered Loan Book Breakdown
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Performance',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comprehensive summary of all group lending activities',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _exportToExcel(
                      filteredLoans,
                      filteredPayments,
                      vendorProvider,
                      groupProvider,
                    ),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Export Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
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
                    icon: const Icon(Icons.download),
                    label: const Text('Export PDF Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Month Filter Bar
          _buildFilterBar(context),
          const SizedBox(height: 32),

          // Main Stats Row
          Row(
            children: [
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Total Disbursed',
                  'R ${totalDisbursed.toStringAsFixed(0)}',
                  Icons.payments_outlined,
                  AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Total Collected',
                  'R ${totalCollected.toStringAsFixed(0)}',
                  Icons.account_balance_wallet_outlined,
                  AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Outstanding Capital',
                  'R ${totalOutstanding.toStringAsFixed(0)}',
                  Icons.pending_actions,
                  AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Total Savings',
                  'R ${totalSavings.toStringAsFixed(0)}',
                  Icons.savings_outlined,
                  AppTheme.primaryGold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Secondary Stats Row (Fees)
          Row(
            children: [
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Initiation Fees',
                  'R ${totalInitiationFees.toStringAsFixed(0)}',
                  Icons.fiber_new,
                  AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Admin & Service Fees',
                  'R ${totalAdminFees.toStringAsFixed(0)}',
                  Icons.admin_panel_settings_outlined,
                  AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildReportCard(
                  theme,
                  'Total Expected Fees',
                  'R ${totalExpectedFees.toStringAsFixed(0)}',
                  Icons.summarize_outlined,
                  AppTheme.primaryGold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Detailed Breakdown Table Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Master Loan Ledger (Detailed)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Table(
                    border: TableBorder.all(
                      color: theme.dividerColor,
                      width: 0.5,
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(2.5), // Name
                      1: FlexColumnWidth(1.8), // ID Number
                      2: FlexColumnWidth(1.8), // Phone
                      3: FlexColumnWidth(1.8), // Group
                      4: FlexColumnWidth(2), // Business
                      5: FlexColumnWidth(1.2), // Principal
                      6: FlexColumnWidth(0.8), // Term
                      7: FlexColumnWidth(0.8), // Init Fee
                      8: FlexColumnWidth(0.8), // Admin Fee
                      9: FlexColumnWidth(0.8), // Penalty
                      10: FlexColumnWidth(1.2), // Monthly
                      11: FlexColumnWidth(1.2), // Total Paid
                      12: FlexColumnWidth(1.2), // Balance
                      13: FlexColumnWidth(0.6), // Actions
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.03),
                        ),
                        children: [
                          _buildTableHeader('Member Name'),
                          _buildTableHeader('ID Number'),
                          _buildTableHeader('Phone'),
                          _buildTableHeader('Group'),
                          _buildTableHeader('Business'),
                          _buildTableHeader('Principal'),
                          _buildTableHeader('Term'),
                          _buildTableHeader('Init Fee'),
                          _buildTableHeader('Admin Fee'),
                          _buildTableHeader('Penalty'),
                          _buildTableHeader('Monthly'),
                          _buildTableHeader('Total Paid'),
                          _buildTableHeader('Balance'),
                          _buildTableHeader(''), // Actions
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
                                ? AppTheme.primaryGold.withOpacity(0.1)
                                : null,
                          ),
                          children: [
                            _buildTableCell(
                              vendor?.name ?? 'Unknown',
                              isBold: true,
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                              onDoubleTap: _goToLoan,
                            ),
                            _buildTableCell(
                              vendor?.idNumber ?? '-',
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildTableCell(
                              vendor?.phone ?? '-',
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildTableCell(
                              group?.name ?? '-',
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildTableCell(
                              vendor?.businessType ?? '-',
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildEditableTableCell(
                              loan.id,
                              'amount',
                              loan.amount.toStringAsFixed(0),
                              prefix: 'R ',
                            ),
                            _buildEditableTableCell(
                              loan.id,
                              'durationMonths',
                              loan.durationMonths.toString(),
                              suffix: 'm',
                            ),
                            _buildEditableTableCell(
                              loan.id,
                              'initiationFee',
                              loan.initiationFee?.toStringAsFixed(0) ?? '0',
                              prefix: 'R ',
                            ),
                            _buildEditableTableCell(
                              loan.id,
                              'monthlyAdminFee',
                              loan.monthlyAdminFee?.toStringAsFixed(0) ?? '0',
                              prefix: 'R ',
                            ),
                            _buildEditableTableCell(
                              loan.id,
                              'penaltyFee',
                              appliedPenalty.toStringAsFixed(0),
                              prefix: 'R ',
                            ),
                            _buildTableCell(
                              'R ${loan.monthlyPayment.toStringAsFixed(0)}',
                              color: AppTheme.primaryGold,
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildTableCell(
                              'R ${totalPaid.toStringAsFixed(0)}',
                              color: Colors.greenAccent,
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildTableCell(
                              'R ${balance.toStringAsFixed(0)}',
                              color: Colors.orangeAccent,
                              onTap: () =>
                                  setState(() => _selectedLoanId = loan.id),
                            ),
                            _buildActionsCell(loan.id),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 40),

          // Advanced Insights Section
          Text(
            'Advanced Insights & Aging Analysis',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Monthly Breakdown & Aging Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Financial Breakdown
              Expanded(
                flex: 3,
                child: _buildInsightCard(
                  theme,
                  'Monthly Financial Breakdown',
                  _buildMonthlyBreakdownTable(context),
                ),
              ),
              const SizedBox(width: 24),
              // Arrears Aging
              Expanded(
                flex: 2,
                child: _buildInsightCard(
                  theme,
                  'Arrears Aging Analysis',
                  _buildAgingTable(context, aging30, aging60, aging90, aging90Plus),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Loan Book Breakdown Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // By DF
              Expanded(
                child: _buildInsightCard(
                  theme,
                  'Loan Book by Facilitator (DF)',
                  _buildBreakdownTable(context, 'DF', breakdownByDF),
                ),
              ),
              const SizedBox(width: 24),
              // By Center
              Expanded(
                child: _buildInsightCard(
                  theme,
                  'Loan Book by Center',
                  _buildBreakdownTable(context, 'Center', breakdownByCenter),
                ),
              ),
              const SizedBox(width: 24),
              // By Loan Type
              Expanded(
                child: _buildInsightCard(
                  theme,
                  'Loan Book by Type',
                  _buildBreakdownTable(context, 'Type', breakdownByType),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final options = _getMonthFilterOptions();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: AppTheme.primaryGold, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPORTING PERIOD',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSelectedPeriodString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonthFilter,
                dropdownColor: theme.cardColor,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGold),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildReportCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up, color: color, size: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isBold = false,
    Color? color,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
  }) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
          fontSize: 11,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (onTap != null || onDoubleTap != null) {
      return InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: AppTheme.primaryGold.withOpacity(0.05),
        child: content,
      );
    }

    return content;
  }

  Widget _buildEditableTableCell(
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
        padding: const EdgeInsets.all(4.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: _controllers[key],
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
              prefixText: prefix,
              prefixStyle: const TextStyle(color: AppTheme.primaryGold, fontSize: 10),
              suffixText: suffix,
              suffixStyle: const TextStyle(color: AppTheme.primaryGold, fontSize: 10),
            ),
            onSubmitted: (_) => _saveEdit(loanId, fieldName),
            onTapOutside: (_) => _saveEdit(loanId, fieldName),
          ),
        ),
      );
    }

    return Stack(
      children: [
        _buildTableCell(
          "$prefix$value$suffix",
          onTap: () => _onCellTap(loanId, fieldName, value),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Icon(
            Icons.edit_note,
            size: 10,
            color: AppTheme.primaryGold.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCell(String loanId) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
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
          // Trigger inline edit for the first editable field (amount)
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
                _pdfStat(
                  'Total Disbursed',
                  'R ${disbursed.toStringAsFixed(2)}',
                ),
                _pdfStat(
                  'Total Collected',
                  'R ${collected.toStringAsFixed(2)}',
                ),
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

    // Calculate Summary Data
    final totalDisbursed = filteredLoans.fold(0.0, (sum, l) => sum + l.amount);
    final totalCollected = filteredPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    double totalOutstanding = 0;
    for (var l in filteredLoans) {
      final lp = filteredPayments.where((p) => p.loanId == l.id).toList();
      totalOutstanding += LoanCalculationService.calculateBalance(l, lp);
    }
    // Filter vendors to selected period
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
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

  Widget _buildInsightCard(ThemeData theme, String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBreakdownTable(BuildContext context) {
    final trend = context.watch<AnalyticsProvider>().monthlyTrend;
    final theme = Theme.of(context);

    // List of months for matching
    final List<String> shortMonths = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Table(
      border: TableBorder.all(color: theme.dividerColor, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.05)),
          children: [
            _buildTableHeader('Month'),
            _buildTableHeader('Principal'),
            _buildTableHeader('Interest'),
            _buildTableHeader('Admin Fee'),
            _buildTableHeader('Init Fee'),
            _buildTableHeader('Actual Coll'),
          ],
        ),
        ...trend.map((t) {
          final isSelectedMonth = _selectedMonthFilter > 0 && 
              shortMonths[_selectedMonthFilter] == t.month;

          return TableRow(
            decoration: isSelectedMonth
                ? BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.15),
                  )
                : null,
            children: [
              _buildTableCell(
                t.month,
                isBold: isSelectedMonth,
                color: isSelectedMonth ? AppTheme.primaryGold : null,
              ),
              _buildTableCell('R ${t.disbursed.toStringAsFixed(0)}', isBold: isSelectedMonth),
              _buildTableCell('R ${t.interest.toStringAsFixed(0)}', isBold: isSelectedMonth),
              _buildTableCell('R ${t.adminFees.toStringAsFixed(0)}', isBold: isSelectedMonth),
              _buildTableCell('R ${t.initiationFees.toStringAsFixed(0)}', isBold: isSelectedMonth),
              _buildTableCell(
                'R ${t.collected.toStringAsFixed(0)}',
                color: isSelectedMonth ? AppTheme.primaryGold : Colors.greenAccent,
                isBold: isSelectedMonth,
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

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
      border: TableBorder.all(color: theme.dividerColor, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.05)),
          children: [
            _buildTableHeader('Aging Bracket'),
            _buildTableHeader('Amount'),
          ],
        ),
        _buildAgingRow('30 Days', aging30, Colors.yellowAccent),
        _buildAgingRow('60 Days', aging60, Colors.orangeAccent),
        _buildAgingRow('90 Days', aging90, Colors.redAccent),
        _buildAgingRow('90+ Days', aging90Plus, Colors.red[900]!),
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.1)),
          children: [
            _buildTableHeader('Total Arrears'),
            _buildTableHeader('R ${totalArrears.toStringAsFixed(0)}'),
          ],
        ),
      ],
    );
  }

  TableRow _buildAgingRow(String label, double amount, Color color) {
    return TableRow(
      children: [
        _buildTableCell(label),
        _buildTableCell('R ${amount.toStringAsFixed(0)}', color: color, isBold: true),
      ],
    );
  }

  Widget _buildBreakdownTable(BuildContext context, String mode, Map<String, double> data) {
    final theme = Theme.of(context);

    return Table(
      border: TableBorder.all(color: theme.dividerColor, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: theme.dividerColor.withOpacity(0.05)),
          children: [
            _buildTableHeader(mode),
            _buildTableHeader('Balance'),
          ],
        ),
        ...data.entries.map((e) => TableRow(
          children: [
            _buildTableCell(e.key),
            _buildTableCell('R ${e.value.toStringAsFixed(0)}', isBold: true),
          ],
        )).toList(),
      ],
    );
  }
}
