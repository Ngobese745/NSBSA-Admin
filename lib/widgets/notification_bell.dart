import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification.dart';
import 'package:intl/intl.dart';
import '../screens/notification_history_screen.dart';
import '../providers/shell_navigation_provider.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      offset: const Offset(0, 45),
      tooltip: 'Notifications',
      icon: Selector<NotificationProvider, int>(
        selector: (_, p) => p.unreadCount,
        builder: (context, unreadCount, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none, color: Colors.white70, size: 24),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              final unreadCount = notificationProvider.unreadCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: () {
                            context.read<NotificationProvider>().markAllAsRead();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Mark all as read',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  if (notificationProvider.notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: 350,
                      height: 400,
                      child: ListView.separated(
                        itemCount: notificationProvider.notifications.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Colors.white10),
                        itemBuilder: (context, index) {
                          final notification =
                              notificationProvider.notifications[index];
                          return _NotificationTile(notification: notification);
                        },
                      ),
                    ),
                  const Divider(),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dropdown
                        context.read<ShellNavigationProvider>().setSelectedIndex(13);
                      },
                      child: const Text('View All Notifications'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () {
        if (isUnread) {
          context.read<NotificationProvider>().markAsRead(notification.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        color: isUnread ? Colors.white.withOpacity(0.03) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(notification.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                      color: isUnread ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMM d, HH:mm').format(notification.createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
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
    return Icon(icon, color: color, size: 20);
  }
}
