import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';

/// Compact card for the Admin dashboard showing today's reminder delivery
/// status across Email, WhatsApp, and SMS channels.
class ReminderPreviewPanel extends StatefulWidget {
  const ReminderPreviewPanel({super.key});

  @override
  State<ReminderPreviewPanel> createState() => _ReminderPreviewPanelState();
}

class _ReminderPreviewPanelState extends State<ReminderPreviewPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().fetchDeliveryStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ReminderProvider>();

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
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: AppTheme.primaryGold,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Reminders',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (provider.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (provider.totalSent == 0 && !provider.isLoading)
            _emptyState(theme)
          else ...[
            _channelRow(
              theme,
              'Email',
              Icons.email_outlined,
              provider.deliveryStats['Email_sent'] ?? 0,
              provider.deliveryStats['Email_delivered'] ?? 0,
              provider.deliveryStats['Email_failed'] ?? 0,
            ),
            const SizedBox(height: 10),
            _channelRow(
              theme,
              'WhatsApp',
              Icons.chat_outlined,
              provider.deliveryStats['WhatsApp_sent'] ?? 0,
              provider.deliveryStats['WhatsApp_delivered'] ?? 0,
              provider.deliveryStats['WhatsApp_failed'] ?? 0,
            ),
            const SizedBox(height: 10),
            _channelRow(
              theme,
              'SMS',
              Icons.sms_outlined,
              provider.deliveryStats['SMS_sent'] ?? 0,
              provider.deliveryStats['SMS_delivered'] ?? 0,
              provider.deliveryStats['SMS_failed'] ?? 0,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  'Run Now (08:00)',
                  Icons.play_arrow,
                  provider.isSending,
                  () => provider.triggerInitialReminders(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  'Follow-Up (18:00)',
                  Icons.double_arrow,
                  provider.isSending,
                  () => provider.triggerFollowUpReminders(),
                ),
              ),
            ],
          ),
          if (provider.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              provider.lastError!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: Text(
        'No reminders sent today.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
        ),
      ),
    ),
  );

  Widget _channelRow(
    ThemeData theme,
    String label,
    IconData icon,
    int sent,
    int delivered,
    int failed,
  ) {
    final total = sent + delivered + failed;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.dividerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: theme.textTheme.bodySmall?.color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          )),
        ),
        _statusChip('Sent', sent, Colors.blue, theme),
        const SizedBox(width: 6),
        _statusChip('Delivered', delivered, Colors.green, theme),
        const SizedBox(width: 6),
        _statusChip('Failed', failed, Colors.red, theme),
      ],
    );
  }

  Widget _statusChip(String label, int count, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, bool isSending, VoidCallback onPressed) {
    return SizedBox(
      height: 30,
      child: OutlinedButton.icon(
        onPressed: isSending ? null : onPressed,
        icon: isSending
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
