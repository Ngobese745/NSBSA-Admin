import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_assets.dart';
import '../providers/auth_provider.dart';
import '../services/account_management_service.dart';

/// Dedicated page to handle password recovery and invitations.
/// Route: /auth/setup-password
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
  bool _hasValidSession = false;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    // Process the recovery link
    _initializeRecoveryFlow();
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Extracts the session from the URL (handles hash and query params)
  Future<void> _initializeRecoveryFlow() async {
    try {
      final auth = Supabase.instance.client.auth;
      final uri = Uri.base;
      final fullUrl = uri.toString();

      // Check if there is actually a token or code in the URL
      final hasToken = fullUrl.contains('access_token=') || 
                        fullUrl.contains('code=') || 
                        fullUrl.contains('type=recovery') || 
                        fullUrl.contains('type=invite');

      if (hasToken) {
        // FORCE SWITCH LOGIC:
        // If we have a session ALREADY (at the very start), it's a pre-existing session
        // (like the Super Admin). We MUST clear it to allow the link to exchange.
        if (auth.currentSession != null) {
          debugPrint('PasswordSetupScreen: Stale session detected. Force signing out to clear path for link.');
          await auth.signOut();
          // Small delay to ensure sign-out is processed by the client
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Now wait for the auto-exchange to happen (or manual)
        if (auth.currentSession == null) {
          debugPrint('PasswordSetupScreen: Waiting for auto-exchange...');
          await Future.delayed(const Duration(milliseconds: 1000));
        }

        // Try manual exchange if auto-exchange didn't happen or was missed
        if (auth.currentSession == null) {
          debugPrint('PasswordSetupScreen: Attempting manual exchange.');
          try {
            await auth.getSessionFromUrl(uri);
          } catch (e) {
            debugPrint('Manual exchange failed: $e');
          }
        }
      }

      setState(() {
        _hasValidSession = auth.currentSession != null;
        _isValidatingToken = false;
        if (!_hasValidSession) {
          _error = 'Invalid or expired recovery link. Please request a new one.';
        }
      });
    } catch (e) {
      setState(() {
        _hasValidSession = false;
        _isValidatingToken = false;
        _error = 'Failed to validate link: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Validation
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
      // Update the user's password in Supabase
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (response.user == null) {
        throw Exception('Supabase failed to update user attributes.');
      }

      // Log the event for security audit
      final email = Supabase.instance.client.auth.currentUser?.email ?? 'Unknown';
      await AccountManagementService.logEvent(
        eventType: 'Password Setup Complete',
        targetEmail: email,
        operatorEmail: null, // Self-service
        metadata: {'platform': 'web', 'recovery': true},
      );

      if (mounted) {
        // Refresh local profile state
        await context.read<AuthProvider>().refreshProfile();
        context.read<AuthProvider>().clearPasswordRecovery();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully! Redirecting to login...'),
            backgroundColor: Colors.green,
          ),
        );

        // A small delay ensures the password update is fully propagated 
        // in the Supabase backend before we destroy the current session.
        await Future.delayed(const Duration(seconds: 1));

        // Sign out to force a clean login with the new password
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/auth/login', (_) => false);
        }
      }
    } catch (e) {
      setState(() => _error = e is AuthException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    gold.withOpacity(0.05),
                    Colors.black,
                  ],
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
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: gold.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Branding
                      Center(
                        child: Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            AppAssets.logo,
                            height: 80,
                            errorBuilder: (_, __, ___) => const Icon(Icons.lock_outline, size: 80, color: gold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        'Secure Your Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Setting password for:',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Supabase.instance.client.auth.currentUser?.email ?? 'Validating session...',
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Set a new password to access the NSBSA Admin platform.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      if (_isValidatingToken) ...[
                        const Center(child: CircularProgressIndicator(color: gold)),
                        const SizedBox(height: 20),
                        const Text('Validating link...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ] else if (!_hasValidSession) ...[
                        // Error State
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                _error ?? 'Invalid or expired link.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/auth/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        // Form State
                        _buildPasswordField(
                          'New Password',
                          _passwordController,
                          _obscureNew,
                          () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordField(
                          'Confirm New Password',
                          _confirmController,
                          _obscureConfirm,
                          () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_error != null) 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),

                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _handleSetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 8,
                            shadowColor: gold.withOpacity(0.3),
                          ),
                          child: _isSaving
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ],
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
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
  ) {
    const gold = Color(0xFFD4AF37);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 1.5)),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
              onPressed: onToggle,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ],
    );
  }
}
