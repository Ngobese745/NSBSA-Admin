import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/group_provider.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';
import '../models/loan.dart';
import '../models/vendor.dart';
import '../models/group.dart';
import '../models/payment.dart';
import '../services/loan_calculation_service.dart';
import 'dart:async';
import 'loan_details_screen.dart';

class MasterLoanLedgerScreen extends StatefulWidget {
  const MasterLoanLedgerScreen({super.key});

  @override
  State<MasterLoanLedgerScreen> createState() =>
      _MasterLoanLedgerScreenState();
}

class _MasterLoanLedgerScreenState extends State<MasterLoanLedgerScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // Inline editing
  String? _editingKey;
  final _editControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    for (final c in _editControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.trim());
      }
    });
  }

  String _editKey(String loanId, String field) => '${loanId}_$field';

  void _startEdit(String loanId, String field, String initialValue) {
    final key = _editKey(loanId, field);
    setState(() {
      _editingKey = key;
      _editControllers[key] = TextEditingController(text: initialValue);
    });
  }

  void _saveEdit(String loanId, String field) {
    final key = _editKey(loanId, field);
    final ctrl = _editControllers[key];
    if (ctrl == null) return;

    final raw = ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _editingKey = null);
      return;
    }

    Map<String, dynamic> updates;
    switch (field) {
      case 'amount':
        updates = {'amount': double.tryParse(raw) ?? 0};
        break;
      case 'term':
        updates = {'duration_months': int.tryParse(raw) ?? 0};
        break;
      case 'monthlyPayment':
        updates = {'monthly_payment': double.tryParse(raw) ?? 0};
        break;
      case 'initiationFee':
        updates = {'initiation_fee': double.tryParse(raw) ?? 0};
        break;
      case 'adminFee':
        updates = {'monthly_admin_fee': double.tryParse(raw) ?? 0};
        break;
      case 'penaltyFee':
        updates = {'penalty_fee': double.tryParse(raw) ?? 0};
        break;
      default:
        setState(() => _editingKey = null);
        return;
    }

    context.read<LoanProvider>().updateLoan(loanId, updates).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    });
    setState(() => _editingKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loans = context.watch<LoanProvider>().loans;
    final vendors = context.watch<VendorProvider>().vendors;
    final groups = context.watch<GroupProvider>().groups;
    final payments = context.watch<PaymentProvider>().payments;

    final vendorMap = {for (final v in vendors) v.id: v};
    final groupMap = {for (final g in groups) g.id: g};
    final paymentsByLoan = <String, List<PaymentModel>>{};
    for (final p in payments) {
      paymentsByLoan.putIfAbsent(p.loanId ?? '', () => []).add(p);
    }

    final q = _searchQuery.toLowerCase();
    final filtered = (q.isEmpty ? loans : loans.where((loan) {
      final v = vendorMap[loan.vendorId];
      final g = groupMap[loan.groupId];
      return (loan.vendorName?.toLowerCase().contains(q) == true) ||
          (v?.name.toLowerCase().contains(q) == true) ||
          (v?.phone?.toLowerCase().contains(q) == true) ||
          (v?.idNumber?.toLowerCase().contains(q) == true) ||
          (g?.name.toLowerCase().contains(q) == true) ||
          loan.amount.toString().contains(q) ||
          loan.status.toLowerCase().contains(q);
    }))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ───
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _HeaderAction(
                      icon: Icons.account_balance,
                      tooltip: 'Master Loan Ledger',
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Master Loan Ledger',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} loan${filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Search by name, ID, phone, group, amount, status…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.dividerColor.withOpacity(0.5),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Table ───
          Expanded(
            child: Container(
              color: theme.cardColor,
              child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No loans match "$_searchQuery".'
                          : 'No loans found.',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                  )
                : SingleChildScrollView(
                    child: Table(
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FlexColumnWidth(3.0),   // Member Name
                        1: FlexColumnWidth(2.0),   // ID Number
                        2: FlexColumnWidth(1.8),   // Phone
                        3: FlexColumnWidth(2.2),   // Group
                        4: FlexColumnWidth(1.5),   // Amount
                        5: FlexColumnWidth(1.2),   // Term
                        6: FlexColumnWidth(1.5),   // Balance
                        7: FlexColumnWidth(1.5),   // Total Paid
                        8: FlexColumnWidth(1.5),   // Monthly
                        9: FlexColumnWidth(1.2),   // Status
                        10: FlexColumnWidth(1.2),  // Grace
                        11: FlexColumnWidth(0.8),  // Actions
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: theme.dividerColor.withOpacity(0.06),
                        ),
                      ),
                      children: [
                        // ── Header row ──
                        TableRow(
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.05),
                          ),
                          children: [
                            _th('Member Name'),
                            _th('ID Number'),
                            _th('Phone'),
                            _th('Group'),
                            _th('Amount'),
                            _th('Term'),
                            _th('Balance'),
                            _th('Total Paid'),
                            _th('Monthly'),
                            _th('Status'),
                            _th('Grace'),
                            _th(''),
                          ],
                        ),
                        // ── Data rows ──
                        for (final loan in filtered)
                          _buildDataRow(
                            loan,
                            vendorMap[loan.vendorId],
                            groupMap[loan.groupId],
                            paymentsByLoan[loan.id] ?? [],
                            theme,
                          ),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  TableRow _buildDataRow(
    LoanModel loan,
    VendorModel? vendor,
    GroupModel? group,
    List<PaymentModel> loanPayments,
    ThemeData theme,
  ) {
    final totalPaid = loanPayments.fold(0.0, (s, p) => s + p.amountPaid);
    final balance = LoanCalculationService.calculateBalance(loan, loanPayments);
    final imported = loan.openingAmount != null;
    final inArrears = !imported && LoanCalculationService.isInArrears(loan, loanPayments);
    final arrearsAmount = inArrears
        ? LoanCalculationService.calculateArrears(loan, loanPayments)
        : 0.0;
    final arrearsFee = inArrears
        ? LoanCalculationService.arrearsFee(loan, loanPayments)
        : 0.0;
    final monthsBehind = inArrears
        ? LoanCalculationService.monthsInArrears(loan, loanPayments)
        : 0;

    return TableRow(
      children: [
        imported
            ? _td(loan.vendorName ?? vendor?.name ?? '—',
                icon: Icons.download_for_offline, iconTooltip: 'Imported')
            : inArrears
                ? _td(loan.vendorName ?? vendor?.name ?? '—',
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.redAccent,
                    iconTooltip: 'In Arrears (${monthsBehind}m) — R ${arrearsAmount.toStringAsFixed(0)} owed, R ${arrearsFee.toStringAsFixed(0)} penalty')
                : _td(loan.vendorName ?? vendor?.name ?? '—'),
        _td(vendor?.idNumber ?? '—'),
        _td(vendor?.phone ?? '—'),
        _td(group?.name ?? '—'),
        imported
            ? _td('R ${loan.amount.toStringAsFixed(0)}', color: Colors.blueGrey)
            : _editableTd(loan.id, 'amount', loan.amount.toStringAsFixed(0), prefix: 'R '),
        imported
            ? _td('${loan.durationMonths}m', color: Colors.blueGrey)
            : _editableTd(loan.id, 'term', loan.durationMonths.toString(), suffix: 'm'),
        _td('R ${balance.toStringAsFixed(0)}',
            color: inArrears ? Colors.redAccent : Colors.orange),
        _td('R ${totalPaid.toStringAsFixed(0)}', color: Colors.green),
        imported
            ? _td('R ${loan.monthlyPayment.toStringAsFixed(0)}', color: Colors.blueGrey)
            : _editableTd(loan.id, 'monthlyPayment', loan.monthlyPayment.toStringAsFixed(0), prefix: 'R '),
        _statusCell(loan.status, inArrears),
        _graceCell(loan),
        _actionsCell(loan.id, theme, imported: imported),
      ],
    );
  }

  // ─── Helpers ───

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
  Widget _td(String text, {Color? color, IconData? icon, Color? iconColor, String? iconTooltip}) {
    final textWidget = Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: color,
      ),
      overflow: TextOverflow.ellipsis,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: textWidget),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Tooltip(
                    message: iconTooltip ?? '',
                    child: Icon(icon, size: 12, color: iconColor ?? Colors.blueGrey.shade300),
                  ),
                ),
              ],
            )
          : textWidget,
    );
  }

  Widget _statusCell(String status, bool inArrears) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _statusBadge(status),
          if (inArrears)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Text(
                'ARREARS',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _graceCell(LoanModel loan) {
    if (!loan.gracePeriodEnabled) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 11)),
      );
    }
    final isActive = loan.isInGracePeriod;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Tooltip(
        message: isActive
            ? 'Client is in grace period. Payments start ${loan.firstPaymentDate?.toString().substring(0, 10) ?? ''}.'
            : 'Grace period ended. First payment was due ${loan.firstPaymentDate?.toString().substring(0, 10) ?? ''}.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.amber.withOpacity(0.15)
                : Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive
                  ? Colors.amber.withOpacity(0.4)
                  : Colors.green.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.hourglass_empty : Icons.check_circle_outline,
                size: 10,
                color: isActive ? Colors.amber : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                isActive ? 'GRACE' : 'ENDED',
                style: TextStyle(
                  color: isActive ? Colors.amber : Colors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${loan.gracePeriodMonths ?? 0}m',
                style: TextStyle(
                  color: isActive ? Colors.amber.shade100 : Colors.green.shade100,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editableTd(
    String loanId,
    String field,
    String value, {
    String prefix = '',
    String suffix = '',
  }) {
    final key = _editKey(loanId, field);
    final isEditing = _editingKey == key;

    if (isEditing) {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          height: 32,
          child: TextField(
            controller: _editControllers[key],
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(
                    color: AppTheme.primaryGold, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(
                    color: AppTheme.primaryGold, width: 1.5),
              ),
              prefixText: prefix,
              prefixStyle: const TextStyle(
                  color: AppTheme.primaryGold, fontSize: 9),
              suffixText: suffix,
              suffixStyle: const TextStyle(
                  color: AppTheme.primaryGold, fontSize: 9),
            ),
            onSubmitted: (_) => _saveEdit(loanId, field),
            onTapOutside: (_) => _saveEdit(loanId, field),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _startEdit(loanId, field, value),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              '$prefix$value$suffix',
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

  Widget _statusBadge(String status) {
    Color color;
    IconData? icon;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        icon = Icons.play_circle_filled;
        break;
      case 'settled':
        color = Colors.blueGrey;
        break;
      case 'defaulted':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: icon != null
            ? Icon(icon, size: 14, color: color)
            : Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  Widget _actionsCell(String loanId, ThemeData theme, {bool imported = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<String>(
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
          } else if (!imported && value == 'edit_amount') {
            final loan = context.read<LoanProvider>().loans.firstWhere(
                  (l) => l.id == loanId,
                );
            _startEdit(loanId, 'amount',
                loan.amount.toStringAsFixed(0));
          } else if (!imported && value == 'edit_term') {
            final loan = context.read<LoanProvider>().loans.firstWhere(
                  (l) => l.id == loanId,
                );
            _startEdit(loanId, 'term',
                loan.durationMonths.toString());
          } else if (!imported && value == 'edit_fees') {
            _showFeesDialog(loanId);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'view',
            child: ListTile(
              leading: Icon(Icons.visibility, size: 18),
              title: Text('View Details', style: TextStyle(fontSize: 13)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (!imported) ...[
            const PopupMenuItem(
              value: 'edit_amount',
              child: ListTile(
                leading: Icon(Icons.edit, size: 18),
                title: Text('Edit Amount', style: TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit_term',
              child: ListTile(
                leading: Icon(Icons.edit, size: 18),
                title: Text('Edit Term', style: TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit_fees',
              child: ListTile(
                leading: Icon(Icons.money, size: 18),
                title: Text('Edit Fees', style: TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFeesDialog(String loanId) {
    final loan = context.read<LoanProvider>().loans.firstWhere(
          (l) => l.id == loanId,
        );

    final initCtrl = TextEditingController(
        text: (loan.initiationFee ?? 0).toStringAsFixed(0));
    final adminCtrl = TextEditingController(
        text: (loan.monthlyAdminFee ?? 0).toStringAsFixed(0));
    final penaltyCtrl = TextEditingController(
        text: (loan.penaltyFee ?? 0).toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Fees'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: initCtrl,
              decoration: const InputDecoration(
                labelText: 'Initiation Fee',
                prefixText: 'R ',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: adminCtrl,
              decoration: const InputDecoration(
                labelText: 'Monthly Admin Fee',
                prefixText: 'R ',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: penaltyCtrl,
              decoration: const InputDecoration(
                labelText: 'Penalty Fee',
                prefixText: 'R ',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<LoanProvider>().updateLoan(loanId, {
                'initiation_fee': double.tryParse(initCtrl.text) ?? 0,
                'monthly_admin_fee': double.tryParse(adminCtrl.text) ?? 0,
                'penalty_fee': double.tryParse(penaltyCtrl.text) ?? 0,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HeaderAction({
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
