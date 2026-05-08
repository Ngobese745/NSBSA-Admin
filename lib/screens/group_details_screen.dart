import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/group.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../providers/vendor_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/group_provider.dart';
import 'vendor_profile_screen.dart';
import 'loan_details_screen.dart';
import '../services/loan_calculation_service.dart';

class GroupDetailsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<VendorModel> _members = [];
  List<LoanModel> _loans = [];
  bool _isLoading = true;
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.group.name;
    _loadData();
  }

  Future<void> _loadData() async {
    final vendorProvider = context.read<VendorProvider>();
    final loanProvider = context.read<LoanProvider>();

    final results = await Future.wait([
      vendorProvider.fetchVendorsByGroup(widget.group.id),
      loanProvider.fetchLoansByGroup(widget.group.id),
    ]);

    if (mounted) {
      setState(() {
        _members = results[0] as List<VendorModel>;
        _loans = results[1] as List<LoanModel>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 32),
                  _buildSummarySection(theme),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildMembersList(theme)),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: _buildLoansList(theme)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.primaryColor.withOpacity(0.2),
            child: Icon(Icons.group, size: 32, color: theme.primaryColor),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _currentName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                    onPressed: _showEditDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    onPressed: _confirmDeleteGroup,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Reference: ${widget.group.referenceNumber}',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Created On', style: TextStyle(color: Colors.grey[600])),
              Text(
                widget.group.createdAt.toString().substring(0, 10),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _downloadGroupStatement,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Download Statement'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme) {
    double totalLoaned = _loans.fold(0, (sum, item) => sum + item.amount);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Members',
            _members.length.toString(),
            Icons.people,
            theme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Loans',
            _loans.length.toString(),
            Icons.account_balance,
            Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Value',
            'R ${totalLoaned.toStringAsFixed(0)}',
            Icons.payments,
            Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Group Members',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddMemberDialog,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Member'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = _members[index];
              return ListTile(
                title: Text(member.name),
                subtitle: Text(member.phone ?? 'No Phone'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendorProfileScreen(vendor: member),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () => _showEditMemberDialog(member),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _showDeleteMemberConfirm(member),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoansList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Group Loans',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddLoanDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Loan'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: _loans.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No loans found for this group.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _loans.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final loan = _loans[index];
                    return ListTile(
                      title: Text('Loan R ${loan.amount}'),
                      subtitle: Text(
                        'Status: ${loan.status} • Term: ${loan.durationMonths} Months',
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoanDetailsScreen(loan: loan),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'R ${loan.monthlyPayment}/mo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.payment,
                              size: 20,
                              color: Colors.greenAccent,
                            ),
                            onPressed: () => _showRecordPaymentDialog(loan),
                            tooltip: 'Record Payment',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Edit Group Name',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          decoration: const InputDecoration(
            labelText: 'Group Name',
            labelStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await context.read<GroupProvider>().updateGroup(
                  widget.group.id,
                  controller.text,
                );
                setState(() {
                  _currentName = controller.text;
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(VendorModel member) {
    final nameController = TextEditingController(text: member.name);
    final phoneController = TextEditingController(text: member.phone);
    final idController = TextEditingController(text: member.idNumber);
    final businessController = TextEditingController(text: member.businessType);
    final dfController = TextEditingController(text: member.dfName);
    final whatsappController = TextEditingController(
      text: member.whatsappNumber,
    );
    String selectedGender = member.gender ?? 'F';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Edit Member',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: idController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ID Number',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('M')),
                    DropdownMenuItem(value: 'F', child: Text('F')),
                  ],
                  onChanged: (val) => setState(() => selectedGender = val!),
                ),
                TextField(
                  controller: phoneController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: whatsappController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: businessController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Business Type',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: dfController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'DF Name',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await context.read<VendorProvider>().updateVendor(member.id, {
                      'name': nameController.text,
                      'phone': phoneController.text,
                      'id_number': idController.text,
                      'gender': selectedGender,
                      'business_type': businessController.text,
                      'df_name': dfController.text,
                      'whatsapp_number': whatsappController.text,
                    });
                    
                    // Optimistic update
                    final index = _members.indexWhere((m) => m.id == member.id);
                    if (index != -1) {
                      this.setState(() {
                        _members[index] = VendorModel(
                          id: member.id,
                          groupId: member.groupId,
                          name: nameController.text,
                          phone: phoneController.text,
                          idNumber: idController.text,
                          gender: selectedGender,
                          businessType: businessController.text,
                          dfName: dfController.text,
                          whatsappNumber: whatsappController.text,
                          referenceNumber: member.referenceNumber,
                          createdAt: member.createdAt,
                        );
                      });
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member updated successfully')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLoanDialog() {
    final amountController = TextEditingController();
    final termController = TextEditingController(text: '6');
    final monthlyController = TextEditingController();

    String? selectedVendorId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Create New Loan',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedVendorId,
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: const InputDecoration(
                  labelText: 'Select Member',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: _members.map((member) {
                  return DropdownMenuItem(
                    value: member.id,
                    child: Text(member.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedVendorId = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: const InputDecoration(
                  labelText: 'Loan Amount (R)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateMonthly(
                  setState,
                  amountController,
                  termController,
                  monthlyController,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: termController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: const InputDecoration(
                  labelText: 'Duration (Months)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateMonthly(
                  setState,
                  amountController,
                  termController,
                  monthlyController,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: monthlyController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                decoration: InputDecoration(
                  labelText: 'Monthly Payment (R)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  helperText: 'Auto-calculated: (Amount/Term) + Fees',
                  helperStyle: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 10,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                final term = int.tryParse(termController.text) ?? 6;
                final monthly = double.tryParse(monthlyController.text) ?? 0;

                if (amount > 0 && selectedVendorId != null) {
                  setState(() => amountController.text = 'Submitting...'); // basic loading state
                  try {
                    final newLoan = await context.read<LoanProvider>().addLoan(
                      LoanModel(
                        id: '', // Empty ID will be ignored by toJson now
                        groupId: widget.group.id,
                        vendorId: selectedVendorId,
                        amount: amount,
                        durationMonths: term,
                        monthlyPayment: monthly,
                        initiationFee: 150, // Default based on document
                        monthlyAdminFee: 65, // Default based on document
                        penaltyFee: 59, // Default based on document
                        status: 'Active',
                        createdAt: DateTime.now(),
                      ),
                    );
                    
                    // Optimistic update
                    this.setState(() {
                      _loans.insert(0, newLoan);
                    });
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan created successfully')));
                    }
                  } catch (e) {
                    setState(() => amountController.text = amount.toString()); // revert
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } else if (selectedVendorId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a member first'),
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _calculateMonthly(
    StateSetter setState,
    TextEditingController amountController,
    TextEditingController termController,
    TextEditingController monthlyController,
  ) {
    final amount = double.tryParse(amountController.text) ?? 0;
    final term = int.tryParse(termController.text) ?? 0;

    if (amount > 0 && term > 0) {
      // Formula based on NSBSA standard:
      // Monthly = (Principal / Term) + Admin Fee (65) + Penalty Fee (59) + (Initiation Fee (150) / Term)
      const initiationFee = 150.0;
      const adminFee = 65.0;
      const penaltyFee = 59.0;

      final monthly =
          (amount / term) + adminFee + penaltyFee + (initiationFee / term);

      setState(() {
        monthlyController.text = monthly.toStringAsFixed(0);
      });
    }
  }

  void _showRecordPaymentDialog(LoanModel loan) {
    final amountController = TextEditingController(
      text: loan.monthlyPayment.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Record Payment',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recording payment for Loan R ${loan.amount}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount Paid (R)',
                labelStyle: TextStyle(color: Colors.grey),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                try {
                  await context.read<PaymentProvider>().addPayment(
                    PaymentModel(
                      id: '',
                      loanId: loan.id,
                      amountPaid: amount,
                      datePaid: DateTime.now(),
                      createdAt: DateTime.now(),
                    ),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment recorded successfully!'),
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final idController = TextEditingController();
    final businessController = TextEditingController();
    final dfController = TextEditingController();
    final whatsappController = TextEditingController();
    String selectedGender = 'F';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text(
            'Add New Member',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  onChanged: (val) {
                    // Auto-fill WhatsApp if empty
                    if (whatsappController.text.isEmpty) {
                      // Logic handled by controllers or user manually
                    }
                  },
                ),
                TextField(
                  controller: idController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'ID Number',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('M')),
                    DropdownMenuItem(value: 'F', child: Text('F')),
                  ],
                  onChanged: (val) => setState(() => selectedGender = val!),
                ),
                TextField(
                  controller: phoneController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (val) {
                    if (whatsappController.text.isEmpty) {
                      whatsappController.text = val;
                    }
                  },
                ),
                TextField(
                  controller: whatsappController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: businessController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Business Type',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: dfController,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'DF Name',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;

                final vendorProvider = context.read<VendorProvider>();

                // --- Duplicate check ---
                final duplicate = await vendorProvider.checkDuplicateVendor(
                  idNumber: idController.text,
                  phone: phoneController.text,
                );

                if (duplicate != null && context.mounted) {
                  final idMatch =
                      idController.text.trim().isNotEmpty &&
                      duplicate.idNumber?.trim() == idController.text.trim();
                  final matchField = idMatch ? 'ID Number' : 'Phone Number';
                  final matchValue = idMatch
                      ? (duplicate.idNumber ?? '')
                      : (duplicate.phone ?? '');

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Row(
                        children: const [
                          Icon(Icons.block, color: Colors.redAccent, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Duplicate Member Detected',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'A member with this information already exists in the system.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dupRow(
                                  Icons.person,
                                  'Existing Member',
                                  duplicate.name,
                                ),
                                const SizedBox(height: 6),
                                _dupRow(
                                  Icons.badge_outlined,
                                  matchField,
                                  matchValue,
                                ),
                                const SizedBox(height: 6),
                                _dupRow(
                                  Icons.phone_outlined,
                                  'Phone',
                                  duplicate.phone ?? 'N/A',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Please verify the details or search for the existing member instead.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A2A2A),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK, Go Back'),
                        ),
                      ],
                    ),
                  );
                  return; // Block the insert
                }

                // --- No duplicate — proceed with insert ---
                await vendorProvider.addVendor(
                  VendorModel(
                    id: '',
                    groupId: widget.group.id,
                    name: nameController.text,
                    phone: phoneController.text,
                    idNumber: idController.text,
                    gender: selectedGender,
                    businessType: businessController.text,
                    dfName: dfController.text,
                    whatsappNumber: whatsappController.text,
                    referenceNumber: widget.group.name
                        .substring(0, 3)
                        .toUpperCase(),
                    createdAt: DateTime.now(),
                  ),
                );
                _loadData();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteMemberConfirm(VendorModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Delete Member',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove ${member.name} from this group?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<VendorProvider>().deleteVendor(member.id);
              _loadData();
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadGroupStatement() async {
    try {
      final paymentProvider = context.read<PaymentProvider>();
      final allPayments = paymentProvider.payments;
      final loanIds = _loans.map((loan) => loan.id).toSet();
      final groupPayments = allPayments
          .where((payment) => loanIds.contains(payment.loanId))
          .toList();
      double totalLiability = 0;
      for (final loan in _loans) {
        final loanPayments = groupPayments.where((p) => p.loanId == loan.id).toList();
        totalLiability += loan.amount + 
                         (loan.initiationFee ?? 0) + 
                         ((loan.monthlyAdminFee ?? 0) * loan.durationMonths) + 
                         LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);
      }
      final totalPaid = groupPayments.fold<double>(0, (sum, p) => sum + p.amountPaid);
      final balance = totalLiability - totalPaid;

      final logoBytes = await rootBundle.load(
        'assets/images/NSBSA Logo (1).png',
      );
      final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      final pdf = pw.Document();
      final generatedDate = _formatDate(DateTime.now());

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
                    'Group Statement Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Reference: ${widget.group.referenceNumber}'),
                  pw.Text('Date: $generatedDate'),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          build: (_) {
            final sortedPayments = [...groupPayments]
              ..sort((a, b) => b.datePaid.compareTo(a.datePaid));

            return [
              pw.SizedBox(height: 20),
              pw.Text(
                'Group Information',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoRow('Group Name', widget.group.name),
                        _pdfInfoRow('Reference', widget.group.referenceNumber),
                        _pdfInfoRow(
                          'Created On',
                          _formatDate(widget.group.createdAt),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfInfoRow(
                          'Total Members',
                          _members.length.toString(),
                        ),
                        _pdfInfoRow('Total Loans', _loans.length.toString()),
                        _pdfInfoRow('Generated On', generatedDate),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Financial Summary',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfStatItem('Total Liability', _formatCurrency(totalLiability)),
                  _pdfStatItem('Total Paid', _formatCurrency(totalPaid)),
                  _pdfStatItem('Outstanding', _formatCurrency(balance)),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Group Members',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _members.isEmpty
                  ? pw.Text(
                      'No members found.',
                      style: const pw.TextStyle(color: PdfColors.grey),
                    )
                  : pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey100,
                          ),
                          children: [
                            _pdfCell('Name', isBold: true),
                            _pdfCell('Phone', isBold: true),
                            _pdfCell('Business', isBold: true),
                          ],
                        ),
                        ..._members.map(
                          (member) => pw.TableRow(
                            children: [
                              _pdfCell(member.name),
                              _pdfCell(member.phone ?? '-'),
                              _pdfCell(member.businessType ?? '-'),
                            ],
                          ),
                        ),
                      ],
                    ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Loan History',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              _loans.isEmpty
                  ? pw.Text(
                      'No loans found.',
                      style: const pw.TextStyle(color: PdfColors.grey),
                    )
                  : pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey100,
                          ),
                          children: [
                            _pdfCell('Member', isBold: true),
                            _pdfCell('Amount', isBold: true),
                            _pdfCell('Duration', isBold: true),
                            _pdfCell('Monthly', isBold: true),
                            _pdfCell('Status', isBold: true),
                          ],
                        ),
                        ..._loans.map(
                          (loan) => pw.TableRow(
                            children: [
                              _pdfCell(_memberNameById(loan.vendorId)),
                              _pdfCell('R ${loan.amount.toStringAsFixed(0)}'),
                              _pdfCell('${loan.durationMonths} Months'),
                              _pdfCell(
                                'R ${loan.monthlyPayment.toStringAsFixed(0)}',
                              ),
                              _pdfCell(loan.status),
                            ],
                          ),
                        ),
                      ],
                    ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Payment History',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              sortedPayments.isEmpty
                  ? pw.Text(
                      'No payment history found.',
                      style: const pw.TextStyle(color: PdfColors.grey),
                    )
                  : pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey100,
                          ),
                          children: [
                            _pdfCell('Date', isBold: true),
                            _pdfCell('Amount', isBold: true),
                            _pdfCell('Method', isBold: true),
                            _pdfCell('Loan', isBold: true),
                          ],
                        ),
                        ...sortedPayments.map(
                          (payment) => pw.TableRow(
                            children: [
                              _pdfCell(_formatDate(payment.datePaid)),
                              _pdfCell(_formatCurrency(payment.amountPaid)),
                              _pdfCell(payment.paymentMethod ?? 'Manual'),
                              _pdfCell(_loanLabelById(payment.loanId)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ];
          },
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              '-- ${context.pageNumber} of ${context.pagesCount} --',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name:
            'Group_Statement_${widget.group.referenceNumber}_${DateTime.now().toString().substring(0, 10)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate statement: $e')),
      );
    }
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.SizedBox(
              width: 84,
              child: pw.Text(
                '$label:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _pdfStatItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _pdfCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _memberNameById(String? vendorId) {
    if (vendorId == null) return 'Unknown';
    for (final member in _members) {
      if (member.id == vendorId) return member.name;
    }
    return 'Unknown';
  }

  String _loanLabelById(String loanId) {
    for (final loan in _loans) {
      if (loan.id == loanId) {
        return 'R ${loan.amount.toStringAsFixed(0)}';
      }
    }
    return '-';
  }

  String _formatCurrency(double amount) => 'R ${amount.toStringAsFixed(2)}';

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Helper widget used inside the duplicate-detection alert dialog.
  Widget _dupRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.redAccent),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete the group "$_currentName"? This will permanently remove the group record.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final groupId = widget.group.id;
              await context.read<GroupProvider>().deleteGroup(groupId);
              
              if (context.mounted) {
                // Refresh all providers to remove orphaned records (due to cascade delete)
                await Future.wait<void>([
                  context.read<LoanProvider>().fetchLoans(forceRefresh: true),
                  context.read<VendorProvider>().fetchVendors(forceRefresh: true),
                  context.read<PaymentProvider>().fetchPayments(forceRefresh: true),
                ]);

                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to groups screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group "$_currentName" and all associated data deleted')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
