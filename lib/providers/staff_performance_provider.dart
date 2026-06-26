import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/loan.dart';
import '../models/payment.dart';
import '../services/loan_calculation_service.dart';

class StaffPerformance {
  final String staffName;
  final int groupsCreated;
  final int loansDisbursedCount;
  final double loansDisbursedValue;
  final double expectedCollections;
  final double actualCollections;
  final double collectionRate;
  final double totalArrears;

  const StaffPerformance({
    required this.staffName,
    required this.groupsCreated,
    required this.loansDisbursedCount,
    required this.loansDisbursedValue,
    required this.expectedCollections,
    required this.actualCollections,
    required this.collectionRate,
    required this.totalArrears,
  });
}

class StaffPerformanceProvider with ChangeNotifier {
  List<StaffPerformance> _staffPerformances = [];

  List<StaffPerformance> get staffPerformances => _staffPerformances;

  List<StaffPerformance> get topPerformers {
    final list = List<StaffPerformance>.from(_staffPerformances);
    list.sort((a, b) => b.collectionRate.compareTo(a.collectionRate));
    return list;
  }

  List<StaffPerformance> get overdueStaff {
    final list = _staffPerformances.where((s) => s.totalArrears > 0).toList();
    list.sort((a, b) => b.totalArrears.compareTo(a.totalArrears));
    return list;
  }

  void calculatePerformance({
    required List<GroupModel> groups,
    required List<LoanModel> loans,
    required List<PaymentModel> payments,
  }) {
    final Map<String, _StaffMetrics> metrics = {};

    for (var group in groups) {
      // Use dfName as the primary staff identifier for the group, fallback to creatorName
      final staffName = group.dfName ?? group.creatorName ?? 'Unknown Staff';
      
      metrics.putIfAbsent(staffName, () => _StaffMetrics(name: staffName));
      metrics[staffName]!.groupsCreated++;

      final groupLoans = loans.where((l) => l.groupId == group.id).toList();
      for (var loan in groupLoans) {
        metrics[staffName]!.loansDisbursedCount++;
        metrics[staffName]!.loansDisbursedValue += loan.amount;

        // Calculate expected collections (Principal + Interest)
        final expected = loan.monthlyPayment * loan.durationMonths;
        metrics[staffName]!.expectedCollections += expected;

        // Sum actual collections for this loan
        final loanPayments = payments.where((p) => p.loanId == loan.id).toList();
        final collected = loanPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
        metrics[staffName]!.actualCollections += collected;

        // Calculate arrears for this loan using LoanCalculationService
        final arrears = LoanCalculationService.calculateArrears(loan, loanPayments);
        metrics[staffName]!.totalArrears += arrears;
      }
    }

    _staffPerformances = metrics.values.map((m) {
      final rate = m.expectedCollections > 0 
          ? (m.actualCollections / m.expectedCollections) * 100 
          : 0.0;
      
      return StaffPerformance(
        staffName: m.name,
        groupsCreated: m.groupsCreated,
        loansDisbursedCount: m.loansDisbursedCount,
        loansDisbursedValue: m.loansDisbursedValue,
        expectedCollections: m.expectedCollections,
        actualCollections: m.actualCollections,
        collectionRate: rate,
        totalArrears: m.totalArrears,
      );
    }).toList();

    notifyListeners();
  }
}

class _StaffMetrics {
  final String name;
  int groupsCreated = 0;
  int loansDisbursedCount = 0;
  double loansDisbursedValue = 0;
  double expectedCollections = 0;
  double actualCollections = 0;
  double totalArrears = 0;

  _StaffMetrics({required this.name});
}
