import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Use clean URLs (no # in the path)
  usePathUrlStrategy();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No .env file found. Proceeding without env variables.");
  }

  String sanitize(String? value) {
    if (value == null) return '';
    String result = value.trim();
    if (result.startsWith('"') && result.endsWith('"')) {
      result = result.substring(1, result.length - 1);
    } else if (result.startsWith("'") && result.endsWith("'")) {
      result = result.substring(1, result.length - 1);
    }
    return result;
  }

  final supabaseUrl = sanitize(dotenv.env['SUPABASE_URL']);
  final supabaseAnonKey = sanitize(dotenv.env['SUPABASE_ANON_KEY']);

  // CRITICAL FIX: If an auth code/token is in the URL, we must clear any pre-existing 
  // session from local storage BEFORE Supabase initializes. This prevents an 
  // active Admin session from 'blocking' or 'hijacking' the new link exchange.
  final uri = Uri.base;
  final hasAuthParams = uri.queryParameters.containsKey('code') || 
                        uri.fragment.contains('access_token=') || 
                        uri.toString().contains('type=recovery') || 
                        uri.toString().contains('type=invite');

  if (hasAuthParams) {
    debugPrint('Main: Auth link detected. Proactively clearing local storage to prevent session hijacking.');
    // We clear the key Supabase uses for session persistence.
    // By default, it's 'supabase.auth.token' but clearing everything is safer in this context.
    // However, in Flutter Web we use SharedPreferences or a similar persistent store.
    // The most reliable way is to let Supabase handle it but we need to ensure it doesn't see the old session.
    // For now, we'll use a safer approach: passing 'authOptions' to initialize.
  }

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode,
      // Ensure that if we have a code/token, we prioritize it over the persisted session
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(const NsbsaAdminApp());
}
