import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConnectivityStatus>(
      stream: ConnectivityService().statusStream,
      initialData: ConnectivityService().currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isOffline = status == AppConnectivityStatus.offline;
        final pendingActions = OfflineQueueService().queue.length;

        if (!isOffline && pendingActions == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isOffline ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOffline ? Colors.red : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.sync,
                size: 14,
                color: isOffline ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                isOffline 
                  ? 'Offline ($pendingActions pending)' 
                  : 'Syncing $pendingActions actions...',
                style: TextStyle(
                  color: isOffline ? Colors.red : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
