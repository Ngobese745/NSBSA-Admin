import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../services/loan_calculation_service.dart';

class AnalyticsProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<MonthlyTrend> _monthlyTrend = [];
  List<MonthlyTrend> get monthlyTrend => _monthlyTrend;

  List<GroupPerformance> _topGroups = [];
  List<GroupPerformance> get topGroups => _topGroups;

  Map<String, double> _groupRiskScores = {}; // groupId -> score (0-100)
  Map<String, double> get groupRiskScores => _groupRiskScores;

  Map<String, double> _vendorCreditScores = {}; // vendorId -> score (0-100)
  Map<String, double> get vendorCreditScores => _vendorCreditScores;

  // DF & Centre Reporting Data
  Map<String, Map<String, double>> _dfMonthlyDisbursed = {}; // dfName -> {month: amount}
  Map<String, Map<String, double>> get dfMonthlyDisbursed => _dfMonthlyDisbursed;

  Map<String, double> _centerTotalLoans = {}; // centerId -> amount
  Map<String, double> get centerTotalLoans => _centerTotalLoans;

  Map<String, double> _dfCollectionPerformance = {}; // dfName -> rate
  Map<String, double> get dfCollectionPerformance => _dfCollectionPerformance;

  Map<String, Map<String, dynamic>> _dfPerformance = {}; // dfName -> {collectionRate: double, activeLoans: int}
  Map<String, Map<String, dynamic>> get dfPerformance => _dfPerformance;

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

    // 1. Monthly Trend (Jan to Now)
    _monthlyTrend = _calculateMonthlyTrend(loans, payments);

    // 2. Top Groups by Collection
    _calculateTopGroups(groups, vendors, loans, payments);

    // 3. Risk & Credit Scores
    _calculateScores(groups, vendors, loans, payments);

    // 4. DF & Centre Performance
    _calculateDFCentrePerformance(groups, vendors, loans, payments);

    _isLoading = false;
    notifyListeners();
  }

  void _calculateDFCentrePerformance(
    List<GroupModel> groups,
    List<VendorModel> vendors,
    List<LoanModel> loans,
    List<PaymentModel> payments,
  ) {
    _dfMonthlyDisbursed = {};
    _centerTotalLoans = {};
    _dfCollectionPerformance = {};

    final now = DateTime.now();
    final monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Maps for faster lookup
    final Map<String, String?> groupToCenter = {for (var g in groups) g.id: g.centerId};
    final Map<String, String?> groupToDF = {for (var g in groups) g.id: g.dfName};

    for (var loan in loans) {
      final groupId = loan.groupId;
      final dfName = groupToDF[groupId] ?? 'Unassigned';
      final centerId = groupToCenter[groupId];

      // DF Monthly Disbursed
      if (loan.createdAt.year == now.year) {
        final month = monthNames[loan.createdAt.month];
        _dfMonthlyDisbursed.putIfAbsent(dfName, () => {});
        _dfMonthlyDisbursed[dfName]![month] =
            (_dfMonthlyDisbursed[dfName]![month] ?? 0) + loan.amount;
      }

      // Centre Total Loans
      if (centerId != null) {
        _centerTotalLoans[centerId] = (_centerTotalLoans[centerId] ?? 0) + loan.amount;
      }
    }

    // DF Collection Performance
    final Map<String, double> dfDisbursed = {};
    final Map<String, double> dfCollected = {};
    final Map<String, int> dfActiveLoans = {};

    for (var loan in loans) {
      final dfName = groupToDF[loan.groupId] ?? 'Unassigned';
      dfDisbursed[dfName] = (dfDisbursed[dfName] ?? 0) + loan.amount;
      
      final loanPayments = payments.where((p) => p.loanId == loan.id);
      final collected = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
      dfCollected[dfName] = (dfCollected[dfName] ?? 0) + collected;

      if (loan.status == 'Active' || loan.status == 'Overdue') {
        dfActiveLoans[dfName] = (dfActiveLoans[dfName] ?? 0) + 1;
      }
    }

    _dfPerformance = {};
    for (var df in dfDisbursed.keys) {
      final disbursed = dfDisbursed[df] ?? 0.0;
      final collected = dfCollected[df] ?? 0.0;
      final rate = disbursed > 0 ? (collected / disbursed) * 100 : 100.0;
      _dfCollectionPerformance[df] = rate;
      _dfPerformance[df] = {
        'collectionRate': rate,
        'activeLoans': dfActiveLoans[df] ?? 0,
      };
    }
  }

  List<MonthlyTrend> _calculateMonthlyTrend(
    List<LoanModel> loans,
    List<PaymentModel> payments,
  ) {
    final now = DateTime.now();
    final Map<int, double> monthlyDisbursed = {};
    final Map<int, double> monthlyCollected = {};

    // Initialize months from Jan (1) to current month
    for (int i = 1; i <= now.month; i++) {
      monthlyDisbursed[i] = 0;
      monthlyCollected[i] = 0;
    }

    // Process loans for disbursement trend
    for (var l in loans) {
      if (l.createdAt.year == now.year && l.createdAt.month <= now.month) {
        monthlyDisbursed[l.createdAt.month] =
            (monthlyDisbursed[l.createdAt.month] ?? 0) + l.amount;
      }
    }

    // Process payments for collection trend
    for (var p in payments) {
      if (p.datePaid.year == now.year && p.datePaid.month <= now.month) {
        monthlyCollected[p.datePaid.month] =
            (monthlyCollected[p.datePaid.month] ?? 0) + p.amountPaid;
      }
    }

    final List<String> monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return List.generate(now.month, (index) {
      final m = index + 1;
      return MonthlyTrend(
        monthNames[m],
        monthlyDisbursed[m] ?? 0.0,
        monthlyCollected[m] ?? 0.0,
      );
    });
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
      if (l.vendorId != null) {
        final groupId = vendorToGroup[l.vendorId];
        if (groupId != null) {
          loanToGroup[l.id] = groupId;
        }
      }
    }

    for (var p in payments) {
      final groupId = loanToGroup[p.loanId];
      if (groupId != null) {
        groupCollections[groupId] =
            (groupCollections[groupId] ?? 0) + p.amountPaid;
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
        final loanPayments = payments.where((p) => p.loanId == loan.id).toList();
        final expected =
            (loan.monthlyPayment * loan.durationMonths) +
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

      double repaymentRate = totalExpected > 0 ? (totalPaid / totalExpected) : 1.0;
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

class MonthlyTrend {
  final String month;
  final double disbursed;
  final double collected;
  MonthlyTrend(this.month, this.disbursed, this.collected);
}

class GroupPerformance {
  final String name;
  final double collected;
  GroupPerformance(this.name, this.collected);
}
