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
    final path = Uri.base.path;
    if (path == '/auth/login') return const LoginScreen();
    if (path == '/auth/setup-password') return const PasswordSetupScreen();

    if (!auth.isAuthenticated) return const LoginScreen();

    // Staff clicked an invite or reset link and must set a password first.
    if (auth.isPasswordRecovery) return const PasswordSetupScreen();

    return const MainShell();
  }
}
