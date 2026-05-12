import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_assets.dart';
import '../providers/auth_provider.dart';
import '../services/account_management_service.dart';

/// Shown after a staff member clicks an invite link or approved reset link.
/// Forces them to set a compliant password before accessing the system.
class PasswordSetupScreen extends StatefulWidget {
  const PasswordSetupScreen({super.key});

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _isValidatingToken = true;
  bool _hasValidInviteSession = false;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _validateInviteSession();
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSetPassword() async {
    if (!_hasValidInviteSession) {
      setState(
        () => _error =
            'Your invitation link has expired. Please contact the Super Admin for a new invite.',
      );
      return;
    }

    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    final validationError = AccountManagementService.validatePassword(password);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Update password via Supabase Auth (auto hashes + salts)
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      // Log the password set event
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      await AccountManagementService.logEvent(
        eventType: 'Password Created',
        targetEmail: email,
        operatorEmail: null,
        metadata: {
          'self_service': true,
          'action': 'Password Created',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        await context.read<AuthProvider>().refreshProfile();
        context.read<AuthProvider>().clearPasswordRecovery();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password created successfully — you can now log in.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/auth/login', (_) => false);
        }
      }
    } catch (e) {
      final message = e is AuthException ? e.message : e.toString();
      setState(() => _error = message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _validateInviteSession() async {
    final uri = Uri.base;
    final hasAuthCallback = _hasAuthCallbackParams(uri);

    if (!hasAuthCallback) {
      setState(() {
        _hasValidInviteSession = false;
        _isValidatingToken = false;
        _error =
            'Your invitation link has expired. Please contact the Super Admin for a new invite.';
      });
      return;
    }

    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        await auth.getSessionFromUrl(uri);
      }

      setState(() {
        _hasValidInviteSession = auth.currentSession != null;
        _isValidatingToken = false;
        if (!_hasValidInviteSession) {
          _error =
              'Your invitation link has expired. Please contact the Super Admin for a new invite.';
        }
      });
    } catch (_) {
      setState(() {
        _hasValidInviteSession = false;
        _isValidatingToken = false;
        _error =
            'Your invitation link has expired. Please contact the Super Admin for a new invite.';
      });
    }
  }

  bool _hasAuthCallbackParams(Uri uri) {
    final fragmentParams = Uri.splitQueryString(
      uri.fragment.replaceFirst('?', ''),
    );
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error_description') ||
        fragmentParams.containsKey('access_token') ||
        fragmentParams.containsKey('error_description');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gold = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background blur
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0A0A), Color(0xFF111108)],
                ),
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.05),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: Image.asset(
                          AppAssets.logo,
                          height: 72,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.security, size: 72, color: gold),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      const Text(
                        'Create Your Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This password will be used for your staff login.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      const SizedBox(height: 32),

                      if (_isValidatingToken) ...[
                        const Center(
                          child: CircularProgressIndicator(color: gold),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Password rules
                      if (!_isValidatingToken && _hasValidInviteSession) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: gold.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password Requirements',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...[
                                '• Minimum 8 characters',
                                '• At least one uppercase letter (A–Z)',
                                '• At least one lowercase letter (a–z)',
                                '• At least one number (0–9)',
                                '• At least one special character (!@#\$&*~_-)',
                              ].map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // New Password field
                        _buildPasswordField(
                          'New Password',
                          _passwordController,
                          _obscureNew,
                          () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password field
                        _buildPasswordField(
                          'Confirm Password',
                          _confirmController,
                          _obscureConfirm,
                          () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Error
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 8),

                      // Submit button
                      SizedBox(
                        height: 52,
                        child: _hasValidInviteSession
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isSaving
                                    ? null
                                    : _handleSetPassword,
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.black,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Set Password',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              )
                            : OutlinedButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      '/auth/login',
                                      (_) => false,
                                    ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: gold,
                                  side: const BorderSide(color: gold),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Back to Login'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController ctrl,
    bool obscure,
    VoidCallback toggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD4AF37)),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}
