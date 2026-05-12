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
    final queryParams = uri.queryParameters;
    final fragment = uri.fragment;
    final fullUrl = uri.toString();

    // 1. Detection of Supabase tokens/codes (PKCE or Implicit)
    // We check fragments, query params, and full URL for robustness.
    final hasAuthData = fragment.contains('access_token=') || 
                        fullUrl.contains('access_token=') ||
                        queryParams.containsKey('code') ||
                        fullUrl.contains('code=');

    final isRecoveryFlow = fragment.contains('type=recovery') || 
                           fullUrl.contains('type=recovery') ||
                           queryParams['type'] == 'recovery' ||
                           fragment.contains('type=invite') || 
                           fullUrl.contains('type=invite') ||
                           queryParams['type'] == 'invite' ||
                           fragment.contains('type=signup') || 
                           fullUrl.contains('type=signup') ||
                           queryParams['type'] == 'signup' ||
                           // In PKCE flow, we might not have a type parameter in the URL,
                           // but if we have a code and we are not yet authenticated,
                           // we should treat it as a setup flow.
                           (hasAuthData && !auth.isAuthenticated);

    if (hasAuthData && isRecoveryFlow) {
      return const PasswordSetupScreen();
    }

    // 2. Explicit path check (after auth data detection)
    if (path == '/auth/login') return const LoginScreen();
    if (path.contains('/auth/setup-password')) return const PasswordSetupScreen();

    // 3. Fallback for authenticated state
    if (!auth.isAuthenticated) return const LoginScreen();

    // 4. Fallback for the recovery flag in the provider (triggered by onAuthStateChange)
    if (auth.isPasswordRecovery) return const PasswordSetupScreen();

    return const MainShell();
  }
}
