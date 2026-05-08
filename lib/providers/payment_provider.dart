import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

import '../services/cache_service.dart';

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
      final response = await _supabase.from('payments').select().order('created_at', ascending: false);
      _payments = (response as List).map((e) => PaymentModel.fromJson(e)).toList();
      
      await CacheService.saveCache('payments_cache', _payments.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentModel> addPayment(PaymentModel payment) async {
    try {
      final response = await _supabase.from('payments').insert(payment.toJson()).select().single();
      final newPayment = PaymentModel.fromJson(response);
      
      _payments.insert(0, newPayment);
      notifyListeners();
      
      CacheService.saveCache('payments_cache', _payments.map((e) => e.toJson()).toList());
      
      return newPayment;
    } catch (e) {
      debugPrint('Error adding payment: $e');
      rethrow;
    }
  }
  Future<void> deletePayment(String id) async {
    try {
      await _supabase.from('payments').delete().eq('id', id);
      
      _payments.removeWhere((p) => p.id == id);
      notifyListeners();
      CacheService.saveCache('payments_cache', _payments.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error deleting payment: $e');
      rethrow;
    }
  }
}
