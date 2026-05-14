import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import '../models/payment.dart';

class SearchProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  Timer? _debounce;

  List<GroupModel> _groupResults = [];
  List<VendorModel> _vendorResults = [];
  List<LoanModel> _loanResults = [];
  List<PaymentModel> _paymentResults = [];

  bool _isSearching = false;
  String _query = '';
  String _currentContext =
      'global'; // 'global', 'groups', 'vendors', 'loans', 'payments'

  List<GroupModel> get groupResults => _groupResults;
  List<VendorModel> get vendorResults => _vendorResults;
  List<LoanModel> get loanResults => _loanResults;
  List<PaymentModel> get paymentResults => _paymentResults;

  bool get isSearching => _isSearching;
  String get query => _query;
  String get currentContext => _currentContext;

  Future<void> search(String query, {String contextType = 'global'}) async {
    _query = query;
    _currentContext = contextType;

    if (query.isEmpty) {
      clearSearch();
      return;
    }

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      _isSearching = true;
      notifyListeners();

      // 1. Parse Filters from Query
      String baseQuery = '';
      String? statusFilter;
      String? amountFilter;

      final parts = query.split(' ');
      for (var p in parts) {
        if (p.toLowerCase().startsWith('status:')) {
          statusFilter = p.substring(7); // e.g. status:overdue -> overdue
        } else if (p.toLowerCase().startsWith('amount:')) {
          amountFilter = p.substring(7); // e.g. amount:>5000 -> >5000
        } else {
          baseQuery += '$p ';
        }
      }
      baseQuery = baseQuery.trim();

      try {
        // Clear previous specific results
        _groupResults = [];
        _vendorResults = [];
        _loanResults = [];
        _paymentResults = [];

        // 2. Conditional Execution based on Context
        bool searchAll = contextType == 'global';

        if (searchAll || contextType == 'groups') {
          var q = _supabase.from('groups').select();
          if (baseQuery.isNotEmpty) {
            q = q.or(
              'name.ilike.%$baseQuery%,reference_number.ilike.%$baseQuery%',
            );
          }
          final groupResponse = await q;
          _groupResults = (groupResponse as List)
              .map((e) => GroupModel.fromJson(e))
              .toList();
        }

        if (searchAll || contextType == 'vendors') {
          var q = _supabase.from('vendors').select();
          if (baseQuery.isNotEmpty) {
            q = q.or(
              'name.ilike.%$baseQuery%,phone.ilike.%$baseQuery%,id_number.ilike.%$baseQuery%,business_type.ilike.%$baseQuery%,reference_number.ilike.%$baseQuery%',
            );
          }
          final vendorResponse = await q;
          _vendorResults = (vendorResponse as List)
              .map((e) => VendorModel.fromJson(e))
              .toList();
        }

        if (searchAll || contextType == 'loans') {
          var q = _supabase.from('loans').select();
          if (statusFilter != null) {
            q = q.ilike('status', '%$statusFilter%');
          }
          // Basic amount filter parsing: amount:>5000 or amount:<5000 or amount:5000
          if (amountFilter != null) {
            if (amountFilter.startsWith('>')) {
              final val = double.tryParse(amountFilter.substring(1));
              if (val != null) q = q.gte('amount', val);
            } else if (amountFilter.startsWith('<')) {
              final val = double.tryParse(amountFilter.substring(1));
              if (val != null) q = q.lte('amount', val);
            } else {
              final val = double.tryParse(amountFilter);
              if (val != null) q = q.eq('amount', val);
            }
          }

          final loanResponse = await q;
          _loanResults = (loanResponse as List)
              .map((e) => LoanModel.fromJson(e))
              .toList();

          // If there's a base query and no filters, filter loans locally by amount since it's hard to do complex ORs across joined tables in simple query
          if (baseQuery.isNotEmpty &&
              statusFilter == null &&
              amountFilter == null) {
            final amt = double.tryParse(baseQuery);
            if (amt != null) {
              _loanResults = _loanResults.where((l) => l.amount == amt).toList();
            } else {
              // To support searching loans by text, we might need a richer view, but for now we clear if text doesn't match
              _loanResults = _loanResults
                  .where(
                    (l) =>
                        l.status.toLowerCase().contains(baseQuery.toLowerCase()),
                  )
                  .toList();
            }
          }
        }

        if (searchAll || contextType == 'payments') {
          var q = _supabase.from('payments').select();
          // Payments don't have status, but let's allow amount filtering
          if (amountFilter != null) {
            if (amountFilter.startsWith('>')) {
              final val = double.tryParse(amountFilter.substring(1));
              if (val != null) q = q.gte('amount_paid', val);
            } else if (amountFilter.startsWith('<')) {
              final val = double.tryParse(amountFilter.substring(1));
              if (val != null) q = q.lte('amount_paid', val);
            } else {
              final val = double.tryParse(amountFilter);
              if (val != null) q = q.eq('amount_paid', val);
            }
          }

          if (baseQuery.isNotEmpty) {
            q = q.ilike('payment_method', '%$baseQuery%');
          }

          final paymentResponse = await q;
          _paymentResults = (paymentResponse as List)
              .map((e) => PaymentModel.fromJson(e))
              .toList();
        }
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        _isSearching = false;
        notifyListeners();
      }
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    _query = '';
    _groupResults = [];
    _vendorResults = [];
    _loanResults = [];
    _paymentResults = [];
    _isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
