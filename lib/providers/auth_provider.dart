import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  
  AuthProvider() {
    _checkInitialSession();
  }

  void _checkInitialSession() {
    // Check if we already have a session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _isAuthenticated = true;
      notifyListeners();
    }

    // Listen to ongoing auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _isAuthenticated = true;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _isAuthenticated = false;
        notifyListeners();
      }
    });
  }

  bool get isAuthenticated => _isAuthenticated;
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  Future<String?> login(String email, String password) async {
    try {
      // 1. Try real Supabase Auth first
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (res.session != null) {
        _isAuthenticated = true;
        notifyListeners();
        return null; // Success (no error)
      }
    } catch (e) {
      debugPrint('Supabase login failed: $e');

      // If it's an AuthException, extract the message
      if (e is AuthException) {
        return e.message;
      }
      return 'Incorrect email or password. Connection failed.';
    }
    
    return 'Authentication failed.';
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _isAuthenticated = false;
    notifyListeners();
  }
}
