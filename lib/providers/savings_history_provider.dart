import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/savings_history.dart';
import '../services/realtime_service.dart';

class SavingsHistoryProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<SavingsHistoryModel> _history = [];
  bool _isLoading = false;
  String? _currentVendorId;

  List<SavingsHistoryModel> get history => _history;
  bool get isLoading => _isLoading;

  SavingsHistoryProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'savings_history',
      onData: (payload) {
        final event = payload.eventType;
        final data = payload.newRecord;

        if (event == PostgresChangeEvent.insert) {
          final newEntry = SavingsHistoryModel.fromJson(data);
          // Only add if it's for the vendor we are currently looking at
          if (_currentVendorId != null && newEntry.vendorId == _currentVendorId) {
            if (!_history.any((e) => e.id == newEntry.id)) {
              _history.insert(0, newEntry);
              notifyListeners();
            }
          }
        }
      },
    );
  }

  Future<void> fetchHistoryByVendor(String vendorId) async {
    _currentVendorId = vendorId;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('savings_history')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      _history = (response as List)
          .map((e) => SavingsHistoryModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching savings history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHistoryEntry(SavingsHistoryModel entry) async {
    try {
      final response = await _supabase
          .from('savings_history')
          .insert(entry.toJson())
          .select()
          .single();

      final newEntry = SavingsHistoryModel.fromJson(response);
      if (_currentVendorId == newEntry.vendorId) {
        _history.insert(0, newEntry);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding savings history: $e');
      rethrow;
    }
  }

  Future<void> addEntry({
    required String vendorId,
    required double amount,
    required String type,
    required String updatedBy,
    double? previousBalance,
    double? newBalance,
  }) async {
    final entry = SavingsHistoryModel(
      id: '',
      vendorId: vendorId,
      amount: amount,
      previousBalance: previousBalance ?? 0,
      newBalance: newBalance ?? 0,
      actionType: type,
      updatedBy: updatedBy,
      createdAt: DateTime.now(),
    );
    await addHistoryEntry(entry);
  }
}
