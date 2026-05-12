import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'system_audit_service.dart';


/// Service for account creation, password reset approval, and audit logging.
/// Uses the Supabase Service Role client for admin operations.
class AccountManagementService {
  static SupabaseClient? _adminClient;

  /// Sanitizes environment variables by stripping quotes and whitespace.
  static String _sanitize(String? value) {
    if (value == null) return '';
    String result = value.trim();
    if (result.startsWith('"') && result.endsWith('"')) {
      result = result.substring(1, result.length - 1);
    } else if (result.startsWith("'") && result.endsWith("'")) {
      result = result.substring(1, result.length - 1);
    }
    return result;
  }

  /// Returns a service-role Supabase client.
  /// The service role key must be set in .env as SUPABASE_SERVICE_ROLE_KEY.
  static SupabaseClient get _admin {
    if (_adminClient != null) return _adminClient!;

    final url = _sanitize(dotenv.env['SUPABASE_URL']);
    final serviceKey = _sanitize(dotenv.env['SUPABASE_SERVICE_ROLE_KEY']);

    if (url.isEmpty || serviceKey.isEmpty) {
      throw Exception(
        'SUPABASE_SERVICE_ROLE_KEY or SUPABASE_URL is not set or malformed in .env. '
        'Add it from Supabase Dashboard → Project Settings → API.',
      );
    }

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

  /// Creates a new staff account and sends an invite email.
  /// Only call this from Super Admin context.
  static Future<void> createStaffAccount({
    required String email,
    required String fullName,
    required String role,
    required String operatorEmail,
    String? redirectTo,
  }) async {
    // 1. Invite the user via Supabase Auth (creates auth.users row + email).
    // Use the provided redirectTo or fallback to the production URL.
    final targetRedirect = redirectTo ?? 'https://nsbsa-admin.vercel.app/auth/setup-password';
    
    final inviteResponse = await _admin.auth.admin.inviteUserByEmail(
      email,
      redirectTo: targetRedirect,
      data: {'full_name': fullName},
    );
    final newUser = inviteResponse.user;
    if (newUser == null) {
      throw Exception(
        'Invite did not return a user record; cannot create profile.',
      );
    }

    // 2. profiles.id is the primary key and must match auth.users(id).
    await _admin.from('profiles').upsert({
      'id': newUser.id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'status': 'Active',
    }, onConflict: 'id');

    // 3. Log the event
    await logEvent(
      eventType: 'account_created',
      targetEmail: email,
      operatorEmail: operatorEmail,
      metadata: {'role': role, 'full_name': fullName},
    );

    SystemAuditService.logAction(
      actionType: 'CREATE_USER',
      affectedEntity: 'User: $email',
      description: 'Created staff account with role: $role.',
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

    await logEvent(
      eventType: 'reset_requested',
      targetEmail: email,
      operatorEmail: null,
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

  /// Super Admin approves a reset request — triggers the reset email.
  static Future<void> approvePasswordReset({
    required String requestId,
    required String targetEmail,
    required String operatorEmail,
  }) async {
    // 1. Send the actual reset email via admin client
    await _admin.auth.resetPasswordForEmail(targetEmail);

    // 2. Mark request as approved
    await _client
        .from('password_reset_requests')
        .update({
          'status': 'approved',
          'reviewed_by': operatorEmail,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    // 3. Log the approval
    await logEvent(
      eventType: 'reset_approved',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
    );
  }

  /// Super Admin rejects a reset request.
  static Future<void> rejectPasswordReset({
    required String requestId,
    required String targetEmail,
    required String operatorEmail,
  }) async {
    await _client
        .from('password_reset_requests')
        .update({
          'status': 'rejected',
          'reviewed_by': operatorEmail,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);

    await logEvent(
      eventType: 'reset_rejected',
      targetEmail: targetEmail,
      operatorEmail: operatorEmail,
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
