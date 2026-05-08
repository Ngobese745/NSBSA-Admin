class GroupPaymentModel {
  final String id;
  final String groupId;
  final double totalAmount;
  final DateTime paymentDate;
  final DateTime createdAt;

  GroupPaymentModel({
    required this.id,
    required this.groupId,
    required this.totalAmount,
    required this.paymentDate,
    required this.createdAt,
  });

  factory GroupPaymentModel.fromJson(Map<String, dynamic> json) {
    return GroupPaymentModel(
      id: json['id'],
      groupId: json['group_id'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['payment_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'group_id': groupId,
      'total_amount': totalAmount,
      'payment_date': paymentDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
