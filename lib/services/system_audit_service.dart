import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_audit_log_model.dart';

class SystemAuditService {
  static final _supabase = Supabase.instance.client;

  /// Logs a system action to the `system_audit_log` table.
  /// Fire and forget. Errors are caught and printed to debug console to prevent disrupting workflows.
  static Future<void> logAction({
    required String actionType,
    required String affectedEntity,
    required String description,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final performedBy = user?.email ?? 'Unknown User';

      await _supabase.from('system_audit_log').insert({
        'action_type': actionType,
        'performed_by': performedBy,
        'affected_entity': affectedEntity,
        'description': description,
        // timestamp is handled by the database default (now())
      });
    } catch (e) {
      debugPrint('SystemAuditService.logAction error: $e');
    }
  }

  /// Fetches recent logs from the `system_audit_log` table, ordered by timestamp descending.
  static Future<List<SystemAuditLogModel>> fetchLogs({int limit = 200}) async {
    try {
      final response = await _supabase
          .from('system_audit_log')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List).map((e) => SystemAuditLogModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('SystemAuditService.fetchLogs error: $e');
      return [];
    }
  }
}
