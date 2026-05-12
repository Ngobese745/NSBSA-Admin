class SavingsHistoryModel {
  final String id;
  final String vendorId;
  final double amount;
  final double previousBalance;
  final double newBalance;
  final String actionType;
  final String updatedBy;
  final DateTime createdAt;

  SavingsHistoryModel({
    required this.id,
    required this.vendorId,
    required this.amount,
    required this.previousBalance,
    required this.newBalance,
    required this.actionType,
    required this.updatedBy,
    required this.createdAt,
  });

  factory SavingsHistoryModel.fromJson(Map<String, dynamic> json) {
    return SavingsHistoryModel(
      id: json['id'],
      vendorId: json['vendor_id'],
      amount: (json['amount'] as num).toDouble(),
      previousBalance: (json['previous_balance'] as num).toDouble(),
      newBalance: (json['new_balance'] as num).toDouble(),
      actionType: json['action_type'],
      updatedBy: json['updated_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'vendor_id': vendorId,
      'amount': amount,
      'previous_balance': previousBalance,
      'new_balance': newBalance,
      'action_type': actionType,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
