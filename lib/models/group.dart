class GroupModel {
  final String id;
  final String referenceNumber;
  final String name;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.referenceNumber,
    required this.name,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      referenceNumber: json['reference_number'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'reference_number': referenceNumber,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
