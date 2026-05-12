class LeadershipModel {
  final String id;
  final String? centerId;
  final String? groupId;
  final String vendorId;
  final String role; // Chairperson, Secretary, Treasurer
  final String? vendorName; // Optional for UI display

  LeadershipModel({
    required this.id,
    this.centerId,
    this.groupId,
    required this.vendorId,
    required this.role,
    this.vendorName,
  });

  factory LeadershipModel.fromJson(Map<String, dynamic> json) {
    return LeadershipModel(
      id: json['id'] as String,
      centerId: json['center_id'] as String?,
      groupId: json['group_id'] as String?,
      vendorId: json['vendor_id'] as String,
      role: json['role'] as String,
      vendorName: json['vendor_name'] as String?, // If joined in query
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'center_id': centerId,
      'group_id': groupId,
      'vendor_id': vendorId,
      'role': role,
    };
  }
}
