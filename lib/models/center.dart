class CenterModel {
  final String id;
  final String name;
  final String referenceNumber;
  final DateTime createdAt;

  CenterModel({
    required this.id,
    required this.name,
    required this.referenceNumber,
    required this.createdAt,
  });

  factory CenterModel.fromJson(Map<String, dynamic> json) {
    return CenterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      referenceNumber: json['reference_number'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'reference_number': referenceNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
