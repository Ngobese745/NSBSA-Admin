import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';
import '../models/group_payment.dart';
import '../models/loan.dart';
import '../services/cache_service.dart';
import '../services/loan_calculation_service.dart';
import '../services/system_audit_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';
import '../services/offline_queue_service.dart';
import '../services/connectivity_service.dart';

import 'package:intl/intl.dart';
import '../services/communication_service.dart';

class PaymentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<PaymentModel> _payments = [];
  bool _isLoading = false;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;

  PaymentProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'payments',
      onData: (payload) {
        final event = payload.eventType;
        final data = payload.newRecord;
        final oldData = payload.oldRecord;

        if (event == PostgresChangeEvent.insert) {
          final newPayment = PaymentModel.fromJson(data);
          if (!_payments.any((p) => p.id == newPayment.id)) {
            _payments.insert(0, newPayment);
            _syncCacheAndNotify();
          }
        } else if (event == PostgresChangeEvent.update) {
          final updatedPayment = PaymentModel.fromJson(data);
          final index = _payments.indexWhere((p) => p.id == updatedPayment.id);
          if (index != -1) {
            _payments[index] = updatedPayment;
            _syncCacheAndNotify();
          }
        } else if (event == PostgresChangeEvent.delete) {
          final id = oldData['id'];
          _payments.removeWhere((p) => p.id == id);
          _syncCacheAndNotify();
        }
      },
    );
  }

  void _syncCacheAndNotify() {
    CacheService.saveCache('payments_cache', _payments.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> fetchPayments({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCache('payments_cache');
      if (cachedData != null) {
        _payments = cachedData.map((e) => PaymentModel.fromJson(e)).toList();
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('payments')
          .select()
          .order('created_at', ascending: false);
      _payments = (response as List).map((e) => PaymentModel.fromJson(e)).toList();
      _syncCacheAndNotify();
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentModel> addPayment(PaymentModel payment, {LoanModel? loan}) async {
    // Optimistic Update
    _payments.insert(0, payment);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'payments',
        type: OfflineActionType.create,
        data: payment.toJson(),
        timestamp: DateTime.now(),
      ));
      return payment;
    }

    try {
      final response = await _supabase.from('payments').insert(payment.toJson()).select().single();
      final newPayment = PaymentModel.fromJson(response);

      // Replace optimistic entry
      final index = _payments.indexWhere((p) => p.id == payment.id || p.id == '');
      if (index != -1) _payments[index] = newPayment;

      // Settlement check
      if (loan != null) {
        final loanPayments = _payments.where((p) => p.loanId == loan.id).toList();
        if (LoanCalculationService.isSettled(loan, loanPayments)) {
          await _supabase.from('loans').update({'status': 'Settled'}).eq('id', loan.id);
        }
      }

      _syncCacheAndNotify();
      _logAndNotify(newPayment, loan);
      return newPayment;
    } catch (e) {
      _payments.removeWhere((p) => p.id == payment.id);
      notifyListeners();
      debugPrint('Error adding payment: $e');
      rethrow;
    }
  }

  void _logAndNotify(PaymentModel payment, LoanModel? loan) {
    SystemAuditService.logAction(
      actionType: 'RECORD_PAYMENT',
      affectedEntity: 'Loan ID: ${payment.loanId}',
      description: 'Recorded payment of R${payment.amountPaid}.',
    );
    NotificationService.notifyAdmins(
      'Payment Received',
      'A payment of R${payment.amountPaid} has been recorded.',
      type: 'FINANCIAL',
    );
    _triggerPaymentConfirmation(payment, loan);
  }

  Future<void> _triggerPaymentConfirmation(PaymentModel payment, LoanModel? loan) async {
    try {
      String? vendorId = loan?.vendorId;
      if (vendorId == null) {
        final loanData = await _supabase.from('loans').select('vendor_id').eq('id', payment.loanId).single();
        vendorId = loanData['vendor_id']?.toString();
      }
      
      if (vendorId != null) {
        final vendorData = await _supabase.from('vendors').select('name, email, phone, whatsapp_number').eq('id', vendorId).single();
        final commService = CommunicationService();
        final formattedDate = DateFormat('MMMM dd, yyyy').format(payment.datePaid);
        
        commService.sendPaymentConfirmation(
          vendorId: vendorId,
          vendorName: vendorData['name'] ?? 'Member',
          toEmail: vendorData['email'] ?? '',
          toPhone: vendorData['phone'] ?? '',
          toWhatsApp: vendorData['whatsapp_number'] ?? '',
          amount: payment.amountPaid.toStringAsFixed(2),
          transactionId: payment.id,
          date: formattedDate,
          paymentMethod: payment.paymentMethod ?? 'Electronic Transfer',
        ).catchError((e) => debugPrint('Error sending confirmation: $e'));
      }
    } catch (e) {
      debugPrint('Failed to fetch vendor or send confirmation: $e');
    }
  }

  Future<void> addGroupPayment(String groupId, List<PaymentModel> memberPayments, {List<LoanModel>? loans}) async {
    // Note: Optimistic updates for group payments are complex because of IDs.
    // For now, we perform real-time sync when online.
    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      // In offline mode, we'd need to queue each payment individually or as a batch.
      // Batching is better.
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'group_payments_batch', // Special table handled by sync service
        type: OfflineActionType.create,
        data: {
          'group_id': groupId,
          'payments': memberPayments.map((p) => p.toJson()).toList(),
        },
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final totalAmount = memberPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
      final gpResp = await _supabase.from('group_payments').insert({
        'group_id': groupId,
        'total_amount': totalAmount,
        'payment_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final groupPaymentId = gpResp['id'];
      final paymentsToInsert = memberPayments.map((p) {
        final json = p.toJson();
        json['group_payment_id'] = groupPaymentId;
        return json;
      }).toList();

      final insertedData = await _supabase.from('payments').insert(paymentsToInsert).select();
      final insertedPayments = (insertedData as List).map((e) => PaymentModel.fromJson(e)).toList();

      // Individual confirmations
      for (final payment in insertedPayments) {
        LoanModel? loan;
        try {
          loan = loans?.firstWhere((l) => l.id == payment.loanId);
        } catch (_) {}
        _triggerPaymentConfirmation(payment, loan);
      }

      await fetchPayments(forceRefresh: true);
    } catch (e) {
      debugPrint('Error adding group payment: $e');
      rethrow;
    }
  }

  Future<void> deletePayment(String id) async {
    final oldIndex = _payments.indexWhere((p) => p.id == id);
    if (oldIndex == -1) return;
    final deleted = _payments.removeAt(oldIndex);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'payments',
        type: OfflineActionType.delete,
        data: {'id': id},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('payments').delete().eq('id', id);
      _syncCacheAndNotify();
    } catch (e) {
      _payments.insert(oldIndex, deleted);
      notifyListeners();
      debugPrint('Error deleting payment: $e');
      rethrow;
    }
  }
}
