import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';

/// Displays the payment reminder history for a specific vendor.
/// Designed to be embedded in the vendor profile screen.
class ReminderHistorySection extends StatefulWidget {
  final String vendorId;

  const ReminderHistorySection({super.key, required this.vendorId});

  @override
  State<ReminderHistorySection> createState() => _ReminderHistorySectionState();
}

class _ReminderHistorySectionState extends State<ReminderHistorySection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().fetchVendorHistory(widget.vendorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ReminderProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reminder History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (provider.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.vendorHistory.isEmpty && !provider.isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 32,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'No reminders sent yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          )
        else
          ...provider.vendorHistory.map((log) => _reminderRow(theme, log)),
      ],
    );
  }

  Widget _reminderRow(ThemeData theme, dynamic log) {
    final channel = log.channel ?? '';
    final status = log.status ?? '';
    final type = log.reminderType ?? '';
    final date = log.createdAt != null
        ? '${log.createdAt.day}/${log.createdAt.month}/${log.createdAt.year}'
        : '';
    final isFollowUp = type == 'follow_up';
    final IconData icon;
    final Color iconColor;

    switch (channel) {
      case 'Email':
        icon = Icons.email_outlined;
        iconColor = Colors.blue;
        break;
      case 'WhatsApp':
        icon = Icons.chat_outlined;
        iconColor = Colors.green;
        break;
      case 'SMS':
        icon = Icons.sms_outlined;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      channel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _typeBadge(isFollowUp),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          _statusBadge(status, theme),
        ],
      ),
    );
  }

  Widget _typeBadge(bool isFollowUp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: (isFollowUp ? Colors.red : AppTheme.primaryGold).withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: (isFollowUp ? Colors.red : AppTheme.primaryGold).withOpacity(0.3),
        ),
      ),
      child: Text(
        isFollowUp ? 'Follow-up' : 'Initial',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: isFollowUp ? Colors.red : AppTheme.primaryGold,
        ),
      ),
    );
  }

  Widget _statusBadge(String status, ThemeData theme) {
    final Color color;
    final String label;

    switch (status) {
      case 'sent':
      case 'delivered':
        color = Colors.green;
        label = status[0].toUpperCase() + status.substring(1);
        break;
      case 'failed':
        color = Colors.red;
        label = 'Failed';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }
}
