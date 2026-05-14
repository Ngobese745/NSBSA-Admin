import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RealtimeService {
  final _supabase = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};
  
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  void subscribeToTable({
    required String tableName,
    required Function(PostgresChangePayload payload) onData,
  }) {
    if (_channels.containsKey(tableName)) return;

    final channel = _supabase.channel('public:$tableName');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: tableName,
      callback: (payload) {
        debugPrint('Realtime update for $tableName: ${payload.eventType}');
        onData(payload);
      },
    ).subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('Subscribed to $tableName');
      } else if (error != null) {
        debugPrint('Error subscribing to $tableName: $error');
      }
    });

    _channels[tableName] = channel;
  }

  void unsubscribeFromTable(String tableName) {
    _channels[tableName]?.unsubscribe();
    _channels.remove(tableName);
  }

  void dispose() {
    for (var channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }
}
