class ProfileModel {
  final String id;
  final String? email;
  final String? fullName;
  final String role;
  final String status;
  final String? department;
  final DateTime createdAt;

  ProfileModel({
    required this.id,
    this.email,
    this.fullName,
    required this.role,
    this.status = 'Active',
    this.department,
    required this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'] ?? 'Development Facilitator',
      status: json['status'] ?? 'Active',
      department: json['department'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'status': status,
      'department': department,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Role helpers
  bool get isSuperAdmin => role == 'Super Admin';
  bool get isBlocked => status == 'Blocked';
  bool get isAdmin => role == 'Admin' || isSuperAdmin;
  bool get isFinance => role == 'Finance' || isSuperAdmin;
  bool get isMarketing => role == 'Marketing' || isSuperAdmin;
  bool get isFieldAgent => role == 'Development Facilitator';
  bool get isVerifyingOperator => role == 'Verifying Operator';

  // Permission helpers
  bool get canManageUsers => isAdmin;
  bool get canProcessPayments => isFinance;
  bool get canViewFinancialReports => isFinance || isAdmin;
  bool get canManageAnnouncements => isMarketing || isAdmin;
  bool get canViewAuditLogs => isSuperAdmin;
  bool get canEditData => !isFieldAgent; // Field agents are view-only
}
