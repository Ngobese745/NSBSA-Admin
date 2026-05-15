import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/vendor.dart';
import '../../models/group.dart';
import '../../services/communication_service.dart';
import 'package:intl/intl.dart';

class GroupCommunicationDialog extends StatefulWidget {
  final GroupModel? group;
  final List<VendorModel> members;
  final String? customTitle;

  const GroupCommunicationDialog({
    Key? key,
    this.group,
    required this.members,
    this.customTitle,
  }) : super(key: key);

  @override
  _GroupCommunicationDialogState createState() => _GroupCommunicationDialogState();
}

class _GroupCommunicationDialogState extends State<GroupCommunicationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunicationService _commService = CommunicationService();
  
  // Controllers for message inputs
  final TextEditingController _emailSubjectController = TextEditingController();
  final TextEditingController _emailBodyController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();

  bool _isSending = false;
  int _successCount = 0;
  int _failCount = 0;
  String _currentProcessingMember = "";
  late List<VendorModel> _selectedMembers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedMembers = List.from(widget.members);
    
    final contextName = widget.group?.name ?? "NSBSA";
    // Default dynamic placeholders
    _emailSubjectController.text = "Important Update for $contextName members";
    _emailBodyController.text = "Dear member of $contextName,\n\n";
    _whatsappController.text = "Hello NSBSA member, ";
    _smsController.text = "NSBSA: Important update for $contextName members: ";
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailSubjectController.dispose();
    _emailBodyController.dispose();
    _whatsappController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _sendBulkEmail() async {
    if (_emailSubjectController.text.isEmpty || _emailBodyController.text.isEmpty) return;
    if (_selectedMembers.isEmpty) return;
    
    setState(() {
      _isSending = true;
      _successCount = 0;
      _failCount = 0;
    });

    for (var member in _selectedMembers) {
      if (member.email != null && member.email!.isNotEmpty) {
        setState(() => _currentProcessingMember = member.name);
        final success = await _commService.sendManualEmail(
          vendorId: member.id,
          toEmail: member.email!,
          subject: _emailSubjectController.text,
          content: _emailBodyController.text,
        );
        if (success) _successCount++; else _failCount++;
      } else {
        _failCount++;
      }
    }

    _handleBulkResult("Emails processed");
  }

  Future<void> _sendBulkWhatsApp() async {
    if (_whatsappController.text.isEmpty) return;
    if (_selectedMembers.isEmpty) return;
    
    setState(() {
      _isSending = true;
      _successCount = 0;
      _failCount = 0;
    });

    for (var member in _selectedMembers) {
      final number = member.whatsappNumber ?? member.phone;
      if (number != null && number.isNotEmpty) {
        setState(() => _currentProcessingMember = member.name);
        final success = await _commService.sendManualWhatsApp(
          vendorId: member.id,
          toWhatsApp: number,
          content: _whatsappController.text,
        );
        if (success) _successCount++; else _failCount++;
      } else {
        _failCount++;
      }
    }

    _handleBulkResult("WhatsApp messages processed");
  }

  Future<void> _sendBulkSMS() async {
    if (_smsController.text.isEmpty) return;
    if (_selectedMembers.isEmpty) return;
    
    setState(() {
      _isSending = true;
      _successCount = 0;
      _failCount = 0;
    });

    for (var member in _selectedMembers) {
      if (member.phone != null && member.phone!.isNotEmpty) {
        setState(() => _currentProcessingMember = member.name);
        final success = await _commService.sendManualSMS(
          vendorId: member.id,
          toPhone: member.phone!,
          content: _smsController.text,
        );
        if (success) _successCount++; else _failCount++;
      } else {
        _failCount++;
      }
    }

    _handleBulkResult("SMS messages processed");
  }

  void _handleBulkResult(String operation) {
    if (mounted) {
      setState(() => _isSending = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0D1117),
          title: Text("Bulk Processing Complete", style: GoogleFonts.outfit(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildResultRow("Successfully Sent", _successCount, Colors.green),
              const SizedBox(height: 12),
              _buildResultRow("Failed/Skipped", _failCount, Colors.red),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Color(0xFFD4AF37))),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[400])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = const Color(0xFFD4AF37);

    return Dialog(
      backgroundColor: const Color(0xFF0D1117),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: goldColor.withOpacity(0.3), width: 1),
      ),
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: goldColor.withOpacity(0.1),
                  child: Icon(Icons.groups_rounded, color: goldColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customTitle ?? 'Group Announcement',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Sending to ${_selectedMembers.length} members${widget.group != null ? ' of ${widget.group!.name}' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMemberSelector(goldColor),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isSending) 
              _buildProcessingState(goldColor, _selectedMembers.length)
            else ...[
              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: goldColor,
                  labelColor: goldColor,
                  unselectedLabelColor: Colors.grey,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: goldColor.withOpacity(0.05),
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.email_outlined), text: 'Group Email'),
                    Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Group WhatsApp'),
                    Tab(icon: Icon(Icons.sms_outlined), text: 'Group SMS'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEmailTab(theme, goldColor),
                    _buildWhatsAppTab(theme, goldColor),
                    _buildSMSTab(theme, goldColor),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSelector(Color goldColor) {
    return PopupMenuButton<void>(
      tooltip: "Select Recipients",
      offset: const Offset(0, 40),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: goldColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: goldColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 16, color: goldColor),
            const SizedBox(width: 8),
            Text(
              _selectedMembers.length == widget.members.length
                  ? "All Members"
                  : "${_selectedMembers.length} Selected",
              style: GoogleFonts.inter(
                color: goldColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setPopupState) => SizedBox(
                  width: 250,
                  height: 300,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recipient List",
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (_selectedMembers.length == widget.members.length) {
                                    _selectedMembers.clear();
                                  } else {
                                    _selectedMembers = List.from(widget.members);
                                  }
                                });
                                setPopupState(() {});
                              },
                              child: Text(
                                _selectedMembers.length == widget.members.length
                                    ? "Deselect All"
                                    : "Select All",
                                style: TextStyle(color: goldColor, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.members.length,
                          itemBuilder: (context, index) {
                            final member = widget.members[index];
                            final isSelected = _selectedMembers.any((m) => m.id == member.id);
                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              title: Text(
                                member.name,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              activeColor: goldColor,
                              checkColor: Colors.black,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedMembers.add(member);
                                  } else {
                                    _selectedMembers.removeWhere((m) => m.id == member.id);
                                  }
                                });
                                setPopupState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState(Color goldColor, int totalCount) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD4AF37)),
            const SizedBox(height: 24),
            Text(
              "Processing Bulk Messages...",
              style: GoogleFonts.outfit(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Currently sending to: $_currentProcessingMember",
              style: GoogleFonts.inter(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildResultRow("Completed", _successCount + _failCount, goldColor),
                  const SizedBox(height: 8),
                  _buildResultRow("Remaining", totalCount - (_successCount + _failCount), Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTab(ThemeData theme, Color goldColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _emailSubjectController,
          label: "Subject",
          hint: "Enter email subject",
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildTextField(
            controller: _emailBodyController,
            label: "Message Content",
            hint: "Write your announcement...",
            maxLines: 10,
          ),
        ),
        const SizedBox(height: 16),
        _buildSendButton(_sendBulkEmail, "Send Bulk Branded Email", Icons.email_rounded, goldColor),
      ],
    );
  }

  Widget _buildWhatsAppTab(ThemeData theme, Color goldColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            controller: _whatsappController,
            label: "WhatsApp Message",
            hint: "Type your announcement...",
            maxLines: 8,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoBox("Messages will include the NSBSA contact footer automatically."),
        const SizedBox(height: 16),
        _buildSendButton(_sendBulkWhatsApp, "Send Bulk WhatsApp", Icons.chat_bubble_rounded, goldColor),
      ],
    );
  }

  Widget _buildSMSTab(ThemeData theme, Color goldColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            controller: _smsController,
            label: "SMS Message",
            hint: "Keep it concise (max 160 chars recommended)...",
            maxLines: 5,
            maxLength: 160,
          ),
        ),
        const SizedBox(height: 16),
        _buildSendButton(_sendBulkSMS, "Send Bulk SMS", Icons.sms_rounded, goldColor),
      ],
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[300], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: Colors.blue[100], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[700]),
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4AF37)),
            ),
            counterStyle: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(VoidCallback onPressed, String label, IconData icon, Color goldColor) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: goldColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: goldColor.withOpacity(0.4),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
