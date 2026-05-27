import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InactivityTimeoutService {
  InactivityTimeoutService._();

  static final InactivityTimeoutService instance = InactivityTimeoutService._();

  Timer? _timer;
  Timer? _warningTimer;
  int _remainingSeconds = 60;
  bool _isDisposed = false;
  bool _warningActive = false;

  // In-memory cache of the user's timeout preference.
  int? _cachedTimeoutMinutes;
  bool _cachedTimeoutDisabled = false;
  String? _cachedUserId;

  GlobalKey<NavigatorState>? _navigatorKey;
  VoidCallback? _onTimeout;

  /// Initialize with navigator key and the callback for when timeout expires.
  void init({
    required GlobalKey<NavigatorState> navigatorKey,
    required VoidCallback onTimeout,
  }) {
    _navigatorKey = navigatorKey;
    _onTimeout = onTimeout;
    _loadPreference();
    _resetTimer();
  }

  /// Re-read the timeout preference from the profiles table.
  /// Call this after the user saves new timeout settings.
  Future<void> refreshPreference() async {
    _cachedUserId = null; // force re-read
    await _loadPreference();
    if (!_warningActive) _resetTimer();
  }

  Future<void> _loadPreference() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _cachedTimeoutMinutes = null;
      _cachedTimeoutDisabled = true;
      _cachedUserId = null;
      return;
    }
    if (user.id == _cachedUserId) return; // already cached

    _cachedUserId = user.id;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('timeout_minutes, timeout_disabled')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        _cachedTimeoutMinutes = data['timeout_minutes'] as int?;
        _cachedTimeoutDisabled = data['timeout_disabled'] == true;
      } else {
        _cachedTimeoutMinutes = null;
        _cachedTimeoutDisabled = false;
      }
    } catch (_) {
      _cachedTimeoutMinutes = null;
      _cachedTimeoutDisabled = false;
    }
  }

  int? get effectiveTimeoutMinutes {
    if (_cachedTimeoutDisabled) return null;
    return _cachedTimeoutMinutes ?? 15;
  }

  bool get isDisabled => _cachedTimeoutDisabled;
  int? get timeoutMinutes => _cachedTimeoutMinutes;

  void onUserActivity() {
    if (_isDisposed) return;
    final minutes = effectiveTimeoutMinutes;
    if (minutes == null) return;
    if (_warningActive) return;
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _warningTimer?.cancel();
    final minutes = effectiveTimeoutMinutes;
    if (minutes == null) return;
    _timer = Timer(Duration(minutes: minutes), _onInactive);
  }

  void _onInactive() {
    _showWarningDialog();
  }

  void _showWarningDialog() {
    if (_warningActive) return;
    _warningActive = true;
    _remainingSeconds = 60;
    _warningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        _warningTimer?.cancel();
        _warningTimer = null;
        _warningActive = false;
        _logout();
      }
    });

    // Dialog shown in a post-frame callback to avoid build phase issues.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navState = _navigatorKey?.currentState;
      if (navState == null) return;
      if (!navState.overlay!.context.mounted) return;

      showDialog(
        context: navState.overlay!.context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Row(
                    children: [
                      const Icon(Icons.timer_off, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text(
                        'Session Timeout',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You\'ve been inactive for a while.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _remainingSeconds > 0
                            ? 'Auto-logout in $_remainingSeconds second${_remainingSeconds == 1 ? '' : 's'}'
                            : 'Logging out now\u2026',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _warningTimer?.cancel();
                        _warningTimer = null;
                        _warningActive = false;
                        Navigator.pop(context);
                        _resetTimer();
                      },
                      child: const Text(
                        'Stay Logged In',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _warningTimer?.cancel();
                        _warningTimer = null;
                        _warningActive = false;
                        Navigator.pop(context);
                        _logout();
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  void _logout() {
    _timer?.cancel();
    _warningTimer?.cancel();
    _timer = null;
    _warningTimer = null;
    _warningActive = false;
    _onTimeout?.call();
  }

  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _warningTimer?.cancel();
    _timer = null;
    _warningTimer = null;
    _onTimeout = null;
    _navigatorKey = null;
  }
}
