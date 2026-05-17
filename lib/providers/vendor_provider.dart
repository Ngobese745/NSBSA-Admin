import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor.dart';
import '../models/savings_history.dart';

import '../services/cache_service.dart';
import '../services/system_audit_service.dart';
import '../services/realtime_service.dart';
import '../services/offline_queue_service.dart';
import '../services/connectivity_service.dart';
import '../services/communication_service.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class VendorProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<VendorModel> _vendors = [];
  bool _isLoading = false;

  List<VendorModel> get vendors => _vendors;
  bool get isLoading => _isLoading;

  VendorProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'vendors',
      onData: (payload) {
        final event = payload.eventType;
        final data = payload.newRecord;
        final oldData = payload.oldRecord;

        if (event == PostgresChangeEvent.insert) {
          final newVendor = VendorModel.fromJson(data);
          if (!_vendors.any((v) => v.id == newVendor.id)) {
            _vendors.insert(0, newVendor);
            _syncCacheAndNotify();
          }
        } else if (event == PostgresChangeEvent.update) {
          final updatedVendor = VendorModel.fromJson(data);
          final index = _vendors.indexWhere((v) => v.id == updatedVendor.id);
          if (index != -1) {
            _vendors[index] = updatedVendor;
            _syncCacheAndNotify();
          }
        } else if (event == PostgresChangeEvent.delete) {
          final id = oldData['id'];
          _vendors.removeWhere((v) => v.id == id);
          _syncCacheAndNotify();
        }
      },
    );
  }

  void _syncCacheAndNotify() {
    CacheService.saveCache('vendors_cache', _vendors.map((e) => e.toJson()).toList());
    notifyListeners();
  }

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
      final response = await _supabase
          .from('vendors')
          .select()
          .order('created_at', ascending: false);
      _vendors = (response as List).map((e) => VendorModel.fromJson(e)).toList();
      _syncCacheAndNotify();
    } catch (e) {
      debugPrint('Error fetching vendors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<VendorModel> addVendor(VendorModel vendor) async {
    // Optimistic
    _vendors.insert(0, vendor);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'vendors',
        type: OfflineActionType.create,
        data: vendor.toJson(),
        timestamp: DateTime.now(),
      ));
      return vendor;
    }

    try {
      String? dfId = vendor.dfId;
      String? dfName = vendor.dfName;

      if (dfId == null || dfName == null) {
        final groupRes = await _supabase.from('groups').select('df_id, df_name').eq('id', vendor.groupId).single();
        dfId ??= groupRes['df_id'];
        dfName ??= groupRes['df_name'];
      }

      final data = vendor.toJson();
      data['df_id'] = dfId;
      data['df_name'] = dfName;

      final response = await _supabase.from('vendors').insert(data).select().single();
      final newVendor = VendorModel.fromJson(response);

      final index = _vendors.indexWhere((v) => v.id == vendor.id || v.id == '');
      if (index != -1) _vendors[index] = newVendor;

      _syncCacheAndNotify();
      _logAction(newVendor);

      // Trigger Privacy Policy notification for newly added member
      _triggerPrivacyPolicyNotification(newVendor);

      return newVendor;
    } catch (e) {
      _vendors.removeWhere((v) => v.id == vendor.id);
      notifyListeners();
      debugPrint('Error adding vendor: $e');
      rethrow;
    }
  }

  void _logAction(VendorModel vendor) {
    SystemAuditService.logAction(
      actionType: 'CREATE_VENDOR',
      affectedEntity: 'Vendor: ${vendor.name} (${vendor.idNumber ?? vendor.phone})',
      description: 'Created a new vendor/member.',
    );
  }

  Future<void> _triggerPrivacyPolicyNotification(VendorModel vendor) async {
    try {
      // Fetch Group/Center Info
      final groupRes = await _supabase
          .from('groups')
          .select('name, reference_number, centers(name)')
          .eq('id', vendor.groupId)
          .single();
      
      final groupName = groupRes['name']?.toString() ?? 'Unknown Group';
      final groupRef = groupRes['reference_number']?.toString() ?? 'N/A';
      final centerName = groupRes['centers']?['name']?.toString() ?? 'Unknown Center';

      await CommunicationService().sendPrivacyPolicyNotification(
        vendorId: vendor.id,
        vendorName: vendor.name,
        toEmail: vendor.email ?? '',
        toPhone: vendor.phone ?? '',
        toWhatsApp: vendor.whatsappNumber ?? '',
        groupName: groupName,
        groupRef: groupRef,
        centerName: centerName,
        memberRole: vendor.role ?? 'Member',
      );
    } catch (e) {
      debugPrint('Non-critical: Privacy Policy notification failed for ${vendor.name}: $e');
    }
  }

  Future<void> updateVendor(String id, Map<String, dynamic> data) async {
    final index = _vendors.indexWhere((v) => v.id == id);
    if (index == -1) return;

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'vendors',
        type: OfflineActionType.update,
        data: {'id': id, ...data},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final response = await _supabase.from('vendors').update(data).eq('id', id).select().single();
      _vendors[index] = VendorModel.fromJson(response);
      _syncCacheAndNotify();
      
      SystemAuditService.logAction(
        actionType: 'UPDATE_VENDOR',
        affectedEntity: 'Vendor ID: $id',
        description: 'Updated vendor profile details.',
      );
    } catch (e) {
      debugPrint('Error updating vendor: $e');
      rethrow;
    }
  }

  Future<void> deleteVendor(String id) async {
    final index = _vendors.indexWhere((v) => v.id == id);
    if (index == -1) return;
    final deleted = _vendors.removeAt(index);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'vendors',
        type: OfflineActionType.delete,
        data: {'id': id},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('vendors').delete().eq('id', id);
      _syncCacheAndNotify();
      SystemAuditService.logAction(
        actionType: 'DELETE_VENDOR',
        affectedEntity: 'Vendor ID: $id',
        description: 'Deleted vendor from the system.',
      );
    } catch (e) {
      _vendors.insert(index, deleted);
      notifyListeners();
      debugPrint('Error deleting vendor: $e');
      rethrow;
    }
  }

  Future<VendorModel?> checkDuplicateVendor({
    required String? idNumber,
    required String? phone,
    String? excludeId,
  }) async {
    final hasId = idNumber != null && idNumber.trim().isNotEmpty;
    final hasPhone = phone != null && phone.trim().isNotEmpty;
    if (!hasId && !hasPhone) return null;

    try {
      if (hasId) {
        var query = _supabase.from('vendors').select().eq('id_number', idNumber!.trim());
        if (excludeId != null && excludeId.isNotEmpty) query = query.neq('id', excludeId);
        final results = await query;
        if ((results as List).isNotEmpty) return VendorModel.fromJson(results.first);
      }
      if (hasPhone) {
        var query = _supabase.from('vendors').select().eq('phone', phone!.trim());
        if (excludeId != null && excludeId.isNotEmpty) query = query.neq('id', excludeId);
        final results = await query;
        if ((results as List).isNotEmpty) return VendorModel.fromJson(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking duplicate vendor: $e');
      return null;
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

  Future<void> recordSavingsTransaction({
    required String vendorId,
    required double amount,
    required String actionType,
    required String updatedBy,
  }) async {
    final index = _vendors.indexWhere((v) => v.id == vendorId);
    if (index == -1) return;

    final vendor = _vendors[index];
    final double previousBalance = vendor.savingsAmount ?? 0.0;
    double newBalance;

    if (actionType == 'Deposit') {
      newBalance = previousBalance + amount;
    } else if (actionType == 'Withdrawal') {
      newBalance = previousBalance - amount;
    } else {
      // Adjustment
      newBalance = amount;
    }

    // Optimistic Update
    final updatedVendor = vendor.copyWith(savingsAmount: newBalance);
    _vendors[index] = updatedVendor;
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'savings_transaction_batch', // Logic handled in background sync
        type: OfflineActionType.create,
        data: {
          'vendor_id': vendorId,
          'amount': amount,
          'previous_balance': previousBalance,
          'new_balance': newBalance,
          'action_type': actionType,
          'updated_by': updatedBy,
        },
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      // 1. Update vendor balance
      await _supabase.from('vendors').update({'savings_amount': newBalance}).eq('id', vendorId);

      // 2. Record history
      await _supabase.from('savings_history').insert({
        'vendor_id': vendorId,
        'amount': amount,
        'previous_balance': previousBalance,
        'new_balance': newBalance,
        'action_type': actionType,
        'updated_by': updatedBy,
      });

      SystemAuditService.logAction(
        actionType: 'SAVINGS_TRANSACTION',
        affectedEntity: 'Vendor ID: $vendorId',
        description: 'Recorded $actionType of R $amount. New balance: R $newBalance.',
      );
      
      _syncCacheAndNotify();

      // 3. Trigger Automated Notification
      _triggerSavingsNotification(
        vendorId: vendorId,
        amount: amount,
        previousBalance: previousBalance,
        newBalance: newBalance,
        actionType: actionType,
        updatedBy: updatedBy,
      );
    } catch (e) {
      // Rollback optimistic update
      _vendors[index] = vendor;
      notifyListeners();
      debugPrint('Error recording savings transaction: $e');
      rethrow;
    }
  }

  Future<void> _triggerSavingsNotification({
    required String vendorId,
    required double amount,
    required double previousBalance,
    required double newBalance,
    required String actionType,
    required String updatedBy,
  }) async {
    // Small delay to ensure DB indexing is complete
    await Future.delayed(const Duration(seconds: 2));

    try {
      final vendor = _vendors.firstWhere((v) => v.id == vendorId);
      
      // 1. Fetch Group/Center Info
      final groupRes = await _supabase
          .from('groups')
          .select('name, center_id, centers(name)')
          .eq('id', vendor.groupId)
          .single();
      
      final groupName = groupRes['name'] ?? 'Unknown Group';
      final centerName = groupRes['centers']?['name'] ?? 'Unknown Center';

      // 2. Fetch Recent History (for PDF)
      final historyRes = await _supabase
          .from('savings_history')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(10);
      
      final recentHistory = (historyRes as List)
          .map((e) => SavingsHistoryModel.fromJson(e))
          .toList();

      // Find the current transaction in history to get its ID
      final currentHistory = recentHistory.firstWhere(
        (h) => h.amount == amount && h.newBalance == newBalance && h.actionType == actionType,
        orElse: () => SavingsHistoryModel(
          id: 'SAV-${DateTime.now().millisecondsSinceEpoch}',
          vendorId: vendorId,
          amount: amount,
          previousBalance: previousBalance,
          newBalance: newBalance,
          actionType: actionType,
          updatedBy: updatedBy,
          createdAt: DateTime.now(),
        ),
      );

      // 3. Send Notification
      await CommunicationService().sendSavingsTransactionNotification(
        vendor: vendor,
        history: currentHistory,
        groupName: groupName,
        centerName: centerName,
        recentHistory: recentHistory,
      );
    } catch (e) {
      debugPrint('Error triggering savings notification: $e');
    }
  }

  Future<String?> uploadAvatar(String vendorId, Uint8List fileBytes, String extension) async {
    try {
      _isLoading = true;
      notifyListeners();

      Uint8List dataToUpload = fileBytes;
      
      // If over 5MB, compress
      if (fileBytes.length > 5 * 1024 * 1024) {
        final image = img.decodeImage(fileBytes);
        if (image != null) {
          // Resize if very large, otherwise just compress quality
          img.Image resized = image;
          if (image.width > 1200) {
            resized = img.copyResize(image, width: 1200);
          }
          dataToUpload = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
        }
      }

      final fileName = 'avatar_${vendorId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'avatars/$fileName';

      await _supabase.storage.from('documents').uploadBinary(
        filePath,
        dataToUpload,
        fileOptions: FileOptions(contentType: 'image/$extension', upsert: true),
      );

      final publicUrl = _supabase.storage.from('documents').getPublicUrl(filePath);

      // Update vendor profile
      await updateVendor(vendorId, {'avatar_url': publicUrl});

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
