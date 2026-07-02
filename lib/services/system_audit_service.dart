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
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final performedBy = user?.email ?? 'Unknown User';

      final insert = <String, dynamic>{
        'action_type': actionType,
        'performed_by': performedBy,
        'affected_entity': affectedEntity,
        'description': description,
      };
      if (metadata != null) {
        insert['metadata'] = metadata;
      }

      await _supabase.from('system_audit_log').insert(insert);
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

      return (response as List)
          .map((e) => SystemAuditLogModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('SystemAuditService.fetchLogs error: $e');
      return [];
    }
  }
}
