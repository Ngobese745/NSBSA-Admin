import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';
import '../models/group_payment.dart';
import '../models/loan.dart';
import '../services/cache_service.dart';
import '../services/loan_calculation_service.dart';
import '../services/system_audit_service.dart';
import '../services/notification_service.dart';

import 'package:intl/intl.dart';
import '../services/communication_service.dart';

class PaymentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<PaymentModel> _payments = [];
  bool _isLoading = false;

  List<PaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;

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
      _payments = (response as List)
          .map((e) => PaymentModel.fromJson(e))
          .toList();

      await CacheService.saveCache(
        'payments_cache',
        _payments.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentModel> addPayment(
    PaymentModel payment, {
    LoanModel? loan,
  }) async {
    try {
      final response = await _supabase
          .from('payments')
          .insert(payment.toJson())
          .select()
          .single();
      final newPayment = PaymentModel.fromJson(response);

      _payments.insert(0, newPayment);

      // Check for loan settlement if loan model is provided
      if (loan != null) {
        final loanPayments = _payments
            .where((p) => p.loanId == loan.id)
            .toList();
        if (LoanCalculationService.isSettled(loan, loanPayments)) {
          await _supabase
              .from('loans')
              .update({'status': 'Settled'})
              .eq('id', loan.id);
        }
      }

      notifyListeners();
      CacheService.saveCache(
        'payments_cache',
        _payments.map((e) => e.toJson()).toList(),
      );
      SystemAuditService.logAction(
        actionType: 'RECORD_PAYMENT',
        affectedEntity: 'Loan ID: ${payment.loanId}',
        description: 'Recorded payment of R${payment.amountPaid}.',
      );

      await NotificationService.notifyAdmins(
        'Payment Received',
        'A payment of R${payment.amountPaid} has been recorded.',
        type: 'FINANCIAL',
      );

      // Trigger Automated Payment Confirmation
      _triggerPaymentConfirmation(newPayment, loan);

      return newPayment;
    } catch (e) {
      debugPrint('Error adding payment: $e');
      rethrow;
    }
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

  Future<void> addGroupPayment(
    String groupId,
    List<PaymentModel> memberPayments, {
    List<LoanModel>? loans,
  }) async {
    try {
      final totalAmount = memberPayments.fold(
        0.0,
        (sum, p) => sum + p.amountPaid,
      );

      // 1. Create Group Payment Record
      final groupPaymentResponse = await _supabase
          .from('group_payments')
          .insert({
            'group_id': groupId,
            'total_amount': totalAmount,
            'payment_date': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final groupPaymentId = groupPaymentResponse['id'];

      // 2. Prepare individual payments with the group_payment_id
      final paymentsToInsert = memberPayments.map((p) {
        final json = p.toJson();
        json['group_payment_id'] = groupPaymentId;
        return json;
      }).toList();

      // 3. Bulk insert individual payments
      final insertedData = await _supabase.from('payments').insert(paymentsToInsert).select();
      final insertedPayments = (insertedData as List).map((e) => PaymentModel.fromJson(e)).toList();

      // Refresh payments list locally
      await fetchPayments(forceRefresh: true);

      // Trigger Automated Payment Confirmations for each member in the group payment
      for (final payment in insertedPayments) {
        LoanModel? loan;
        try {
          loan = loans?.firstWhere((l) => l.id == payment.loanId);
        } catch (_) {}
        _triggerPaymentConfirmation(payment, loan);
      }

      // 4. Check for loan settlements
      if (loans != null) {
        for (final loan in loans) {
          final loanPayments = _payments
              .where((p) => p.loanId == loan.id)
              .toList();
          if (LoanCalculationService.isSettled(loan, loanPayments)) {
            await _supabase
                .from('loans')
                .update({'status': 'Settled'})
                .eq('id', loan.id);
          }
        }
      }

      SystemAuditService.logAction(
        actionType: 'RECORD_GROUP_PAYMENT',
        affectedEntity: 'Group ID: $groupId',
        description:
            'Recorded group payment totaling R$totalAmount for ${memberPayments.length} members.',
      );

      await NotificationService.notifyAdmins(
        'Group Payment Received',
        'Total R$totalAmount received from ${memberPayments.length} members.',
        type: 'FINANCIAL',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding group payment: $e');
      rethrow;
    }
  }

  Future<void> deletePayment(String id) async {
    try {
      await _supabase.from('payments').delete().eq('id', id);

      _payments.removeWhere((p) => p.id == id);
      notifyListeners();
      CacheService.saveCache(
        'payments_cache',
        _payments.map((e) => e.toJson()).toList(),
      );

      SystemAuditService.logAction(
        actionType: 'DELETE_PAYMENT',
        affectedEntity: 'Payment ID: $id',
        description: 'Deleted payment record from the system.',
      );
    } catch (e) {
      debugPrint('Error deleting payment: $e');
      rethrow;
    }
  }
}
