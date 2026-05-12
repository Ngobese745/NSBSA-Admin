import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/password_setup_screen.dart';
import '../theme/app_theme.dart';
import 'app_providers.dart';

/// Root widget for the NSBSA Admin app.
///
/// Keep application-wide concerns here: provider scope, global theme, and the
/// authenticated landing route. Feature screens should stay under `lib/screens`
/// or their future feature modules.
class NsbsaAdminApp extends StatelessWidget {
  const NsbsaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          return MaterialApp(
            title: 'NSBSA Admin',
            theme: AppTheme.lightGoldTheme,
            darkTheme: AppTheme.darkGoldTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: _resolveHome(authProvider),
            routes: {
              '/auth/login': (_) => const LoginScreen(),
              '/auth/setup-password': (_) => const PasswordSetupScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _resolveHome(AuthProvider auth) {
    final uri = Uri.base;
    final path = uri.path;
    final fragment = uri.fragment;
    final fullUrl = uri.toString();

    // 1. Explicit path check
    if (path == '/auth/login') return const LoginScreen();
    if (path.contains('/auth/setup-password')) return const PasswordSetupScreen();

    // 2. Detection of Supabase tokens in the hash (#access_token=...&type=recovery)
    // We check BOTH the fragment and the full URL string for safety.
    final hasToken = fragment.contains('access_token=') || fullUrl.contains('access_token=');
    final isRecovery = fragment.contains('type=recovery') || fullUrl.contains('type=recovery') ||
                       fragment.contains('type=invite') || fullUrl.contains('type=invite') ||
                       fragment.contains('type=signup') || fullUrl.contains('type=signup');

    if (hasToken && isRecovery) {
      return const PasswordSetupScreen();
    }

    // 3. Fallback for authenticated state
    if (!auth.isAuthenticated) return const LoginScreen();

    // 4. Fallback for the recovery flag in the provider
    if (auth.isPasswordRecovery) return const PasswordSetupScreen();

    return const MainShell();
  }
}
