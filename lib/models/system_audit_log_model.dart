class SystemAuditLogModel {
  final String id;
  final String actionType;
  final String performedBy;
  final DateTime timestamp;
  final String affectedEntity;
  final String description;

  SystemAuditLogModel({
    required this.id,
    required this.actionType,
    required this.performedBy,
    required this.timestamp,
    required this.affectedEntity,
    required this.description,
  });

  factory SystemAuditLogModel.fromJson(Map<String, dynamic> json) {
    return SystemAuditLogModel(
      id: json['id'] as String,
      actionType: json['action_type'] as String,
      performedBy: json['performed_by'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      affectedEntity: json['affected_entity'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action_type': actionType,
      'performed_by': performedBy,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'affected_entity': affectedEntity,
      'description': description,
    };
  }
}
