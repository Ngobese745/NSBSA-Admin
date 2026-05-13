import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import 'communication_service.dart';
import 'system_audit_service.dart';
import 'notification_service.dart';

/// Service for account creation, password reset approval, and audit logging.
/// Uses the Supabase Service Role client for admin operations.
class AccountManagementService {
  static SupabaseClient? _adminClient;

  /// Returns a service-role Supabase client.
  /// The service role key must be set in .env as SUPABASE_SERVICE_ROLE_KEY.
  static SupabaseClient get _admin {
    if (_adminClient != null) return _adminClient!;

    final url = AppConfig.supabaseUrl;
    final serviceKey = AppConfig.supabaseServiceRoleKey;

    _adminClient = SupabaseClient(url, serviceKey);
    return _adminClient!;
  }

  /// Standard anon client for non-admin operations.
  static SupabaseClient get _client => Supabase.instance.client;

  // ─────────────────────────────────────────────
  // ACCOUNT CREATION
  // ─────────────────────────────────────────────

  /// True when Supabase Auth refused to send another email (429 / SMTP caps).
  static bool isAuthEmailRateLimit(Object error) {
    if (error is AuthApiException) {
      return error.code == 'over_email_send_rate_limit' ||
          error.statusCode == '429';
    }
    return false;
  }

  /// Short message for the staff-invite dialog and similar flows.
  static String staffInviteErrorMessage(Object error) {
    if (isAuthEmailRateLimit(error)) {
      return 'Supabase is temporarily limiting auth emails (invite links). '
          'Wait 30–60 minutes, send fewer test invites, or in the Supabase '
          'Dashboard open Project Settings → Auth and set up custom SMTP / '
          'review rate limits.';
    }
    if (error is AuthApiException) {
      return error.message;
    }
    return error.toString();
  }

