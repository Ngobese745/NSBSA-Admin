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

  SavingsHistoryModel copyWith({
    String? id,
    String? vendorId,
    double? amount,
    double? previousBalance,
    double? newBalance,
    String? actionType,
    String? updatedBy,
    DateTime? createdAt,
  }) {
    return SavingsHistoryModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      amount: amount ?? this.amount,
      previousBalance: previousBalance ?? this.previousBalance,
      newBalance: newBalance ?? this.newBalance,
      actionType: actionType ?? this.actionType,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SavingsHistoryModel.fromJson(Map<String, dynamic> json) {
    return SavingsHistoryModel(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (json['previous_balance'] as num?)?.toDouble() ?? 0.0,
      newBalance: (json['new_balance'] as num?)?.toDouble() ?? 0.0,
      actionType: json['action_type'] ?? 'Unknown',
      updatedBy: json['updated_by'] ?? 'System',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
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
