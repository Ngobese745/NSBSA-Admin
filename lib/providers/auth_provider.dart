import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/account_management_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isPasswordRecovery = false;
  ProfileModel? _userProfile;
  final _supabase = Supabase.instance.client;

  AuthProvider() {
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      _isAuthenticated = true;
      await _fetchUserProfile(session.user.id);
      notifyListeners();
    }

    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        // User clicked an invite or reset link — show password setup screen
        _isPasswordRecovery = true;
        _isAuthenticated = true;
        if (data.session != null)
          await _fetchUserProfile(data.session!.user.id);
        notifyListeners();
        return;
      }

      if (event == AuthChangeEvent.signedIn) {
        _isAuthenticated = true;
        _isPasswordRecovery = false;
        if (data.session != null)
          await _fetchUserProfile(data.session!.user.id);
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _isAuthenticated = false;
        _isPasswordRecovery = false;
        _userProfile = null;
        notifyListeners();
      } else if (event == AuthChangeEvent.userUpdated) {
        // Password was successfully updated
        _isPasswordRecovery = false;
        if (data.session != null)
          await _fetchUserProfile(data.session!.user.id);
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        _userProfile = ProfileModel.fromJson(data);
        if (_userProfile!.isBlocked) {
          await _supabase.auth.signOut();
          _isAuthenticated = false;
          _userProfile = null;
        }
      } else {
        debugPrint('No profile found for user $userId');
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  /// Re-fetches the current user's profile from the database.
  Future<void> refreshProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _fetchUserProfile(userId);
      notifyListeners();
    }
  }

  /// Clears the password-recovery flag after setup is complete.
  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isPasswordRecovery => _isPasswordRecovery;
  User? get currentUser => _supabase.auth.currentUser;
  ProfileModel? get userProfile => _userProfile;
  String get userRole => _userProfile?.role ?? 'Development Facilitator';

  Future<String?> login(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.session != null) {
        await _fetchUserProfile(res.session!.user.id);
        
        if (_userProfile == null) {
          await _supabase.auth.signOut();
          return 'Your account exists, but your profile has not been set up. Please contact the Super Admin.';
        }

        if (_userProfile?.isBlocked == true ||
            _supabase.auth.currentSession == null) {
          return 'This account has been blocked. Please contact the Super Admin.';
        }
        _isAuthenticated = true;
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Supabase login failed: $e');
      if (e is AuthException) return e.message;
      return 'Incorrect email or password.';
    }
    return 'Authentication failed.';
  }

  /// Submits a password reset request for Super Admin approval.
  Future<String?> submitPasswordResetRequest(String email) async {
    try {
      await AccountManagementService.submitResetRequest(email);
      return null; // success
    } catch (e) {
      return 'Failed to submit request: $e';
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _isAuthenticated = false;
    _isPasswordRecovery = false;
    _userProfile = null;
    notifyListeners();
  }
}
