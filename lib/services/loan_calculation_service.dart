import '../models/loan.dart';
import '../models/payment.dart';

class LoanCalculationService {
  // Standard admin fee (R65) used when loan.monthlyAdminFee is null
  static const double defaultAdminFee = 65.0;
  // Standard penalty fee (R59) used when loan.penaltyFee is null/0
  static const double defaultPenaltyFee = 59.0;

  /// Returns the full expected monthly amount (monthly instalment + admin fee).
  /// The admin fee is ALWAYS included.
  static double expectedMonthlyAmount(LoanModel loan) {
    return loan.monthlyPayment + (loan.monthlyAdminFee ?? defaultAdminFee);
  }

  /// Returns the effective penalty fee value, defaulting to standard if not set.
  static double effectivePenaltyFee(LoanModel loan) {
    return (loan.penaltyFee ?? 0) > 0 ? loan.penaltyFee! : defaultPenaltyFee;
  }

  /// Number of full monthly instalments that should already have been paid
  /// based on the loan's first payment date and the current date.
  /// For loans with a grace period, instalments are only counted from the
  /// `firstPaymentDate` (which sits at the end of the grace period).
  static int instalmentsDue(LoanModel loan, {DateTime? now}) {
    final anchor = loan.effectiveFirstPaymentDate;
    if (anchor == null) return 0;
    final current = now ?? DateTime.now();
    int count = 0;
    for (int i = 0; i < loan.durationMonths; i++) {
      final dueDate = DateTime(
        anchor.year,
        anchor.month + i,
        anchor.day,
      );
      if (current.isAfter(dueDate) || current.isAtSameMomentAs(dueDate)) {
        count = i + 1;
      } else {
        break;
      }
    }
    return count;
  }

  /// Total amount that should have been paid by now (admin fee included).
  static double totalExpected(LoanModel loan, {DateTime? now}) {
    final due = instalmentsDue(loan, now: now);
    return expectedMonthlyAmount(loan) * due;
  }

  /// Sum of all payments ever made against this loan.
  static double totalPaidAmount(List<PaymentModel> payments) {
    return payments.fold(0.0, (sum, p) => sum + p.amountPaid);
  }

  /// Arrears amount = expected total - paid total. Always positive.
  /// Returns 0 when the loan has not yet started (no instalments due).
  static double calculateArrears(
    LoanModel loan,
    List<PaymentModel> payments, {
    DateTime? now,
  }) {
    if (loan.firstInstalmentDate == null) return 0.0;
    final due = instalmentsDue(loan, now: now);
    if (due == 0) return 0.0;
    final expected = totalExpected(loan, now: now);
    final paid = totalPaidAmount(payments);
    final arrears = expected - paid;
    return arrears > 0 ? arrears : 0.0;
  }

  /// Number of months the client is currently behind. Each full
  /// expected-monthly shortfall counts as one month in arrears.
  static int monthsInArrears(
    LoanModel loan,
    List<PaymentModel> payments, {
    DateTime? now,
  }) {
    final arrears = calculateArrears(loan, payments, now: now);
    final monthly = expectedMonthlyAmount(loan);
    if (monthly <= 0) return 0;
    if (arrears <= 0) return 0;
    return (arrears / monthly).ceil();
  }

  /// True when the client is behind on at least one instalment.
  static bool isInArrears(
    LoanModel loan,
    List<PaymentModel> payments, {
    DateTime? now,
  }) {
    return calculateArrears(loan, payments, now: now) > 0;
  }

  /// Arrears fee = penalty fee × number of months in arrears.
  /// Penalty continues to apply for as long as the loan remains
  /// in arrears (until the loan is settled / closed).
  static double arrearsFee(
    LoanModel loan,
    List<PaymentModel> payments, {
    DateTime? now,
  }) {
    if (loan.penaltyFee == null || loan.penaltyFee == 0) {
      // Still apply default penalty when arrears exist
      final months = monthsInArrears(loan, payments, now: now);
      if (months == 0) return 0.0;
      return defaultPenaltyFee * months;
    }
    final months = monthsInArrears(loan, payments, now: now);
    return months == 0 ? 0.0 : loan.penaltyFee! * months;
  }

  /// Alias retained for backwards compatibility with the rest of the
  /// codebase. Equivalent to [arrearsFee].
  static double calculateAppliedPenalty(
    LoanModel loan,
    List<PaymentModel> payments, {
    DateTime? now,
  }) {
    return arrearsFee(loan, payments, now: now);
  }

  /// Calculates the current balance of a loan.
  ///
  /// Formula (same for imported and system-created loans):
  ///   (monthlyPayment + adminFee) × duration
  ///   + initiationFee
  ///   + arrearsFee
  ///   - totalPaid
  static double calculateBalance(LoanModel loan, List<PaymentModel> payments) {
    final totalPaid = totalPaidAmount(payments);
    final penalty = arrearsFee(loan, payments);

    final totalLiability =
        expectedMonthlyAmount(loan) * loan.durationMonths +
        (loan.initiationFee ?? 0) +
        penalty;

    final balance = totalLiability - totalPaid;

    return balance < 0.01 ? 0.0 : balance;
  }

  /// Checks if a loan is fully settled.
  static bool isSettled(LoanModel loan, List<PaymentModel> payments) {
    return calculateBalance(loan, payments) <= 0.01;
  }

  /// Returns the next payment due date for a loan.
  static DateTime? nextPaymentDate(LoanModel loan) {
    final anchor = loan.effectiveFirstPaymentDate;
    if (anchor == null) return null;
    final now = DateTime.now();
    for (int i = 0; i < loan.durationMonths; i++) {
      final dueDate = DateTime(
        anchor.year,
        anchor.month + i,
        anchor.day,
      );
      if (dueDate.isAfter(now)) return dueDate;
    }
    return null; // Loan term ended
  }
}
