import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;

  static Future<void> notify({
    required String title,
    required String message,
    required String type, // SYSTEM, ACTIVITY, FINANCIAL, HIERARCHY
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
      // We don't want to break the main app flow if notifications fail
      print('Silent Error: Failed to send notification: $e');
    }
  }

  // Helper methods for common system notifications

  static Future<void> notifySuperAdmin(
    String title,
    String message, {
    String type = 'SYSTEM',
  }) async {
    await notify(
      title: title,
      message: message,
      type: type,
      recipientRole: 'SUPER_ADMIN',
    );
  }

  static Future<void> notifyAdmins(
    String title,
    String message, {
    String type = 'ACTIVITY',
  }) async {
    await notify(
      title: title,
      message: message,
      type: type,
      recipientRole: 'ADMIN',
    );
  }

  static Future<void> notifyAll(
    String title,
    String message, {
    String type = 'SYSTEM',
  }) async {
    await notify(
      title: title,
      message: message,
      type: type,
      recipientRole: 'ALL',
    );
  }
}
