import 'package:flutter_test/flutter_test.dart';
import 'package:nsbsa_admin/services/loan_calculation_service.dart';
import 'package:nsbsa_admin/models/loan.dart';
import 'package:nsbsa_admin/models/payment.dart';

void main() {
  group('LoanCalculationService', () {
    test('calculateBalance correctly calculates outstanding amount without fees', () {
      final loan = LoanModel(
        id: '1',
        vendorId: 'v1',
        amount: 1000.0,
        purpose: 'Business',
        monthlyPayment: 100.0,
        durationMonths: 10,
        status: 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final payments = [
        PaymentModel(
          id: 'p1',
          loanId: '1',
          vendorId: 'v1',
          groupId: 'g1',
          amountPaid: 200.0,
          datePaid: DateTime.now(),
          status: 'Completed',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final balance = LoanCalculationService.calculateBalance(loan, payments);
      expect(balance, 800.0);
    });

    test('calculateBalance includes initiation and admin fees', () {
      final loan = LoanModel(
        id: '2',
        vendorId: 'v1',
        amount: 1000.0,
        initiationFee: 50.0,
        monthlyAdminFee: 10.0,
        purpose: 'Business',
        monthlyPayment: 100.0,
        durationMonths: 10, // Total admin fee = 100
        status: 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Expected total: 1000 + 50 + (10 * 10) = 1150
      final payments = [
        PaymentModel(
          id: 'p2',
          loanId: '2',
          vendorId: 'v1',
          groupId: 'g1',
          amountPaid: 150.0,
          datePaid: DateTime.now(),
          status: 'Completed',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final balance = LoanCalculationService.calculateBalance(loan, payments);
      expect(balance, 1000.0); // 1150 - 150
    });
  });
}
