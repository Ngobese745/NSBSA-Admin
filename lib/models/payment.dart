class PaymentModel {
  final String id;
  final String loanId;
  final String? groupPaymentId;
  final double amountPaid;
  final double? balanceRemaining;
  final String? paymentMethod;
  final DateTime datePaid;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.loanId,
    this.groupPaymentId,
    required this.amountPaid,
    this.balanceRemaining,
    this.paymentMethod,
    required this.datePaid,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'],
      loanId: json['loan_id'],
      groupPaymentId: json['group_payment_id'],
      amountPaid: (json['amount_paid'] as num).toDouble(),
      balanceRemaining: json['balance_remaining'] != null 
          ? (json['balance_remaining'] as num).toDouble() 
          : null,
      paymentMethod: json['payment_method'],
      datePaid: DateTime.parse(json['date_paid']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'loan_id': loanId,
      'amount_paid': amountPaid,
      'date_paid': datePaid.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (groupPaymentId != null) {
      map['group_payment_id'] = groupPaymentId;
    }
    final br = balanceRemaining;
    if (br != null) {
      map['balance_remaining'] = br;
    }
    if (paymentMethod != null) {
      map['payment_method'] = paymentMethod;
    }
    return map;
  }
}
