class GroupModel {
  final String id;
  final String referenceNumber;
  final String name;
  final String? centerId;
  final DateTime createdAt;

  final String? dfId;
  final String? dfName;
  final String? creatorId;
  final String? creatorName;

  GroupModel({
    required this.id,
    required this.referenceNumber,
    required this.name,
    this.centerId,
    required this.createdAt,
    this.dfId,
    this.dfName,
    this.creatorId,
    this.creatorName,
  });

  /// Placeholder when a group cannot be resolved (lists, lookups).
  factory GroupModel.unknown() {
    return GroupModel(
      id: '',
      referenceNumber: '',
      name: 'Unknown Group',
      createdAt: DateTime.now(),
    );
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      referenceNumber: json['reference_number'],
      name: json['name'],
      centerId: json['center_id'],
      createdAt: DateTime.parse(json['created_at']),
      dfId: json['df_id'],
      dfName: json['df_name'],
      creatorId: json['creator_id'],
      creatorName: json['creator_name'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'reference_number': referenceNumber,
      'name': name,
      'center_id': centerId,
      'created_at': createdAt.toIso8601String(),
      'df_id': dfId,
      'df_name': dfName,
      'creator_id': creatorId,
      'creator_name': creatorName,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
