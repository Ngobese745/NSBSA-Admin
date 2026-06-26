import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan.dart';

import '../services/cache_service.dart';
import '../services/system_audit_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/offline_queue_service.dart';
import '../services/connectivity_service.dart';
import '../services/communication_service.dart';

class LoanProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _communicationService = CommunicationService();
  List<LoanModel> _loans = [];
  bool _isLoading = false;

  List<LoanModel> get loans => _loans;
  bool get isLoading => _isLoading;

  LoanProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'loans',
      onData: (payload) {
        final event = payload.eventType;
        final data = payload.newRecord;
        final oldData = payload.oldRecord;

        if (event == PostgresChangeEvent.insert) {
          final newLoan = LoanModel.fromJson(data);
          if (!_loans.any((l) => l.id == newLoan.id)) {
            _loans.insert(0, newLoan);
            _syncCacheAndNotify();
          }
        } else if (event == PostgresChangeEvent.update) {
          final updatedLoan = LoanModel.fromJson(data);
          final index = _loans.indexWhere((l) => l.id == updatedLoan.id);
          if (index != -1) {
            _loans[index] = updatedLoan;
            _syncCacheAndNotify();
          }
        } else if (event == PostgresChangeEvent.delete) {
          final id = oldData['id'];
          _loans.removeWhere((l) => l.id == id);
          _syncCacheAndNotify();
        }
      },
    );
  }

  Timer? _cacheDebounce;

  void _syncCacheAndNotify() {
    notifyListeners();
    _cacheDebounce?.cancel();
    _cacheDebounce = Timer(const Duration(seconds: 2), () {
      CacheService.saveCache('loans_cache', _loans.map((e) => e.toJson()).toList());
    });
  }

  Future<void> fetchLoans({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCache('loans_cache');
      if (cachedData != null) {
        _loans = cachedData.map((e) => LoanModel.fromJson(e)).toList();
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('loans')
          .select('*, vendors(name)')
          .order('created_at', ascending: false);
      _loans = (response as List).map((e) => LoanModel.fromJson(e)).toList();
      _syncCacheAndNotify();
    } catch (e) {
      debugPrint('Error fetching loans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LoanModel> addLoan(LoanModel loan) async {
    // Optimistic Update
    _loans.insert(0, loan);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'loans',
        type: OfflineActionType.create,
        data: loan.toJson(),
        timestamp: DateTime.now(),
      ));
      return loan;
    }

    try {
      final loanData = loan.toJson();
      loanData.remove('vendor_name');
      
      final response = await _supabase.from('loans').insert(loanData).select().single();
      final confirmedLoan = LoanModel.fromJson(response);
      
      final index = _loans.indexWhere((l) => l.id == loan.id);
      if (index != -1) {
        _loans[index] = confirmedLoan;
      } else {
        _loans.insert(0, confirmedLoan);
      }
      
      _syncCacheAndNotify();
      _logAndNotify(confirmedLoan);

      // Trigger multi-channel notifications (fire-and-forget)
      _triggerLoanNotifications(confirmedLoan).catchError((e) {
        debugPrint('Non-critical: Loan notification failed: $e');
      });

      return confirmedLoan;
    } catch (e) {
      _loans.removeWhere((l) => l.id == loan.id);
      notifyListeners();
      throw Exception('Failed to add loan. Please try again.');
    }
  }

  Future<void> updateLoan(String id, Map<String, dynamic> updates) async {
    final oldLoanIndex = _loans.indexWhere((l) => l.id == id);
    if (oldLoanIndex == -1) return;
    
    final oldLoan = _loans[oldLoanIndex];
    
    // Optimistic Update
    // Note: This is a simplified merge, usually you'd create a copy with updates
    // For brevity, we just trigger notify and wait for DB
    
    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'loans',
        type: OfflineActionType.update,
        data: {'id': id, ...updates},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final safeUpdates = Map<String, dynamic>.from(updates);
      safeUpdates.remove('vendor_name');
      
      final response = await _supabase.from('loans').update(safeUpdates).eq('id', id).select().single();
      final updatedLoan = LoanModel.fromJson(response);

      _loans[oldLoanIndex] = updatedLoan;
      _syncCacheAndNotify();
    } catch (e) {
      debugPrint('Error updating loan: $e');
      rethrow;
    }
  }

  Future<void> deleteLoan(String id) async {
    final oldLoanIndex = _loans.indexWhere((l) => l.id == id);
    if (oldLoanIndex == -1) return;
    final deletedLoan = _loans.removeAt(oldLoanIndex);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'loans',
        type: OfflineActionType.delete,
        data: {'id': id},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('loans').delete().eq('id', id);
      _syncCacheAndNotify();
    } catch (e) {
      _loans.insert(oldLoanIndex, deletedLoan);
      notifyListeners();
      debugPrint('Error deleting loan: $e');
      rethrow;
    }
  }

  Future<List<LoanModel>> fetchLoansByGroup(String groupId) async {
    try {
      final response = await _supabase
          .from('loans')
          .select('*, vendors(name)')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => LoanModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching group loans: $e');
      return [];
    }
  }

  void _logAndNotify(LoanModel loan) {
    SystemAuditService.logAction(
      actionType: 'CREATE_LOAN',
      affectedEntity: 'Loan for Vendor: ${loan.vendorId}',
      description: 'Created a new loan for R${loan.amount}.',
    );
    NotificationService.notifyAdmins(
      'New Loan Created',
      'A new loan of R${loan.amount} has been issued.',
      type: 'FINANCIAL',
    );
  }

  Future<void> _triggerLoanNotifications(LoanModel loan) async {
    try {
      // 1. Fetch Vendor Details
      final vendorRes = await _supabase
          .from('vendors')
          .select('name, email, phone, whatsapp_number')
          .eq('id', loan.vendorId ?? '')
          .single();

      final vName = vendorRes['name']?.toString() ?? 'Member';
      final vEmail = vendorRes['email']?.toString() ?? '';
      final vPhone = vendorRes['phone']?.toString() ?? '';
      final vWhatsApp = vendorRes['whatsapp_number']?.toString() ?? '';

      // 2. Fetch Group & Center Details
      final groupRes = await _supabase
          .from('groups')
          .select('name, center_id')
          .eq('id', loan.groupId)
          .single();

      final gName = groupRes['name']?.toString() ?? 'NSBSA Group';
      final centerId = groupRes['center_id'];

      String cName = 'NSBSA Center';
      if (centerId != null) {
        final centerRes = await _supabase
            .from('centers')
            .select('name')
            .eq('id', centerId)
            .single();
        cName = centerRes['name']?.toString() ?? 'NSBSA Center';
      }

      // 3. Send Notification
      await _communicationService.sendLoanCreationNotification(
        vendorId: loan.vendorId ?? '',
        vendorName: vName,
        toEmail: vEmail,
        toPhone: vPhone,
        toWhatsApp: vWhatsApp,
        loanRef: loan.id.substring(0, 8).toUpperCase(),
        amount: loan.amount,
        groupName: gName,
        centerName: cName,
        date: loan.createdAt,
        durationMonths: loan.durationMonths,
        nextPaymentDate: loan.firstInstalmentDate,
        initiationFee: loan.initiationFee,
        monthlyAdminFee: loan.monthlyAdminFee,
      );
    } catch (e) {
      debugPrint('Error triggering loan notifications: $e');
      rethrow;
    }
  }
}
