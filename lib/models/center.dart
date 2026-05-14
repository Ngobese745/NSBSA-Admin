class CenterModel {
  final String id;
  final String name;
  final String referenceNumber;
  final DateTime createdAt;

  final String? dfId;
  final String? dfName;

  CenterModel({
    required this.id,
    required this.name,
    required this.referenceNumber,
    required this.createdAt,
    this.dfId,
    this.dfName,
  });

  factory CenterModel.fromJson(Map<String, dynamic> json) {
    return CenterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      referenceNumber: json['reference_number'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      dfId: json['df_id'],
      dfName: json['df_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'reference_number': referenceNumber,
      'created_at': createdAt.toIso8601String(),
      'df_id': dfId,
      'df_name': dfName,
    };
  }
}
