/// Determines the applicable interest rate based on the predefined NSBSA
/// rate table keyed by loan amount and duration in months.
///
/// Rates are expressed as decimals (e.g. 0.1033 for 10.33%).
class LoanInterestService {
  LoanInterestService._();

  /// Rate table: loanAmount → (durationMonths → rate as decimal).
  static const Map<int, Map<int, double>> _rateTable = {
    1000: {6: 0.1033, 4: 0.0750, 3: 0.1347},
    1500: {6: 0.0760, 4: 0.0667, 3: 0.0967},
    2000: {6: 0.0608, 4: 0.0550, 3: 0.0772},
    2500: {6: 0.0525, 4: 0.0520, 3: 0.0659},
    3000: {6: 0.0467, 4: 0.0493, 3: 0.0583},
  };

  static const List<int> _amountBrackets = [1000, 1500, 2000, 2500, 3000];
  static const List<int> _supportedDurations = [3, 4, 6];

  /// Returns the exact interest rate (as decimal) for a given loan amount and
  /// duration, or `null` if no exact match exists.
  static double? getExactRate(double amount, int durationMonths) {
    final bracket = _amountBrackets.firstWhere(
      (b) => b == amount.round(),
      orElse: () => -1,
    );
    if (bracket == -1) return null;
    final rates = _rateTable[bracket];
    if (rates == null) return null;
    return rates[durationMonths];
  }

  /// Finds the nearest supported amount bracket.
  static int nearestAmountBracket(double amount) {
    final rounded = amount.round();
    return _amountBrackets.reduce(
      (a, b) => (a - rounded).abs() < (b - rounded).abs() ? a : b,
    );
  }

  /// Finds the nearest supported duration.
  static int nearestDuration(int months) {
    return _supportedDurations.reduce(
      (a, b) => (a - months).abs() < (b - months).abs() ? a : b,
    );
  }

  /// Returns the best available rate for the given amount and duration.
  /// If the exact combination exists, returns it.
  /// Otherwise falls back to the nearest amount bracket and/or duration.
  /// Returns `null` only if the table is empty (should never happen).
  static double? getRate(double amount, int durationMonths) {
    // Exact match
    final exact = getExactRate(amount, durationMonths);
    if (exact != null) return exact;

    // Nearest amount bracket + exact duration
    final nearAmount = nearestAmountBracket(amount);
    final nearAmountRate = _rateTable[nearAmount]?[durationMonths];
    if (nearAmountRate != null) return nearAmountRate;

    // Exact amount + nearest duration
    final nearDuration = nearestDuration(durationMonths);
    final exactAmount = getExactRate(amount, nearDuration);
    if (exactAmount != null) return exactAmount;

    // Nearest amount + nearest duration
    return _rateTable[nearAmount]?[nearDuration];
  }

  /// Human-readable explanation for the tooltip.
  static String describeRate(double amount, int durationMonths) {
    final exact = getExactRate(amount, durationMonths);
    if (exact != null) {
      return 'Rate of ${_formatPct(exact)} applies to R${_fmt(amount)} '
          'over $durationMonths months.';
    }
    final bracket = nearestAmountBracket(amount);
    final dur = nearestDuration(durationMonths);
    final rate = _rateTable[bracket]?[dur];
    if (rate == null) return 'No matching rate found.';
    final parts = <String>[];
    if (bracket != amount.round()) {
      parts.add('nearest amount bracket R$_fmt(bracket)');
    }
    if (dur != durationMonths) {
      parts.add('nearest duration $dur months');
    }
    return 'Using ${_formatPct(rate)} (${parts.join(', ')}) '
        'for R$_fmt(amount) over $durationMonths months.';
  }

  /// Returns all available (rate, amountBracket) entries for a given duration,
  /// sorted from highest rate to lowest.
  static List<MapEntry<double, int>> getRatesForDuration(int durationMonths) {
    final entries = <MapEntry<double, int>>[];
    for (final entry in _rateTable.entries) {
      final rate = entry.value[durationMonths];
      if (rate != null) {
        entries.add(MapEntry(rate, entry.key));
      }
    }
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  /// Whether the combination is an exact table match.
  static bool isExactMatch(double amount, int durationMonths) {
    return getExactRate(amount, durationMonths) != null;
  }

  // ── Calculations ────────────────────────────────────────────────────────

  /// Total repayment = amount + (amount × rate).
  static double calculateTotalRepayment(double amount, double rate) {
    return amount + (amount * rate);
  }

  /// Monthly payment based on flat (non-compounding) interest spread evenly.
  static double calculateMonthlyPayment(
      double amount, double rate, int months) {
    final total = calculateTotalRepayment(amount, rate);
    return total / months;
  }

  /// The interest amount only (total – principal).
  static double calculateInterestAmount(double amount, double rate) {
    return amount * rate;
  }

  // ── Formatting helpers ──────────────────────────────────────────────────

  static String _formatPct(double rate) => '${(rate * 100).toStringAsFixed(2)}%';
  static String _fmt(double v) => v.toStringAsFixed(0);
}
