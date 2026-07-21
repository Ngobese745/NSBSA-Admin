class LoanModel {
  final String id;
  final String groupId;
  final String? vendorId;
  final double amount;
  final int durationMonths;
  final double monthlyPayment;
  final String status;
  final double? initiationFee;
  final double? monthlyAdminFee;
  final double? penaltyFee;
  final double? openingAmount;
  final double? interestRate;
  final DateTime? firstInstalmentDate;
  final DateTime? firstPaymentDate;
  final DateTime? disbursedDate;
  final bool gracePeriodEnabled;
  final int? gracePeriodMonths;
  final String? vendorName;
  final String? loanType;
  final DateTime createdAt;

  LoanModel({
    required this.id,
    required this.groupId,
    this.vendorId,
    this.vendorName,
    this.loanType,
    required this.amount,
    required this.durationMonths,
    required this.monthlyPayment,
    required this.status,
    this.initiationFee,
    this.monthlyAdminFee,
    this.penaltyFee,
    this.openingAmount,
    this.interestRate,
    this.firstInstalmentDate,
    this.firstPaymentDate,
    this.disbursedDate,
    this.gracePeriodEnabled = false,
    this.gracePeriodMonths,
    required this.createdAt,
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    // Handle nested vendor name from Supabase join: vendors(name)
    String? vName;
    if (json['vendors'] != null && json['vendors'] is Map) {
      vName = json['vendors']['name'];
    } else if (json['vendor_name'] != null) {
      vName = json['vendor_name'];
    }

    return LoanModel(
      id: json['id'],
      groupId: json['group_id'],
      vendorId: json['vendor_id'],
      vendorName: vName,
      amount: (json['amount'] as num).toDouble(),
      durationMonths: json['duration_months'],
      monthlyPayment: (json['monthly_payment'] as num).toDouble(),
      status: json['status'],
      initiationFee: json['initiation_fee'] != null
          ? (json['initiation_fee'] as num).toDouble()
          : null,
      monthlyAdminFee: json['monthly_admin_fee'] != null
          ? (json['monthly_admin_fee'] as num).toDouble()
          : null,
      penaltyFee: json['penalty_fee'] != null
          ? (json['penalty_fee'] as num).toDouble()
          : null,
      openingAmount: json['opening_amount'] != null
          ? (json['opening_amount'] as num).toDouble()
          : null,
      interestRate: json['interest_rate'] != null
          ? (json['interest_rate'] as num).toDouble()
          : null,
      loanType: json['loan_type'],
      firstInstalmentDate: json['first_instalment_date'] != null
          ? DateTime.parse(json['first_instalment_date'])
          : null,
      firstPaymentDate: json['first_payment_date'] != null
          ? DateTime.parse(json['first_payment_date'])
          : null,
      disbursedDate: json['disbursed_date'] != null
          ? DateTime.parse(json['disbursed_date'])
          : null,
      gracePeriodEnabled: json['grace_period_enabled'] == true,
      gracePeriodMonths: json['grace_period_months'] as int?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'group_id': groupId,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'loan_type': loanType,
      'amount': amount,
      'duration_months': durationMonths,
      'monthly_payment': monthlyPayment,
      'status': status,
      'initiation_fee': initiationFee,
      'monthly_admin_fee': monthlyAdminFee,
      'penalty_fee': penaltyFee,
      'opening_amount': openingAmount,
      'interest_rate': interestRate,
      'first_instalment_date': firstInstalmentDate?.toIso8601String(),
      'first_payment_date': firstPaymentDate?.toIso8601String(),
      'disbursed_date': disbursedDate?.toIso8601String(),
      'grace_period_enabled': gracePeriodEnabled,
      'grace_period_months': gracePeriodMonths,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  /// Returns the effective first-payment date.
  /// Falls back to firstInstalmentDate when firstPaymentDate is not set.
  DateTime? get effectiveFirstPaymentDate =>
      firstPaymentDate ?? firstInstalmentDate;

  /// True if the loan is currently in its grace period.
  /// The grace period ends on the first payment date.
  bool get isInGracePeriod {
    if (!gracePeriodEnabled) return false;
    final start = firstPaymentDate;
    if (start == null) return false;
    final now = DateTime.now();
    return now.isBefore(DateTime(start.year, start.month, start.day));
  }
}
