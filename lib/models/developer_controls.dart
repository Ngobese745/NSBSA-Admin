/// Models for developer-managed system banners, feature flags, and audit log.

class SystemBannerModel {
  final String id;
  final String bannerType;
  final String title;
  final String message;
  final String severity;
  final bool isEnabled;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SystemBannerModel({
    required this.id,
    required this.bannerType,
    required this.title,
    required this.message,
    required this.severity,
    required this.isEnabled,
    required this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SystemBannerModel.fromJson(Map<String, dynamic> json) {
    return SystemBannerModel(
      id: json['id'] as String,
      bannerType: json['banner_type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String? ?? 'warning',
      isEnabled: json['is_enabled'] as bool? ?? false,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'banner_type': bannerType,
    'title': title,
    'message': message,
    'severity': severity,
    'is_enabled': isEnabled,
    'starts_at': startsAt.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Active for display: enabled and within [startsAt, endsAt] window.
  bool isActiveNow(DateTime now) {
    if (!isEnabled) return false;
    if (now.isBefore(startsAt)) return false;
    if (endsAt != null && !now.isBefore(endsAt!)) return false;
    return true;
  }
}

class FeatureFlagModel {
  final String featureKey;
  final bool enabled;
  final String label;
  final int sortOrder;
  final DateTime updatedAt;
  final String? updatedBy;
  final List<String> allowedRoles;
  final List<String> allowedUsers;

  const FeatureFlagModel({
    required this.featureKey,
    required this.enabled,
    required this.label,
    required this.sortOrder,
    required this.updatedAt,
    this.updatedBy,
    this.allowedRoles = const [],
    this.allowedUsers = const [],
  });

  factory FeatureFlagModel.fromJson(Map<String, dynamic> json) {
    return FeatureFlagModel(
      featureKey: json['feature_key'] as String,
      enabled: json['enabled'] as bool? ?? true,
      label: json['label'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
      allowedRoles: _parseStringList(json['allowed_roles']),
      allowedUsers: _parseStringList(json['allowed_users']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  FeatureFlagModel copyWith({
    bool? enabled,
    String? label,
    int? sortOrder,
    DateTime? updatedAt,
    String? updatedBy,
    List<String>? allowedRoles,
    List<String>? allowedUsers,
  }) {
    return FeatureFlagModel(
      featureKey: featureKey,
      enabled: enabled ?? this.enabled,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      allowedUsers: allowedUsers ?? this.allowedUsers,
    );
  }
}

class DeveloperActionLogModel {
  final String id;
  final String developerId;
  final String? developerEmail;
  final String actionType;
  final String? resourceType;
  final String? resourceId;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  const DeveloperActionLogModel({
    required this.id,
    required this.developerId,
    this.developerEmail,
    required this.actionType,
    this.resourceType,
    this.resourceId,
    this.payload,
    required this.createdAt,
  });

  factory DeveloperActionLogModel.fromJson(Map<String, dynamic> json) {
    return DeveloperActionLogModel(
      id: json['id'] as String,
      developerId: json['developer_id'] as String,
      developerEmail: json['developer_email'] as String?,
      actionType: json['action_type'] as String,
      resourceType: json['resource_type'] as String?,
      resourceId: json['resource_id'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
