import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum OfflineActionType {
  create,
  update,
  delete,
}

class OfflineAction {
  final String id;
  final String table;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  OfflineAction({
    required this.id,
    required this.table,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
        id: json['id'],
        table: json['table'],
        type: OfflineActionType.values.byName(json['type']),
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class OfflineQueueService {
  static const String _queueKey = 'offline_action_queue';
  final List<OfflineAction> _queue = [];
  bool _isProcessing = false;

  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? queueJson = prefs.getString(_queueKey);
    if (queueJson != null) {
      final List<dynamic> decoded = jsonDecode(queueJson);
      _queue.addAll(decoded.map((e) => OfflineAction.fromJson(e)));
    }
    debugPrint('OfflineQueue initialized with ${_queue.length} pending actions');
  }

  Future<void> queueAction(OfflineAction action) async {
    _queue.add(action);
    await _persistQueue();
    debugPrint('Action queued: ${action.type} on ${action.table}');
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(_queue.map((e) => e.toJson()).toList()));
  }

  List<OfflineAction> get queue => List.unmodifiable(_queue);

  void removeFromQueue(String id) {
    _queue.removeWhere((a) => a.id == id);
    _persistQueue();
  }

  bool get isProcessing => _isProcessing;
  set isProcessing(bool value) => _isProcessing = value;
}
