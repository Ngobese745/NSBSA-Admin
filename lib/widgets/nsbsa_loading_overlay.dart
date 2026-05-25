import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_assets.dart';
import 'segmented_spinner.dart';/// Branded NSBSA loading overlay with splash-screen-style animation.
///
/// Shows the NSBSA logo with a pulsing gold ring immediately when an action
/// starts, transitions to a green checkmark (success) or red error icon when
/// the async [task] completes, then auto-dismisses.
///
/// Double-clicks are prevented via an absorbing tap barrier.
/// A "Still processing…" hint appears after 10 seconds.
const _kGold = Color(0xFFD4AF37);
const _kDark = Color(0xFF0A0E14);
const _kSuccess = Color(0xFF4CAF50);
const _kError = Color(0xFFEF5350);

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps an async [task] with a branded loading overlay.
Future<T?> runWithLoading<T>(
  BuildContext context, {
  required Future<T> Function() task,
  String loadingMessage = 'Processing your request\u2026',
  String? successMessage,
  String Function(Object error)? errorMessageBuilder,
  Duration autoDismiss = const Duration(seconds: 2),
}) async {
  return _runWithOverlay(
    context,
    task: task,
    loadingMessage: loadingMessage,
    successMessage: successMessage,
    errorMessageBuilder: errorMessageBuilder,
    autoDismiss: autoDismiss,
    popFirst: false,
  );
}

/// Like [runWithLoading] but pops the current route (dialog) first.
/// Use inside dialog confirm handlers so the form closes before the
/// loading animation appears.
Future<T?> runWithLoadingAfterPop<T>(
  BuildContext dialogContext, {
  required Future<T> Function() task,
  String loadingMessage = 'Processing your request\u2026',
  String? successMessage,
  String Function(Object error)? errorMessageBuilder,
  Duration autoDismiss = const Duration(seconds: 2),
}) async {
  return _runWithOverlay(
    dialogContext,
    task: task,
    loadingMessage: loadingMessage,
    successMessage: successMessage,
    errorMessageBuilder: errorMessageBuilder,
    autoDismiss: autoDismiss,
    popFirst: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared implementation
// ─────────────────────────────────────────────────────────────────────────────

Future<T?> _runWithOverlay<T>(
  BuildContext context, {
  required Future<T> Function() task,
  required String loadingMessage,
  String? successMessage,
  String Function(Object error)? errorMessageBuilder,
  required Duration autoDismiss,
  required bool popFirst,
}) async {
  final state = _OverlayStateNotifier(const _OverlayPayload(_LoadStage.loading, ''));

  // Insert overlay entry
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(builder: (_) => _NsbsaLoadingOverlay(state: state));
  overlay.insert(entry);

  // Pop dialog first if requested
  if (popFirst) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (context.mounted) nav.pop();
  }

  // One frame delay so the entry mounts, then set message
  await Future<void>.delayed(Duration.zero);
  if (state.value.message.isEmpty) {
    state.value = _OverlayPayload(_LoadStage.loading, loadingMessage);
  }

  // 10-second fallback
  final fallbackTimer = Timer(const Duration(seconds: 10), () {
    if (state.value.stage == _LoadStage.loading) {
      state.value = _OverlayPayload(
        _LoadStage.loading,
        '${state.value.message}\nStill processing\u2026',
      );
    }
  });

  try {
    final result = await task();
    fallbackTimer.cancel();

    if (successMessage != null) {
      state.value = _OverlayPayload(_LoadStage.success, successMessage);
      await Future.delayed(autoDismiss);
    }

    entry.remove();
    return result;
  } catch (e) {
    fallbackTimer.cancel();

    final msg = errorMessageBuilder?.call(e) ?? _humanReadableError(e);
    state.value = _OverlayPayload(_LoadStage.error, msg);
    await Future.delayed(autoDismiss);

    entry.remove();
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal types
// ─────────────────────────────────────────────────────────────────────────────

enum _LoadStage { loading, success, error }

class _OverlayPayload {
  final _LoadStage stage;
  final String message;
  const _OverlayPayload(this.stage, this.message);
}

class _OverlayStateNotifier extends ValueNotifier<_OverlayPayload> {
  _OverlayStateNotifier(super.value);
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash-style overlay widget
// ─────────────────────────────────────────────────────────────────────────────

class _NsbsaLoadingOverlay extends StatefulWidget {
  final _OverlayStateNotifier state;
  const _NsbsaLoadingOverlay({required this.state});

  @override
  State<_NsbsaLoadingOverlay> createState() => _NsbsaLoadingOverlayState();
}

class _NsbsaLoadingOverlayState extends State<_NsbsaLoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final payload = widget.state.value;

    return FadeTransition(
      opacity: _fadeIn,
      child: GestureDetector(
        onTap: () {},
        onPanDown: (_) {},
        child: Container(
          constraints: const BoxConstraints.expand(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildCard(payload, key: ValueKey(payload.stage.name)),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_OverlayPayload payload, {required Key key}) {
    return Container(
      key: key,
      color: Colors.black54,
      child: Stack(
        children: [
          // Background Glow Effect
          Center(
            child: Container(
              width: 600,
              height: 600,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color.fromRGBO(212, 175, 55, 0.08), Colors.transparent],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          
          // Centered Loader and Text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (payload.stage == _LoadStage.loading)
                        const SegmentedSpinner(size: 64, strokeWidth: 2.0),
                      if (payload.stage != _LoadStage.loading)
                        _BounceIcon(
                          icon: payload.stage == _LoadStage.success
                              ? Icons.check_circle
                              : Icons.error,
                          color: payload.stage == _LoadStage.success
                              ? _kSuccess
                              : _kError,
                          size: 48,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          
        ],
      ),
    );
  }
}

// Removed _AnimatedRing and _NsbsaLogo as they are no longer needed

// ── Bounce-in icon for success/error ──────────────────────────────────────
class _BounceIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _BounceIcon({required this.icon, required this.color, required this.size});

  @override
  State<_BounceIcon> createState() => _BounceIconState();
}

class _BounceIconState extends State<_BounceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _opacity = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _humanReadableError(Object error) {
  final s = error.toString();
  if (s.contains('timeout')) return 'Request timed out. Please try again.';
  if (s.contains('network') || s.contains('Socket')) {
    return 'Network error. Check your connection.';
  }
  if (s.contains('permission') || s.contains('Unauthorized')) {
    return 'You don\u2019t have permission for this action.';
  }
  if (s.length > 80) return 'Something went wrong. Please try again.';
  return s;
}
