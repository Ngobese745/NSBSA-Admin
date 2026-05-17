import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

import '../services/cache_service.dart';
import '../services/system_audit_service.dart';
import '../services/communication_service.dart';

class GroupProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _communicationService = CommunicationService();
  List<GroupModel> _groups = [];
  bool _isLoading = false;

  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;

  Future<void> fetchGroups({bool forceRefresh = false}) async {
    // 1. Try to load from cache first
    if (!forceRefresh) {
      final cachedData = await CacheService.getCache('groups_cache');
      if (cachedData != null) {
        _groups = cachedData.map((e) => GroupModel.fromJson(e)).toList();
        notifyListeners();
        return; // Cache hit, return early
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

      // Save fresh data to cache
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
      // Fetch Center to get DF and Center Name
      final centerRes = await _supabase
          .from('centers')
          .select('name, df_id, df_name')
          .eq('id', centerId)
          .single();
      final actualCenterName = centerRes['name']?.toString() ?? 'NSBSA Center';
      final String? dfId = centerRes['df_id']?.toString();
      final dfName = centerRes['df_name']?.toString() ?? 'NSBSA Facilitator';

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
                'role': m['role'],
                'savings_amount': m['savings_amount'],
                'savings_frequency': m['savings_frequency'],
                'savings_start_date': m['savings_start_date'],
                'reference_number': referenceNumber,
                'df_id': (dfId == null || dfId.isEmpty) ? null : dfId,
                'df_name': dfName,
              },
            )
            .toList();

        await _supabase.from('vendors').insert(vendorData).select();

        // Populate Leadership table for targeted communication
        final List<Map<String, dynamic>> leadershipEntries = [];
        final vendorsResponse = await _supabase
            .from('vendors')
            .select()
            .eq('group_id', groupId);

        final List vendorsList = vendorsResponse as List? ?? [];
        
        for (var vendor in vendorsList) {
          final role = vendor['role'];
          if (['Chairperson', 'Secretary', 'Treasurer'].contains(role)) {
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

        // Send notifications to all new members (fire-and-forget — never blocks save)
        for (var vendor in vendorsList) {
          final vendorId = vendor['id']?.toString() ?? '';
          final vendorName = vendor['name']?.toString() ?? '';
          final vendorEmail = vendor['email']?.toString() ?? '';
          final vendorPhone = vendor['phone']?.toString() ?? '';
          final vendorWhatsApp = vendor['whatsapp_number']?.toString() ?? '';
          final memberRole = vendor['role']?.toString() ?? 'Member';

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

      return newGroup;
    } catch (e) {
      debugPrint('Error adding group: $e');
      rethrow;
    }
  }

  Future<void> updateGroup(String id, String name, {String? centerId}) async {
    try {
      final Map<String, dynamic> updates = {'name': name};
      if (centerId != null) updates['center_id'] = centerId;

      await _supabase.from('groups').update(updates).eq('id', id);
      SystemAuditService.logAction(
        actionType: 'UPDATE_GROUP',
        affectedEntity: 'Group ID: $id',
        description:
            'Updated group $name (Center: ${centerId ?? "unchanged"}).',
      );
      await fetchGroups(forceRefresh: true);
    } catch (e) {
      debugPrint('Error updating group: $e');
      rethrow;
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await _supabase.from('groups').delete().eq('id', id);
      _groups.removeWhere((g) => g.id == id);
      notifyListeners();
      await CacheService.saveCache(
        'groups_cache',
        _groups.map((e) => e.toJson()).toList(),
      );
      SystemAuditService.logAction(
        actionType: 'DELETE_GROUP',
        affectedEntity: 'Group ID: $id',
        description: 'Deleted group from the system.',
      );
    } catch (e) {
      debugPrint('Error deleting group: $e');
      rethrow;
    }
  }
}
