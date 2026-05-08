import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan.dart';

import '../services/cache_service.dart';

class LoanProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<LoanModel> _loans = [];
  bool _isLoading = false;

  List<LoanModel> get loans => _loans;
  bool get isLoading => _isLoading;

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
      final response = await _supabase.from('loans').select().order('created_at', ascending: false);
      _loans = (response as List).map((e) => LoanModel.fromJson(e)).toList();
      
      await CacheService.saveCache('loans_cache', _loans.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error fetching loans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LoanModel> addLoan(LoanModel loan) async {
    try {
      final response = await _supabase.from('loans').insert(loan.toJson()).select().single();
      final newLoan = LoanModel.fromJson(response);
      
      _loans.insert(0, newLoan);
      notifyListeners();
      
      // Background cache sync
      CacheService.saveCache('loans_cache', _loans.map((e) => e.toJson()).toList());
      
      return newLoan;
    } catch (e) {
      debugPrint('Error adding loan: $e');
      rethrow;
    }
  }

  Future<List<LoanModel>> fetchLoansByGroup(String groupId) async {
    try {
      final response = await _supabase
          .from('loans')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => LoanModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching group loans: $e');
      return [];
    }
  }
  Future<void> updateLoan(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _supabase.from('loans').update(updates).eq('id', id).select().single();
      final updatedLoan = LoanModel.fromJson(response);
      
      final index = _loans.indexWhere((l) => l.id == id);
      if (index != -1) {
        _loans[index] = updatedLoan;
        notifyListeners();
        CacheService.saveCache('loans_cache', _loans.map((e) => e.toJson()).toList());
      }
    } catch (e) {
      debugPrint('Error updating loan: $e');
      rethrow;
    }
  }

  Future<void> deleteLoan(String id) async {
    try {
      await _supabase.from('loans').delete().eq('id', id);
      
      _loans.removeWhere((l) => l.id == id);
      notifyListeners();
      CacheService.saveCache('loans_cache', _loans.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error deleting loan: $e');
      rethrow;
    }
  }
}
