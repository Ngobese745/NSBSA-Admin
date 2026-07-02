import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';
import '../services/realtime_service.dart';

class NotificationProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  Timer? _refreshDebounce;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  NotificationProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'notifications',
      onData: (payload) {
        try {
          final event = payload.eventType;
          if (event == PostgresChangeEvent.insert) {
            final newNotif = NotificationModel.fromJson(payload.newRecord);
            _notifications.insert(0, newNotif);
            // Keep list bounded
            if (_notifications.length > 100) {
              _notifications = _notifications.sublist(0, 100);
            }
            notifyListeners();
          } else if (event == PostgresChangeEvent.update) {
            final updated = NotificationModel.fromJson(payload.newRecord);
            final index = _notifications.indexWhere((n) => n.id == updated.id);
            if (index != -1) {
              _notifications[index] = updated;
              notifyListeners();
            } else {
              // The updated notification wasn't in our visible window
              _scheduleRefresh();
            }
          } else if (event == PostgresChangeEvent.delete) {
            final id = payload.oldRecord['id'];
            final before = _notifications.length;
            _notifications.removeWhere((n) => n.id == id);
            if (_notifications.length != before) notifyListeners();
          }
        } catch (e) {
          debugPrint('Error processing notifications realtime: $e');
        }
      },
    );
  }

  /// Debounced re-fetch for cases where incremental updates aren't sufficient
  /// (e.g., back-fill after a delete that pushed a new notification off-screen).
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 2), fetchNotifications);
  }

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = (response as List)
          .map((e) => NotificationModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          recipientRole: _notifications[index].recipientRole,
          recipientId: _notifications[index].recipientId,
          isRead: true,
          createdAt: _notifications[index].createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);
      fetchNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> sendNotification({
    required String title,
    required String message,
    required String type,
    String? recipientRole,
    String? recipientId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'title': title,
        'message': message,
        'type': type,
        'recipient_role': recipientRole,
        'recipient_id': recipientId,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }
}