  /// Creates a new staff account with a temporary password.
  /// Only call this from Super Admin context.
  static Future<void> createStaffAccount({
    required String email,
    required String fullName,
    required String role,
    required String operatorEmail,
  }) async {
    // 1. Generate a temporary password
    final tempPassword = _generateTempPassword();

    // 2. Create the user directly via Admin API (bypassing invitation links)
    final response = await _admin.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: tempPassword,
        emailConfirm: true, // Confirm immediately so they can log in
        userMetadata: {'full_name': fullName, 'must_change_password': true},
      ),
    );

    final newUser = response.user;
    if (newUser == null) {
      throw Exception('Failed to create auth user.');
    }

    // 3. Create the profile
    await _admin.from('profiles').upsert({
      'id': newUser.id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'status': 'Active',
    }, onConflict: 'id');

    // 4. Send the credentials via CommunicationService
    final comms = CommunicationService();
    await comms.sendStaffCredentials(
      toEmail: email,
      fullName: fullName,
      tempPassword: tempPassword,
    );

    // 5. Log the event
    await logEvent(
      eventType: 'account_created',
      targetEmail: email,
      operatorEmail: operatorEmail,
      metadata: {
        'role': role,
        'full_name': fullName,
        'flow': 'direct_credentials',
      },
    );
    SystemAuditService.logAction(
      actionType: 'CREATE_USER',
      affectedEntity: 'User: $email',
      description:
          'Created staff account (Direct Credentials) with role: $role.',
    );

    await NotificationService.notifySuperAdmin(
      'New User Created',
      '$fullName ($email) has been added as $role.',
      type: 'ACTIVITY',
    );
  }

  /// Generates a secure temporary password (min 12 chars, mixed case, numbers, symbols).
  static String _generateTempPassword() {
    const chars = r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$&*';
    final rand = Random.secure();
    return List.generate(14, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Finalizes the password setup for a user forced to change it.
  static Future<void> completeForcePasswordSetup(String newPassword) async {
    final auth = Supabase.instance.client.auth;

    // Update the password
    await auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'must_change_password': false},
      ),
    );

    await logEvent(
      eventType: 'password_setup_completed',
      targetEmail: auth.currentUser?.email ?? 'unknown',
    );
  }

  static Future<void> updateStaffProfile({
    required String userId,
    required String fullName,
    required String email,
    required String department,
    required String role,
    required String status,
    required String operatorEmail,
    required bool canChangeCriticalFields,
  }) async {
    final update = <String, dynamic>{
      'full_name': fullName,
      'email': email,
      'department': department.isEmpty ? null : department,
    };

    if (canChangeCriticalFields) {
      update['role'] = role;
      update['status'] = status;
      await _admin.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(
          email: email,
          banDuration: status == 'Blocked' ? '876000h' : 'none',
        ),
      );
    }

    await _client.from('profiles').update(update).eq('id', userId);

    await logEvent(
      eventType: 'user_updated',
      targetEmail: email,
      operatorEmail: operatorEmail,
      metadata: {
        'user_id': userId,
        'full_name': fullName,
        'department': department,
        if (canChangeCriticalFields) 'role': role,
        if (canChangeCriticalFields) 'status': status,
      },
    );

    SystemAuditService.logAction(
      actionType: 'UPDATE_USER',
      affectedEntity: 'User ID: $userId',
      description: 'Updated staff profile details for $email.',
    );
  }

  static Future<void> blockUser({
    required String userId,
    required String targetEmail,
    required String operatorEmail,
    required String reason,
  }) async {
    await _admin.auth.admin.updateUserById(
      userId,
      attributes: AdminUserAttributes(banDuration: '876000h'),
    );
    await _client
        .from('profiles')
        .update({'status': 'Blocked'})
        .eq('id', userId);
    await logEvent(
      eventType: 'user_blocked',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
      metadata: {
        'user_id': userId,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    SystemAuditService.logAction(
      actionType: 'BLOCK_USER',
      affectedEntity: 'User ID: $userId',
      description: 'Blocked user account ($targetEmail). Reason: $reason.',
    );

    await NotificationService.notifySuperAdmin(
      'User Blocked',
      '$targetEmail has been blocked. Reason: $reason',
      type: 'ACTIVITY',
    );
  }

  static Future<void> unblockUser({
    required String userId,
    required String targetEmail,
    required String operatorEmail,
  }) async {
    await _admin.auth.admin.updateUserById(
      userId,
      attributes: AdminUserAttributes(banDuration: 'none'),
    );
    await _client
        .from('profiles')
        .update({'status': 'Active'})
        .eq('id', userId);
    await logEvent(
      eventType: 'user_unblocked',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
      metadata: {
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    SystemAuditService.logAction(
      actionType: 'UNBLOCK_USER',
      affectedEntity: 'User ID: $userId',
      description: 'Unblocked user account ($targetEmail).',
    );
  }

  static Future<void> deleteUserAccount({
    required String userId,
    required String targetEmail,
    required String operatorEmail,
  }) async {
    await logEvent(
      eventType: 'user_deleted',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
      metadata: {
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    await _admin.auth.admin.deleteUser(userId);

    SystemAuditService.logAction(
      actionType: 'DELETE_USER',
      affectedEntity: 'User ID: $userId',
      description: 'Deleted user account ($targetEmail).',
    );
  }

  // ─────────────────────────────────────────────
  // PASSWORD RESET WORKFLOW
  // ─────────────────────────────────────────────

  /// Submit a password reset request (called by staff, no admin key needed).
  static Future<void> submitResetRequest(String email) async {
    await _client.from('password_reset_requests').insert({
      'user_email': email,
      'status': 'pending',
    });

    await NotificationService.notifySuperAdmin(
      'Password Reset Request',
      'A reset request has been submitted for $email.',
      type: 'ACTIVITY',
    );
  }

  /// Fetch all pending reset requests.
  static Future<List<Map<String, dynamic>>> fetchPendingResets() async {
    final data = await _client
        .from('password_reset_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Super Admin approves a reset request — generates temp password and sends email.
  static Future<void> approvePasswordReset({
    required String requestId,
    required String targetEmail,
    required String operatorEmail,
  }) async {
    // 1. Find the user ID
    final profileData = await _admin
        .from('profiles')
        .select('id')
        .eq('email', targetEmail)
        .maybeSingle();
    
    if (profileData == null) {
      throw Exception('No user profile found for $targetEmail');
    }
    final userId = profileData['id'];

    // 2. Generate secure temp password
    final tempPassword = _generateTempPassword();

    // 3. Update Auth User (metadata + password)
    await _admin.auth.admin.updateUserById(
      userId,
      attributes: AdminUserAttributes(
        password: tempPassword,
        userMetadata: {'must_change_password': true},
      ),
    );

    // 4. Mark request as Completed
    await _client
        .from('password_reset_requests')
        .update({
          'status': 'completed',
          'reviewed_by': operatorEmail,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // 5. Send Email via CommunicationService
    final comms = CommunicationService();
    await comms.sendPasswordResetApproved(
      toEmail: targetEmail,
      tempPassword: tempPassword,
    );

    // 6. Log the approval
    await logEvent(
      eventType: 'reset_approved',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
      metadata: {'method': 'temporary_password'},
    );

    SystemAuditService.logAction(
      actionType: 'APPROVE_RESET',
      affectedEntity: 'User: $targetEmail',
      description: 'Approved password reset and generated temporary credentials.',
    );
  }

  /// Super Admin rejects a reset request.
  static Future<void> rejectPasswordReset({
    required String requestId,
    required String targetEmail,
    required String operatorEmail,
    String? reason,
  }) async {
    // 1. Mark request as Rejected
    await _client
        .from('password_reset_requests')
        .update({
          'status': 'rejected',
          'reviewed_by': operatorEmail,
          'reviewed_at': DateTime.now().toIso8601String(),
          'rejection_reason': reason,
        })
        .eq('id', requestId);

    // 2. Send rejection email
    final comms = CommunicationService();
    await comms.sendPasswordResetRejected(
      toEmail: targetEmail,
      reason: reason,
    );

    // 3. Log the rejection
    await logEvent(
      eventType: 'reset_rejected',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
      metadata: {'reason': reason},
    );

    SystemAuditService.logAction(
      actionType: 'REJECT_RESET',
      affectedEntity: 'User: $targetEmail',
      description: 'Rejected password reset request. Reason: ${reason ?? 'Security policy'}',
    );
  }

  // ─────────────────────────────────────────────
  // AUDIT LOGGING
  // ─────────────────────────────────────────────

  /// Writes an immutable event to account_audit_log.
  static Future<void> logEvent({
    required String eventType,
    required String targetEmail,
    String? operatorEmail,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('account_audit_log').insert({
        'event_type': eventType,
        'target_email': targetEmail,
        'operator_email': operatorEmail,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Audit log write failed: $e');
    }
  }

  /// Fetch audit log entries with optional filters.
  static Future<List<Map<String, dynamic>>> fetchAuditLog({
    String? eventType,
    String? targetEmail,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    var query = _client.from('account_audit_log').select();

    // Filters applied via chaining
    if (eventType != null && eventType.isNotEmpty) {
      query = query.eq('event_type', eventType);
    }
    if (targetEmail != null && targetEmail.isNotEmpty) {
      query = query.ilike('target_email', '%$targetEmail%');
    }

    final data = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  // ─────────────────────────────────────────────
  // PASSWORD VALIDATION
  // ─────────────────────────────────────────────

  static const int minLength = 8;

  static String? validatePassword(String password) {
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    if (!password.contains(RegExp(r'[!@#\$&*~_\-]'))) {
      return 'Password must contain at least one special character (!@#\$&*~_-).';
    }
    return null; // Valid
  }
}
