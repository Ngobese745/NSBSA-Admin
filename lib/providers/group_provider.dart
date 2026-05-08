import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

import '../services/cache_service.dart';

class GroupProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
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
      final response = await _supabase.from('groups').select().order('created_at', ascending: false);
      _groups = (response as List).map((e) => GroupModel.fromJson(e)).toList();
      
      // Save fresh data to cache
      await CacheService.saveCache('groups_cache', _groups.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error fetching groups: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GroupModel> addGroupWithMembers(String name, String referenceNumber, List<Map<String, String>> members) async {
    try {
      final response = await _supabase.from('groups').insert({
        'name': name,
        'reference_number': referenceNumber,
      }).select().single();

      final groupId = response['id'];
      final newGroup = GroupModel.fromJson(response);

      if (members.isNotEmpty) {
        final vendorData = members.map((m) => {
          'group_id': groupId,
          'name': m['name'],
          'phone': m['phone'],
          'id_number': m['id_number'],
          'gender': m['gender'],
          'business_type': m['business'],
          'whatsapp_number': m['whatsapp'],
          'reference_number': referenceNumber,
        }).toList();

        await _supabase.from('vendors').insert(vendorData);
      }
      
      _groups.insert(0, newGroup);
      notifyListeners();
      CacheService.saveCache('groups_cache', _groups.map((e) => e.toJson()).toList());
      
      return newGroup;
    } catch (e) {
      debugPrint('Error adding group: $e');
      rethrow;
    }
  }
  Future<void> updateGroup(String id, String name) async {
    try {
      await _supabase.from('groups').update({'name': name}).eq('id', id);
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
      await CacheService.saveCache('groups_cache', _groups.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error deleting group: $e');
      rethrow;
    }
  }
}
