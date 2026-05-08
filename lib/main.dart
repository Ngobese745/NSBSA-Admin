import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'providers/group_provider.dart';
import 'providers/vendor_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/search_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to load .env, but handle failure gracefully for now
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No .env file found. Proceeding without env variables.");
  }

  // Initialize Supabase if credentials are provided
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(const NsbsaAdminApp());
}

class NsbsaAdminApp extends StatelessWidget {
  const NsbsaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()..fetchGroups()),
        ChangeNotifierProvider(create: (_) => VendorProvider()..fetchVendors()),
        ChangeNotifierProvider(create: (_) => LoanProvider()..fetchLoans()),
        ChangeNotifierProvider(
          create: (_) => PaymentProvider()..fetchPayments(),
        ),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          return MaterialApp(
            title: 'NSBSA Admin',
            theme: AppTheme.lightGoldTheme,
            darkTheme: AppTheme.darkGoldTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: authProvider.isAuthenticated
                ? const MainShell()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
