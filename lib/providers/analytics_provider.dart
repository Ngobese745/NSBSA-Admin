import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../services/loan_calculation_service.dart';

class AnalyticsProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<MonthlyData> _collectionTrend = [];
  List<MonthlyData> get collectionTrend => _collectionTrend;

  List<GroupPerformance> _topGroups = [];
  List<GroupPerformance> get topGroups => _topGroups;

  Map<String, double> _groupRiskScores = {}; // groupId -> score (0-100)
  Map<String, double> get groupRiskScores => _groupRiskScores;

  Map<String, double> _vendorCreditScores = {}; // vendorId -> score (0-100)
  Map<String, double> get vendorCreditScores => _vendorCreditScores;

  double _globalTotalExpected = 0.0;
  double get globalTotalExpected => _globalTotalExpected;

  double _globalTotalPaid = 0.0;
  double get globalTotalPaid => _globalTotalPaid;

  void calculateAnalytics({
    required List<GroupModel> groups,
    required List<VendorModel> vendors,
    required List<LoanModel> loans,
    required List<PaymentModel> payments,
  }) {
    _isLoading = true;
    // notifyListeners(); // Delay notify to avoid build errors if called during build

    // 1. Collection Trend (Last 6 Months)
    _collectionTrend = _calculateCollectionTrend(payments);

    // 2. Top Groups by Collection
    _calculateTopGroups(groups, vendors, loans, payments);

    // 3. Risk & Credit Scores
    _calculateScores(groups, vendors, loans, payments);

    _isLoading = false;
    notifyListeners();
  }

  List<MonthlyData> _calculateCollectionTrend(List<PaymentModel> payments) {
    final now = DateTime.now();
    final Map<String, double> monthlyTotals = {};

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final key =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
      monthlyTotals[key] = 0;
    }

    for (var p in payments) {
      final key =
          '${p.datePaid.year}-${p.datePaid.month.toString().padLeft(2, '0')}';
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = monthlyTotals[key]! + p.amountPaid;
      }
    }

    return monthlyTotals.entries
        .map((e) => MonthlyData(e.key, e.value))
        .toList();
  }

  void _calculateTopGroups(
    List<GroupModel> groups,
    List<VendorModel> vendors,
    List<LoanModel> loans,
    List<PaymentModel> payments,
  ) {
    final Map<String, double> groupCollections = {};
    
    // Create maps for faster lookup
    final Map<String, String> vendorToGroup = {
      for (var v in vendors) v.id: v.groupId
    };
    final Map<String, String> loanToGroup = {};
    for (var l in loans) {
      final groupId = vendorToGroup[l.vendorId];
      if (groupId != null) {
        loanToGroup[l.id] = groupId;
      }
    }

    for (var p in payments) {
      final groupId = loanToGroup[p.loanId];
      if (groupId != null) {
        groupCollections[groupId] = (groupCollections[groupId] ?? 0) + p.amountPaid;
      }
    }

    _topGroups = groups.map((g) {
      final collected = groupCollections[g.id] ?? 0.0;
      return GroupPerformance(g.name, collected);
    }).toList();

    _topGroups.sort((a, b) => b.collected.compareTo(a.collected));
    if (_topGroups.length > 5) _topGroups = _topGroups.sublist(0, 5);
  }

  void _calculateScores(
    List<GroupModel> groups,
    List<VendorModel> vendors,
    List<LoanModel> loans,
    List<PaymentModel> payments,
  ) {
    _vendorCreditScores = {};
    _groupRiskScores = {};
    _globalTotalExpected = 0.0;
    _globalTotalPaid = 0.0;

    for (var vendor in vendors) {
      final vendorLoans = loans.where((l) => l.vendorId == vendor.id).toList();
      if (vendorLoans.isEmpty) {
        _vendorCreditScores[vendor.id] = 100.0; // Perfect score for no loans
        continue;
      }

      double totalExpected = 0;
      double totalPaid = 0;
      int overdueCount = 0;

      for (var loan in vendorLoans) {
        final loanPayments = payments
            .where((p) => p.loanId == loan.id)
            .toList();
        final expected =
            loan.amount +
            (loan.initiationFee ?? 0) +
            ((loan.monthlyAdminFee ?? 0) * loan.durationMonths) +
            LoanCalculationService.calculateAppliedPenalty(loan, loanPayments);

        final paid = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);

        totalExpected += expected;
        totalPaid += paid;
        _globalTotalExpected += expected;
        _globalTotalPaid += paid;

        // Simple overdue check: if balance > 0 and loan is old
        if (expected - paid > 10) {
          overdueCount++;
        }
      }

      double repaymentRate = totalExpected > 0
          ? (totalPaid / totalExpected)
          : 1.0;
      double score = (repaymentRate * 80) + (overdueCount > 0 ? 0 : 20);
      _vendorCreditScores[vendor.id] = score.clamp(0, 100);
    }

    // Group Risk (Average of member scores)
    for (var group in groups) {
      final groupVendors = vendors.where((v) => v.groupId == group.id).toList();
      if (groupVendors.isEmpty) {
        _groupRiskScores[group.id] = 100.0;
        continue;
      }

      double sumScores = 0;
      for (var v in groupVendors) {
        sumScores += _vendorCreditScores[v.id] ?? 100.0;
      }
      _groupRiskScores[group.id] = sumScores / groupVendors.length;
    }
  }
}

class MonthlyData {
  final String month;
  final double amount;
  MonthlyData(this.month, this.amount);
}

class GroupPerformance {
  final String name;
  final double collected;
  GroupPerformance(this.name, this.collected);
}
