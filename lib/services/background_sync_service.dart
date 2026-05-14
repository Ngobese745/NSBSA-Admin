import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';
import 'package:flutter/foundation.dart';

class BackgroundSyncService {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _connectivitySub;

  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  void init() {
    _connectivitySub = ConnectivityService().statusStream.listen((status) {
      if (status == AppConnectivityStatus.online) {
        _processQueue();
      }
    });
  }

  Future<void> _processQueue() async {
    final queueService = OfflineQueueService();
    if (queueService.isProcessing || queueService.queue.isEmpty) return;

    queueService.isProcessing = true;
    debugPrint('Starting background sync for ${queueService.queue.length} actions');

    final pendingActions = List<OfflineAction>.from(queueService.queue);
    
    for (var action in pendingActions) {
      try {
        switch (action.type) {
          case OfflineActionType.create:
            await _supabase.from(action.table).insert(action.data);
            break;
          case OfflineActionType.update:
            final id = action.data['id'];
            final updates = Map<String, dynamic>.from(action.data)..remove('id');
            await _supabase.from(action.table).update(updates).eq('id', id);
            break;
          case OfflineActionType.delete:
            final id = action.data['id'];
            await _supabase.from(action.table).delete().eq('id', id);
            break;
        }
        queueService.removeFromQueue(action.id);
        debugPrint('Synced offline action: ${action.type} on ${action.table}');
      } catch (e) {
        debugPrint('Failed to sync action ${action.id}: $e');
        // Stop processing on first error to maintain sequence if needed
        // Or continue? Usually for financial data, sequence matters.
        break; 
      }
    }

    queueService.isProcessing = false;
    debugPrint('Background sync completed. Pending: ${queueService.queue.length}');
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
