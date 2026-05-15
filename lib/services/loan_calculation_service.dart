import '../models/loan.dart';
import '../models/payment.dart';

class LoanCalculationService {
  /// Calculates the total penalty fee applied to a loan based on payment timing.
  /// A penalty is applied for each month where the cumulative payments by the due date
  /// are less than the expected cumulative amount for that month.
  static double calculateAppliedPenalty(
    LoanModel loan,
    List<PaymentModel> payments,
  ) {
    if (loan.penaltyFee == null || loan.penaltyFee == 0) return 0.0;
    if (loan.firstInstalmentDate == null) return 0.0;

    double totalPenalty = 0.0;
    final now = DateTime.now();

    // Sort payments by date to simplify cumulative calculations
    final sortedPayments = List<PaymentModel>.from(payments)
      ..sort((a, b) => a.datePaid.compareTo(b.datePaid));

    for (int i = 0; i < loan.durationMonths; i++) {
      // Calculate due date for the i-th installment (0-indexed)
      final dueDate = DateTime(
        loan.firstInstalmentDate!.year,
        loan.firstInstalmentDate!.month + i,
        loan.firstInstalmentDate!.day,
      );

      // If the due date hasn't passed yet, don't check for penalty
      if (now.isBefore(dueDate)) break;

      // Expected cumulative amount by this due date
      final expectedCumulative = loan.monthlyPayment * (i + 1);

      // Total paid on or before this due date
      final paidByDueDate = sortedPayments
          .where(
            (p) => p.datePaid.isBefore(dueDate.add(const Duration(days: 1))),
          ) // inclusive of the day
          .fold(0.0, (sum, p) => sum + p.amountPaid);

      if (paidByDueDate < expectedCumulative - 0.01) {
        // 0.01 for floating point safety
        totalPenalty += loan.penaltyFee!;
      }
    }

    return totalPenalty;
  }

  /// Calculates the current balance of a loan.
  static double calculateBalance(LoanModel loan, List<PaymentModel> payments) {
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amountPaid);

    final appliedPenalty = calculateAppliedPenalty(loan, payments);
    final openingAmount = loan.openingAmount ?? 0.0;

    // Total liability is (Monthly Repayment * Term) + Opening Amount + Late Penalties
    // The monthly installment already includes the principal, interest, admin fees, and amortized initiation fee.
    final totalLiability =
        (loan.monthlyPayment * loan.durationMonths) +
        openingAmount +
        appliedPenalty;

    final balance = totalLiability - totalPaid;

    // Prevent over-calculation resulting in negative balances
    return balance < 0.01 ? 0.0 : balance;
  }

  /// Checks if a loan is fully settled.
  static bool isSettled(LoanModel loan, List<PaymentModel> payments) {
    return calculateBalance(loan, payments) <= 0.01;
  }

  /// Calculates total arrears for a loan (amount overdue from missed/partial instalments).
  static double calculateArrears(LoanModel loan, List<PaymentModel> payments) {
    if (loan.firstInstalmentDate == null) return 0.0;
    final now = DateTime.now();
    final sortedPayments = List<PaymentModel>.from(payments)
      ..sort((a, b) => a.datePaid.compareTo(b.datePaid));

    // How many instalments should have been paid by now
    int instalmentsDue = 0;
    for (int i = 0; i < loan.durationMonths; i++) {
      final dueDate = DateTime(
        loan.firstInstalmentDate!.year,
        loan.firstInstalmentDate!.month + i,
        loan.firstInstalmentDate!.day,
      );
      if (now.isAfter(dueDate) || now.isAtSameMomentAs(dueDate)) {
        instalmentsDue = i + 1;
      } else {
        break;
      }
    }

    final expectedPaid = loan.monthlyPayment * instalmentsDue;
    final totalPaid = sortedPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    final arrears = expectedPaid - totalPaid;
    return arrears > 0 ? arrears : 0.0;
  }

  /// Returns the next payment due date for a loan.
  static DateTime? nextPaymentDate(LoanModel loan) {
    if (loan.firstInstalmentDate == null) return null;
    final now = DateTime.now();
    for (int i = 0; i < loan.durationMonths; i++) {
      final dueDate = DateTime(
        loan.firstInstalmentDate!.year,
        loan.firstInstalmentDate!.month + i,
        loan.firstInstalmentDate!.day,
      );
      if (dueDate.isAfter(now)) return dueDate;
    }
    return null; // Loan term ended
  }
}
