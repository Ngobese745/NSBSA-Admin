import '../models/profile.dart';

class AccessControlService {
  /// Allowlisted identity for developer tools (in addition to Super Admin).
  static const String developerToolsAllowlistEmail = 'colane@mwelasefin.co.za';

  /// Whether the given email matches the Super Admin allowlist.
  static bool isSuperAdminEmail(String? email) {
    if (email == null) return false;
    return email.trim().toLowerCase() == developerToolsAllowlistEmail;
  }

  /// Super Admin by role OR allowlisted email.
  static bool isSuperAdmin(ProfileModel? profile) {
    if (profile == null) return false;
    return profile.isSuperAdmin || isSuperAdminEmail(profile.email);
  }

  /// Developer Management: Super Admin or allowlisted developer email only.
  static bool canAccessDeveloperTools(ProfileModel? profile) {
    if (profile == null) return false;
    if (profile.role == 'Super Admin') return true;
    return isSuperAdminEmail(profile.email);
  }

  /// Check if the current user has a specific role
  static bool hasRole(ProfileModel? profile, List<String> allowedRoles) {
    if (profile == null) return false;
    if (profile.role == 'Super Admin')
      return true; // Super Admin bypasses everything
    return allowedRoles.contains(profile.role);
  }

  /// Dashboard Access
  static bool canViewDashboard(ProfileModel? profile) => true; // Everyone

  /// User Management (Admin/Super Admin only)
  static bool canManageUsers(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin', 'Admin']);

  /// Critical user administration (role changes, block/unblock, deletes).
  static bool canAdministerUsers(ProfileModel? profile) =>
      profile?.role == 'Super Admin';

  /// Financial Operations (Finance/Admin/Super Admin)
  static bool canProcessPayments(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin', 'Admin', 'Finance']);

  /// Reports (Finance/Admin/Super Admin)
  static bool canViewReports(ProfileModel? profile) => hasRole(profile, [
    'Super Admin',
    'Admin',
    'Finance',
    'Verifying Operator',
  ]);

  /// Audit Logs (Super Admin only)
  static bool canViewAuditLogs(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin']);

  /// Marketing/Announcements
  static bool canManageAnnouncements(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin', 'Admin', 'Marketing']);

  static bool canAccessMarketing(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin', 'Admin', 'Marketing']);

  /// Data Editing (Everyone except Field Agents who are view-only)
  static bool canEditData(ProfileModel? profile) =>
      profile != null && profile.role != 'Development Facilitator';

  /// View Assigned Portfolio (Field Agents)
  static bool isFieldAgent(ProfileModel? profile) =>
      profile?.role == 'Development Facilitator';

  /// DF can register vendors (always allowed — goes to Pending).
  static bool canRegisterVendors(ProfileModel? profile) =>
      profile != null;

  /// DF can create groups (always allowed — goes to Pending).
  static bool canCreateGroups(ProfileModel? profile) =>
      profile != null;

  /// Approve/reject pending records (Admin/Super Admin only).
  static bool canApproveRecords(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin', 'Admin']);

  /// Can view pending/unapproved records.
  static bool canViewUnapprovedRecords(ProfileModel? profile) =>
      hasRole(profile, ['Super Admin', 'Admin']);
}
