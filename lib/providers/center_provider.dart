import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/center.dart';
import '../models/leadership.dart';
import '../services/cache_service.dart';
import '../services/system_audit_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class CenterProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<CenterModel> _centers = [];
  bool _isLoading = false;

  List<CenterModel> get centers => _centers;
  bool get isLoading => _isLoading;

  Future<void> fetchCenters({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCache('centers_cache');
      if (cachedData != null) {
        _centers = cachedData.map((e) => CenterModel.fromJson(e)).toList();
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.from('centers').select().order('name');
      _centers = (response as List)
          .map((e) => CenterModel.fromJson(e))
          .toList();
      await CacheService.saveCache(
        'centers_cache',
        _centers.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching centers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCenter(String name, String referenceNumber) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempCenter = CenterModel(
      id: tempId,
      name: name,
      referenceNumber: referenceNumber,
      createdAt: DateTime.now(),
    );
    _centers.insert(0, tempCenter);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: tempId,
        table: 'centers',
        type: OfflineActionType.create,
        data: {'name': name, 'reference_number': referenceNumber},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final response = await _supabase
          .from('centers')
          .insert({'name': name, 'reference_number': referenceNumber})
          .select()
          .single();

      final index = _centers.indexWhere((c) => c.id == tempId);
      if (index != -1) {
        _centers[index] = CenterModel.fromJson(response);
      } else {
        _centers.add(CenterModel.fromJson(response));
      }
      notifyListeners();
      CacheService.saveCache(
        'centers_cache',
        _centers.map((e) => e.toJson()).toList(),
      );

      SystemAuditService.logAction(
        actionType: 'CREATE_CENTER',
        affectedEntity: 'Center: $name',
        description: 'Created a new Center $name ($referenceNumber).',
      );
    } catch (e) {
      _centers.removeWhere((c) => c.id == tempId);
      notifyListeners();
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
    final index = _centers.indexWhere((c) => c.id == centerId);
    if (index == -1) return;

    final oldCenter = _centers[index];
    _centers[index] = CenterModel(
      id: oldCenter.id,
      name: oldCenter.name,
      referenceNumber: oldCenter.referenceNumber,
      createdAt: oldCenter.createdAt,
      dfId: dfId,
      dfName: dfName,
    );
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'centers',
        type: OfflineActionType.update,
        data: {'id': centerId, 'df_id': dfId, 'df_name': dfName},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('centers').update({
        'df_id': dfId,
        'df_name': dfName,
      }).eq('id', centerId);

      CacheService.saveCache(
        'centers_cache',
        _centers.map((e) => e.toJson()).toList(),
      );

      SystemAuditService.logAction(
        actionType: 'UPDATE_CENTER_DF',
        affectedEntity: 'Center ID: $centerId',
        description: 'Assigned DF $dfName to Center.',
      );
    } catch (e) {
      _centers[index] = oldCenter;
      notifyListeners();
      debugPrint('Error updating center DF: $e');
      rethrow;
    }
  }

  Future<void> deleteCenter(String id) async {
    final center = _centers.firstWhere((c) => c.id == id);
    if (center.name == 'Main Center') {
      throw Exception('Cannot delete the Main Center.');
    }

    final index = _centers.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final deletedCenter = _centers.removeAt(index);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'centers',
        type: OfflineActionType.delete,
        data: {'id': id},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('centers').delete().eq('id', id);
      CacheService.saveCache(
        'centers_cache',
        _centers.map((e) => e.toJson()).toList(),
      );

      SystemAuditService.logAction(
        actionType: 'DELETE_CENTER',
        affectedEntity: 'Center ID: $id',
        description: 'Deleted center ${center.name}.',
      );
    } catch (e) {
      _centers.insert(index, deletedCenter);
      notifyListeners();
      debugPrint('Error deleting center: $e');
      rethrow;
    }
  }
}
