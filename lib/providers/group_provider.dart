import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../services/cache_service.dart';
import '../services/realtime_service.dart';
import '../services/system_audit_service.dart';
import '../services/communication_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/notification_service.dart';

class GroupProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _communicationService = CommunicationService();
  List<GroupModel> _groups = [];
  bool _isLoading = false;
  Timer? _cacheDebounce;

  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;

  GroupProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'groups',
      onData: (payload) {
        final event = payload.eventType;
        final data = payload.newRecord;
        final oldData = payload.oldRecord;

        try {
          if (event == PostgresChangeEvent.insert) {
            final newGroup = GroupModel.fromJson(data);
            if (!_groups.any((g) => g.id == newGroup.id)) {
              _groups.insert(0, newGroup);
              _syncCacheAndNotify();
            }
          } else if (event == PostgresChangeEvent.update) {
            final updatedGroup = GroupModel.fromJson(data);
            final index = _groups.indexWhere((g) => g.id == updatedGroup.id);
            if (index != -1) {
              _groups[index] = updatedGroup;
              _syncCacheAndNotify();
            }
          } else if (event == PostgresChangeEvent.delete) {
            final id = oldData['id'];
            final before = _groups.length;
            _groups.removeWhere((g) => g.id == id);
            if (_groups.length != before) {
              _syncCacheAndNotify();
            }
          }
        } catch (e) {
          debugPrint('Error processing groups realtime update: $e');
        }
      },
    );
  }

  void _syncCacheAndNotify() {
    notifyListeners();
    _cacheDebounce?.cancel();
    _cacheDebounce = Timer(const Duration(seconds: 2), () {
      CacheService.saveCache(
        'groups_cache',
        _groups.map((e) => e.toJson()).toList(),
      );
    });
  }

  @override
  void dispose() {
    _cacheDebounce?.cancel();
    super.dispose();
  }

  Future<void> fetchGroups({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCache('groups_cache');
      if (cachedData != null) {
        _groups = cachedData.map((e) => GroupModel.fromJson(e)).toList();
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('groups')
          .select()
          .order('created_at', ascending: false);
      _groups = (response as List).map((e) => GroupModel.fromJson(e)).toList();
      await CacheService.saveCache(
        'groups_cache',
        _groups.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching groups: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GroupModel> addGroupWithMembers(
    String name,
    String referenceNumber,
    String centerId,
    List<Map<String, dynamic>> members, {
    String? creatorId,
    String? creatorName,
  }) async {
    try {
      final centerRes = await _supabase
          .from('centers')
          .select('name, df_id, df_name')
          .eq('id', centerId)
          .single();
      final actualCenterName = centerRes['name']?.toString() ?? 'NSBSA Center';
      final String? dfId = centerRes['df_id']?.toString();
      final dfName = centerRes['df_name']?.toString() ?? 'NSBSA Facilitator';

      final user = _supabase.auth.currentUser;
      final response = await _supabase
          .from('groups')
          .insert({
            'name': name,
            'reference_number': referenceNumber,
            'center_id': centerId,
            'df_id': (dfId == null || dfId.isEmpty) ? null : dfId,
            'df_name': dfName,
            'creator_id': (creatorId == null || creatorId.isEmpty) ? null : creatorId,
            'creator_name': creatorName,
            'created_by': user?.id,
          })
          .select()
          .single();

      final groupId = response['id'];
      final newGroup = GroupModel.fromJson(response);

      if (members.isNotEmpty) {
        final vendorData = members
            .map(
              (m) => {
                'group_id': groupId,
                'name': m['name'],
                'phone': m['phone'],
                'id_number': m['id_number'],
                'gender': m['gender'],
                'business_type': m['business'],
                'whatsapp_number': m['whatsapp'],
                'email': m['email'],
                'address': m['address'],
                'role': 'Member',
                'savings_amount': m['savings_amount'],
                'savings_frequency': m['savings_frequency'],
                'savings_start_date': m['savings_start_date'],
                'reference_number': referenceNumber,
                'df_id': (dfId == null || dfId.isEmpty) ? null : dfId,
                'df_name': dfName,
              },
            )
            .toList();

        final vendorsResponse = await _supabase
            .from('vendors')
            .insert(vendorData)
            .select();

        final List insertedVendors = vendorsResponse as List? ?? [];

        final leadershipRoles = {
          for (var m in members)
            if (['Chairperson', 'Secretary', 'Treasurer']
                .contains(m['role']))
              m['name'] as String: m['role'] as String,
        };

        final List<Map<String, dynamic>> leadershipEntries = [];
        for (var vendor in insertedVendors) {
          final name = vendor['name']?.toString() ?? '';
          final role = leadershipRoles[name];
          if (role != null) {
            leadershipEntries.add({
              'group_id': groupId,
              'vendor_id': vendor['id'],
              'role': role,
            });
          }
        }

        if (leadershipEntries.isNotEmpty) {
          await _supabase.from('leadership').insert(leadershipEntries);
        }

        for (var vendor in insertedVendors) {
          final vendorId = vendor['id']?.toString() ?? '';
          final vendorName = vendor['name']?.toString() ?? '';
          final vendorEmail = vendor['email']?.toString() ?? '';
          final vendorPhone = vendor['phone']?.toString() ?? '';
          final vendorWhatsApp = vendor['whatsapp_number']?.toString() ?? '';
          final memberRole = leadershipRoles[vendorName] ?? 'Member';

          if (vendorId.isNotEmpty && vendorName.isNotEmpty) {
            _communicationService
                .sendPrivacyPolicyNotification(
                  vendorId: vendorId,
                  vendorName: vendorName,
                  toEmail: vendorEmail,
                  toPhone: vendorPhone,
                  toWhatsApp: vendorWhatsApp,
                  groupName: name,
                  groupRef: referenceNumber,
                  centerName: actualCenterName,
                  memberRole: memberRole,
                )
                .catchError((e) {
              debugPrint(
                  'Non-critical: Privacy Policy notification failed for $vendorName: $e');
            });
          }
        }
      }

      _groups.insert(0, newGroup);
      notifyListeners();
      CacheService.saveCache(
        'groups_cache',
        _groups.map((e) => e.toJson()).toList(),
      );

      SystemAuditService.logAction(
        actionType: 'CREATE_GROUP',
        affectedEntity: 'Group: $name ($referenceNumber)',
        description: 'Created a new group with ${members.length} members.',
      );

      if (newGroup.isPending) {
        NotificationService.notifyAdmins(
          'Group Approval Needed',
          'Group "$name" requires Admin verification.',
          type: 'ACTIVITY',
        );
        NotificationService.notifySuperAdmin(
          'Group Pending Approval',
          'Group "$name" ($referenceNumber) has been created and is pending review.',
          type: 'ACTIVITY',
        );
      }

      return newGroup;
    } catch (e) {
      debugPrint('Error adding group: $e');
      rethrow;
    }
  }

  Future<void> approveGroup(String id, {String? rejectionReason}) async {
    final index = _groups.indexWhere((g) => g.id == id);
    if (index == -1) return;

    final user = _supabase.auth.currentUser;
    final updates = <String, dynamic>{
      if (rejectionReason == null) ...{
        'approval_status': 'Approved',
        'approved_by': user?.id,
        'approved_at': DateTime.now().toIso8601String(),
      } else ...{
        'approval_status': 'Rejected',
        'approved_by': user?.id,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': rejectionReason,
      }
    };

    try {
      final response = await _supabase.from('groups').update(updates).eq('id', id).select().single();
      _groups[index] = GroupModel.fromJson(response);
      CacheService.saveCache('groups_cache', _groups.map((e) => e.toJson()).toList());
      notifyListeners();

      SystemAuditService.logAction(
        actionType: rejectionReason == null ? 'APPROVE_GROUP' : 'REJECT_GROUP',
        affectedEntity: 'Group ID: $id',
        description: rejectionReason == null
            ? 'Approved group registration.'
            : 'Rejected group registration. Reason: $rejectionReason',
      );
    } catch (e) {
      debugPrint('Error updating group approval status: $e');
      rethrow;
    }
  }

  Future<void> updateGroup(String id, String name, {String? centerId}) async {
    final index = _groups.indexWhere((g) => g.id == id);
    if (index == -1) return;

    final oldGroup = _groups[index];
    _groups[index] = GroupModel(
      id: id,
      name: name,
      referenceNumber: oldGroup.referenceNumber,
      centerId: centerId ?? oldGroup.centerId,
      dfId: oldGroup.dfId,
      dfName: oldGroup.dfName,
      createdAt: oldGroup.createdAt,
    );
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'groups',
        type: OfflineActionType.update,
        data: {'id': id, 'name': name, if (centerId != null) 'center_id': centerId},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final Map<String, dynamic> updates = {'name': name};
      if (centerId != null) updates['center_id'] = centerId;

      await _supabase.from('groups').update(updates).eq('id', id);
      SystemAuditService.logAction(
        actionType: 'UPDATE_GROUP',
        affectedEntity: 'Group ID: $id',
        description: 'Updated group $name (Center: ${centerId ?? "unchanged"}).',
      );
      CacheService.saveCache(
        'groups_cache',
        _groups.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      _groups[index] = oldGroup;
      notifyListeners();
      debugPrint('Error updating group: $e');
      rethrow;
    }
  }

  Future<void> deleteGroup(String id) async {
    final index = _groups.indexWhere((g) => g.id == id);
    if (index == -1) return;

    final deletedGroup = _groups.removeAt(index);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'groups',
        type: OfflineActionType.delete,
        data: {'id': id},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('groups').delete().eq('id', id);
      CacheService.saveCache(
        'groups_cache',
        _groups.map((e) => e.toJson()).toList(),
      );
      SystemAuditService.logAction(
        actionType: 'DELETE_GROUP',
        affectedEntity: 'Group ID: $id',
        description: 'Deleted group from the system.',
      );
    } catch (e) {
      _groups.insert(index, deletedGroup);
      notifyListeners();
      debugPrint('Error deleting group: $e');
      rethrow;
    }
  }
}
