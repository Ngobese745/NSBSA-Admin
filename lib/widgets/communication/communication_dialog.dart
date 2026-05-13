import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/vendor.dart';
import '../../services/communication_service.dart';
import 'package:intl/intl.dart';

class CommunicationDialog extends StatefulWidget {
  final VendorModel vendor;

  const CommunicationDialog({Key? key, required this.vendor}) : super(key: key);

  @override
  _CommunicationDialogState createState() => _CommunicationDialogState();
}

class _CommunicationDialogState extends State<CommunicationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CommunicationService _commService = CommunicationService();
  
  // Controllers for message inputs
  final TextEditingController _emailSubjectController = TextEditingController();
  final TextEditingController _emailBodyController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();

  bool _isSending = false;
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchHistory();
    
    // Default dynamic placeholders for email
    _emailSubjectController.text = "Important Update from NSBSA";
    _emailBodyController.text = "Dear ${widget.vendor.name},\n\n";
    _whatsappController.text = "Hello ${widget.vendor.name}, ";
    _smsController.text = "NSBSA: Hello ${widget.vendor.name}, ";
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _commService.fetchCommunicationHistory(widget.vendor.id);
    if (mounted) {
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    }
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

  Future<void> _sendEmail() async {
    if (_emailSubjectController.text.isEmpty || _emailBodyController.text.isEmpty) return;
    setState(() => _isSending = true);
    final success = await _commService.sendManualEmail(
      vendorId: widget.vendor.id,
      toEmail: widget.vendor.email ?? '',
      subject: _emailSubjectController.text,
      content: _emailBodyController.text,
    );
    _handleResult(success, "Email queued successfully");
  }

  Future<void> _sendWhatsApp() async {
    if (_whatsappController.text.isEmpty) return;
    setState(() => _isSending = true);
    final success = await _commService.sendManualWhatsApp(
      vendorId: widget.vendor.id,
      toWhatsApp: widget.vendor.whatsappNumber ?? widget.vendor.phone ?? '',
      content: _whatsappController.text,
    );
    _handleResult(success, "WhatsApp sent successfully");
  }

  Future<void> _sendSMS() async {
    if (_smsController.text.isEmpty) return;
    setState(() => _isSending = true);
    final success = await _commService.sendManualSMS(
      vendorId: widget.vendor.id,
      toPhone: widget.vendor.phone ?? '',
      content: _smsController.text,
    );
    _handleResult(success, "SMS sent successfully");
  }

  void _handleResult(bool success, String message) {
    if (mounted) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? message : "Failed to send message"),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        _fetchHistory();
        // Clear inputs based on current tab? 
        // For now keep them or clear specific ones.
      }
    }
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
                  child: Icon(Icons.send_rounded, color: goldColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Communication Channels',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Messaging: ${widget.vendor.name}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                  Tab(icon: Icon(Icons.email_outlined), text: 'Email'),
                  Tab(icon: Icon(Icons.chat_bubble_outline), text: 'WhatsApp'),
                  Tab(icon: Icon(Icons.sms_outlined), text: 'SMS'),
                  Tab(icon: Icon(Icons.history_rounded), text: 'History'),
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
                  _buildHistoryTab(theme, goldColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTab(ThemeData theme, Color goldColor) {
    if (widget.vendor.email == null || widget.vendor.email!.isEmpty) {
      return _buildNoContactInfo("Email address not found for this vendor.");
    }
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
            hint: "Write your branded email message...",
            maxLines: 10,
          ),
        ),
        const SizedBox(height: 16),
        _buildSendButton(_sendEmail, "Send Branded Email", Icons.email_rounded, goldColor),
      ],
    );
  }

  Widget _buildWhatsAppTab(ThemeData theme, Color goldColor) {
    final number = widget.vendor.whatsappNumber ?? widget.vendor.phone;
    if (number == null || number.isEmpty) {
      return _buildNoContactInfo("WhatsApp/Phone number not found for this vendor.");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sending to: $number",
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildTextField(
            controller: _whatsappController,
            label: "WhatsApp Message",
            hint: "Type your WhatsApp message...",
            maxLines: 8,
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
                  "Messages will include a 'No Reply' disclaimer automatically.",
                  style: GoogleFonts.inter(color: Colors.blue[100], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSendButton(_sendWhatsApp, "Send WhatsApp", Icons.chat_bubble_rounded, goldColor),
      ],
    );
  }

  Widget _buildSMSTab(ThemeData theme, Color goldColor) {
    if (widget.vendor.phone == null || widget.vendor.phone!.isEmpty) {
      return _buildNoContactInfo("Phone number not found for this vendor.");
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sending to: ${widget.vendor.phone}",
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildTextField(
            controller: _smsController,
            label: "SMS Message",
            hint: "Max 160 characters for best results...",
            maxLines: 5,
            maxLength: 160,
          ),
        ),
        const SizedBox(height: 16),
        _buildSendButton(_sendSMS, "Send Branded SMS", Icons.sms_rounded, goldColor),
      ],
    );
  }

  Widget _buildHistoryTab(ThemeData theme, Color goldColor) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              "No communication history found.",
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final log = _history[index];
        final channel = log['channel'];
        final status = log['status'];
        final date = DateTime.parse(log['created_at']);
        
        IconData channelIcon;
        Color channelColor;
        switch(channel) {
          case 'Email': channelIcon = Icons.email_outlined; channelColor = Colors.blue; break;
          case 'WhatsApp': channelIcon = Icons.chat_bubble_outline; channelColor = Colors.green; break;
          default: channelIcon = Icons.sms_outlined; channelColor = goldColor;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMessageDetailsDialog(log, goldColor),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(channelIcon, size: 14, color: channelColor),
                        const SizedBox(width: 8),
                        Text(
                          channel,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: channelColor,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (log['subject'] != null && log['subject'].toString().isNotEmpty)
                      Text(
                        log['subject'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        log['content'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM dd, yyyy • HH:mm').format(date),
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessageDetailsDialog(Map<String, dynamic> log, Color goldColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: goldColor.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.message_rounded, color: goldColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                log['subject'] ?? 'Message Details',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text(
              log['content'] ?? '',
              style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 14, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: goldColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    switch(status.toLowerCase()) {
      case 'sent': color = Colors.green; icon = Icons.check_circle_outline; break;
      case 'failed': color = Colors.red; icon = Icons.error_outline; break;
      default: color = Colors.orange; icon = Icons.access_time;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
            fillColor: const Color(0xFF0D1117),
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
        icon: _isSending 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Icon(icon, size: 20),
        label: Text(
          _isSending ? "Processing..." : label,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildNoContactInfo(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_support_outlined, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
