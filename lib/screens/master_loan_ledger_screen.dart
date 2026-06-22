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
      case 'openingAmount':
        updates = {'opening_amount': double.tryParse(raw) ?? 0};
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
                        6: FlexColumnWidth(1.8),   // Opening Balance
                        7: FlexColumnWidth(1.8),   // Total Paid
                        8: FlexColumnWidth(1.5),   // Monthly
                        9: FlexColumnWidth(1.2),   // Status
                        10: FlexColumnWidth(0.8),  // Actions
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
                            _th('Opening Balance'),
                            _th('Total Paid'),
                            _th('Monthly'),
                            _th('Status'),
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
    final balance = loan.openingAmount ?? 0.0;

    return TableRow(
      children: [
        _td(loan.vendorName ?? vendor?.name ?? '—'),
        _td(vendor?.idNumber ?? '—'),
        _td(vendor?.phone ?? '—'),
        _td(group?.name ?? '—'),
        _editableTd(loan.id, 'amount',
            loan.amount.toStringAsFixed(0), prefix: 'R '),
        _editableTd(
            loan.id, 'term', loan.durationMonths.toString(), suffix: 'm'),
        _editableTd(loan.id, 'openingAmount',
            balance.toStringAsFixed(0), prefix: 'R '),
        _td('R ${totalPaid.toStringAsFixed(0)}', color: Colors.green),
        _editableTd(loan.id, 'monthlyPayment',
            loan.monthlyPayment.toStringAsFixed(0), prefix: 'R '),
        _statusBadge(loan.status),
        _actionsCell(loan.id, theme),
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

  Widget _td(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
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
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
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
        child: Text(
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

  Widget _actionsCell(String loanId, ThemeData theme) {
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
          } else if (value == 'edit_amount') {
            final loan = context.read<LoanProvider>().loans.firstWhere(
                  (l) => l.id == loanId,
                );
            _startEdit(loanId, 'amount',
                loan.amount.toStringAsFixed(0));
          } else if (value == 'edit_term') {
            final loan = context.read<LoanProvider>().loans.firstWhere(
                  (l) => l.id == loanId,
                );
            _startEdit(loanId, 'term',
                loan.durationMonths.toString());
          } else if (value == 'edit_opening') {
            final loan = context.read<LoanProvider>().loans.firstWhere(
                  (l) => l.id == loanId,
                );
            _startEdit(loanId, 'openingAmount',
                (loan.openingAmount ?? 0).toStringAsFixed(0));
          } else if (value == 'edit_fees') {
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
            value: 'edit_opening',
            child: ListTile(
              leading: Icon(Icons.edit, size: 18),
              title: Text('Edit Opening Balance',
                  style: TextStyle(fontSize: 13)),
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
