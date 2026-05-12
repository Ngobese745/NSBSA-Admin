import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification.dart';
import 'package:intl/intl.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Notifications'),
        actions: [
          if (notificationProvider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => notificationProvider.markAllAsRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all as read'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body:
          notificationProvider.isLoading &&
              notificationProvider.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notificationProvider.notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notificationProvider.notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notification = notificationProvider.notifications[index];
                return _FullNotificationCard(notification: notification);
              },
            ),
    );
  }
}

class _FullNotificationCard extends StatelessWidget {
  final NotificationModel notification;
  const _FullNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Card(
      elevation: isUnread ? 2 : 0,
      color: isUnread ? theme.cardColor : theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUnread
            ? BorderSide(color: theme.primaryColor.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildIcon(notification.type),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy • HH:mm').format(notification.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            notification.message,
            style: TextStyle(
              color: isUnread ? Colors.white : Colors.white60,
              fontSize: 14,
            ),
          ),
        ),
        trailing: isUnread
            ? IconButton(
                icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                onPressed: () => context
                    .read<NotificationProvider>()
                    .markAsRead(notification.id),
                tooltip: 'Mark as read',
              )
            : const Icon(Icons.done, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'SYSTEM':
        icon = Icons.settings_suggest;
        color = Colors.blue;
        break;
      case 'ACTIVITY':
        icon = Icons.person_outline;
        color = Colors.green;
        break;
      case 'FINANCIAL':
        icon = Icons.account_balance_wallet_outlined;
        color = Colors.amber;
        break;
      case 'HIERARCHY':
        icon = Icons.business;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications_none;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
