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
  final DateTime? firstInstalmentDate;
  final DateTime createdAt;

  LoanModel({
    required this.id,
    required this.groupId,
    this.vendorId,
    required this.amount,
    required this.durationMonths,
    required this.monthlyPayment,
    required this.status,
    this.initiationFee,
    this.monthlyAdminFee,
    this.penaltyFee,
    this.openingAmount,
    this.firstInstalmentDate,
    required this.createdAt,
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['id'],
      groupId: json['group_id'],
      vendorId: json['vendor_id'],
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
      firstInstalmentDate: json['first_instalment_date'] != null
          ? DateTime.parse(json['first_instalment_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'group_id': groupId,
      'vendor_id': vendorId,
      'amount': amount,
      'duration_months': durationMonths,
      'monthly_payment': monthlyPayment,
      'status': status,
      'initiation_fee': initiationFee,
      'monthly_admin_fee': monthlyAdminFee,
      'penalty_fee': penaltyFee,
      'opening_amount': openingAmount,
      'first_instalment_date': firstInstalmentDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
