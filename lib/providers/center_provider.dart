import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/center.dart';
import '../models/leadership.dart';
import '../services/system_audit_service.dart';

class CenterProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<CenterModel> _centers = [];
  bool _isLoading = false;

  List<CenterModel> get centers => _centers;
  bool get isLoading => _isLoading;

  Future<void> fetchCenters() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.from('centers').select().order('name');
      _centers = (response as List)
          .map((e) => CenterModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching centers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCenter(String name, String referenceNumber) async {
    try {
      final response = await _supabase
          .from('centers')
          .insert({'name': name, 'reference_number': referenceNumber})
          .select()
          .single();

      _centers.add(CenterModel.fromJson(response));
      notifyListeners();

      SystemAuditService.logAction(
        actionType: 'CREATE_CENTER',
        affectedEntity: 'Center: $name',
        description: 'Created a new Center $name ($referenceNumber).',
      );
    } catch (e) {
      debugPrint('Error creating center: $e');
      rethrow;
    }
  }

  Future<void> assignLeadership({
    String? centerId,
    String? groupId,
    required String vendorId,
    required String role,
  }) async {
    try {
      // Use upsert because we have unique constraints on (center_id, role) and (group_id, role)
      await _supabase.from('leadership').upsert({
        if (centerId != null) 'center_id': centerId,
        if (groupId != null) 'group_id': groupId,
        'vendor_id': vendorId,
        'role': role,
      });

      SystemAuditService.logAction(
        actionType: 'ASSIGN_LEADERSHIP',
        affectedEntity: centerId != null
            ? 'Center ID: $centerId'
            : 'Group ID: $groupId',
        description: 'Assigned $role role to vendor $vendorId.',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error assigning leadership: $e');
      rethrow;
    }
  }

  Future<List<LeadershipModel>> fetchLeadership({
    String? centerId,
    String? groupId,
  }) async {
    try {
      var query = _supabase.from('leadership').select('*, vendors(name)');

      if (centerId != null) query = query.eq('center_id', centerId);
      if (groupId != null) query = query.eq('group_id', groupId);

      final response = await query;
      return (response as List)
          .map(
            (e) => LeadershipModel(
              id: e['id'],
              centerId: e['center_id'],
              groupId: e['group_id'],
              vendorId: e['vendor_id'],
              role: e['role'],
              vendorName: e['vendors']['name'],
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching leadership: $e');
      return [];
    }
  }

  Future<void> updateCenterDF(String centerId, String? dfId, String? dfName) async {
    try {
      await _supabase.from('centers').update({
        'df_id': dfId,
        'df_name': dfName,
      }).eq('id', centerId);

      final index = _centers.indexWhere((c) => c.id == centerId);
      if (index != -1) {
        final c = _centers[index];
        _centers[index] = CenterModel(
          id: c.id,
          name: c.name,
          referenceNumber: c.referenceNumber,
          createdAt: c.createdAt,
          dfId: dfId,
          dfName: dfName,
        );
      }
      notifyListeners();

      SystemAuditService.logAction(
        actionType: 'UPDATE_CENTER_DF',
        affectedEntity: 'Center ID: $centerId',
        description: 'Assigned DF $dfName to Center.',
      );
    } catch (e) {
      debugPrint('Error updating center DF: $e');
      rethrow;
    }
  }

  Future<void> deleteCenter(String id) async {
    try {
      final center = _centers.firstWhere((c) => c.id == id);
      if (center.name == 'Main Center') {
        throw Exception('Cannot delete the Main Center.');
      }

      await _supabase.from('centers').delete().eq('id', id);
      _centers.removeWhere((c) => c.id == id);
      notifyListeners();

      SystemAuditService.logAction(
        actionType: 'DELETE_CENTER',
        affectedEntity: 'Center ID: $id',
        description: 'Deleted center ${center.name}.',
      );
    } catch (e) {
      debugPrint('Error deleting center: $e');
      rethrow;
    }
  }
}
