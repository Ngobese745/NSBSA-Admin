import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/system_audit_service.dart';
import '../services/smsworx_service.dart';
import '../services/wesender_service.dart';
import '../services/idrive_e2_service.dart';

class ApiManagementProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _keys = [];
  List<Map<String, dynamic>> get keys => _keys;

  Future<void> fetchKeys() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase
          .from('api_keys')
          .select()
          .order('service_name', ascending: true);
      _keys = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching API keys: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveKey({
    required String serviceName,
    required String label,
    required String apiKey,
    required String userId,
    required String userEmail,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // First, deactivate any existing active key for this service
      await _supabase
          .from('api_keys')
          .update({'status': 'replaced', 'updated_at': DateTime.now().toIso8601String()})
          .eq('service_name', serviceName)
          .eq('status', 'active');

      // Insert the new key
      await _supabase.from('api_keys').insert({
        'service_name': serviceName,
        'label': label,
        'api_key': apiKey,
        'status': 'active',
        'created_by': userId,
      });

      SystemAuditService.logAction(
        actionType: 'SAVE_API_KEY',
        affectedEntity: 'Service: $serviceName',
        description: 'Developer ($userEmail) updated API key for $serviceName.',
      );

      await fetchKeys();
    } catch (e) {
      debugPrint('Error saving API key: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> revokeKey(String id, String serviceName, String userId, String userEmail) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.from('api_keys').update({
        'status': 'revoked',
        'is_revoked': true,
        'revoked_at': DateTime.now().toIso8601String(),
        'revoked_by': userId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      SystemAuditService.logAction(
        actionType: 'REVOKE_API_KEY',
        affectedEntity: 'Service: $serviceName',
        description: 'Developer ($userEmail) revoked API key for $serviceName.',
      );

      await fetchKeys();
    } catch (e) {
      debugPrint('Error revoking API key: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> testConnection(String serviceName, String apiKey) async {
    if (serviceName.toLowerCase() == 'smsworx') {
      final parts = apiKey.split(':');
      if (parts.length != 2) return false;
      return await SMSWorxService().testConnection(parts[0], parts[1]);
    } else if (serviceName.toLowerCase() == 'wesender') {
      return await WeSenderService().testConnection(apiKey);
    } else if (serviceName.toLowerCase() == 'idrive_e2') {
      final parts = apiKey.split(':');
      if (parts.length < 4) return false;
      return await IDriveE2Service.instance.testConnection(
        accessKeyId: parts[0],
        secretAccessKey: parts[1],
        endpoint: parts[2],
        bucket: parts[3],
      );
    }
    return false;
  }
}
