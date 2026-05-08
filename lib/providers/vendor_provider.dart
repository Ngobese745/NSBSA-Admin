import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor.dart';

import '../services/cache_service.dart';

class VendorProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<VendorModel> _vendors = [];
  bool _isLoading = false;

  List<VendorModel> get vendors => _vendors;
  bool get isLoading => _isLoading;

  Future<void> fetchVendors({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCache('vendors_cache');
      if (cachedData != null) {
        _vendors = cachedData.map((e) => VendorModel.fromJson(e)).toList();
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.from('vendors').select().order('created_at', ascending: false);
      _vendors = (response as List).map((e) => VendorModel.fromJson(e)).toList();
      
      await CacheService.saveCache('vendors_cache', _vendors.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error fetching vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<VendorModel> addVendor(VendorModel vendor) async {
    try {
      final response = await _supabase.from('vendors').insert(vendor.toJson()).select().single();
      final newVendor = VendorModel.fromJson(response);
      
      _vendors.insert(0, newVendor);
      notifyListeners();
      CacheService.saveCache('vendors_cache', _vendors.map((e) => e.toJson()).toList());
      
      return newVendor;
    } catch (e) {
      debugPrint('Error adding vendor: $e');
      rethrow;
    }
  }

  Future<List<VendorModel>> fetchVendorsByGroup(String groupId) async {
    try {
      final response = await _supabase
          .from('vendors')
          .select()
          .eq('group_id', groupId)
          .order('name', ascending: true);
      return (response as List).map((e) => VendorModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching group vendors: $e');
      return [];
    }
  }

  Future<void> updateVendor(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('vendors').update(data).eq('id', id);
      await fetchVendors(forceRefresh: true);
    } catch (e) {
      debugPrint('Error updating vendor: $e');
      rethrow;
    }
  }

  Future<void> deleteVendor(String id) async {
    try {
      await _supabase.from('vendors').delete().eq('id', id);
      await fetchVendors(forceRefresh: true);
    } catch (e) {
      debugPrint('Error deleting vendor: $e');
      rethrow;
    }
  }

  /// Checks if a vendor with the same [idNumber] or [phone] already exists.
  /// Pass [excludeId] when editing so the current record is not flagged.
  /// Returns the conflicting [VendorModel] if a duplicate is found, or null.
  Future<VendorModel?> checkDuplicateVendor({
    required String? idNumber,
    required String? phone,
    String? excludeId,
  }) async {
    final hasId = idNumber != null && idNumber.trim().isNotEmpty;
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    if (!hasId && !hasPhone) return null;

    try {
      // Check by ID number first (stronger identifier)
      if (hasId) {
        var query = _supabase
            .from('vendors')
            .select()
            .eq('id_number', idNumber!.trim());
        if (excludeId != null && excludeId.isNotEmpty) {
          query = query.neq('id', excludeId);
        }
        final results = await query;
        if ((results as List).isNotEmpty) {
          return VendorModel.fromJson(results.first);
        }
      }

      // Then check by phone number
      if (hasPhone) {
        var query = _supabase
            .from('vendors')
            .select()
            .eq('phone', phone!.trim());
        if (excludeId != null && excludeId.isNotEmpty) {
          query = query.neq('id', excludeId);
        }
        final results = await query;
        if ((results as List).isNotEmpty) {
          return VendorModel.fromJson(results.first);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error checking duplicate vendor: $e');
      return null;
    }
  }
}
