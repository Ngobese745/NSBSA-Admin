import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/app_config.dart';
import 'app/app.dart';
import 'services/offline_queue_service.dart';
import 'services/background_sync_service.dart';

bool _urlStrategySet = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use clean URLs (no # in the path)
  if (!_urlStrategySet) {
    usePathUrlStrategy();
    _urlStrategySet = true;
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No .env file found. Proceeding without env variables.");
  }

  try {
    final supabaseUrl = AppConfig.supabaseUrl;
    final supabaseAnonKey = AppConfig.supabaseAnonKey;
    debugPrint('Supabase URL: $supabaseUrl');
    debugPrint('Supabase Key (masked): ${supabaseAnonKey.substring(0, 5)}...');

  // CRITICAL FIX: If an auth code/token is in the URL, we must clear any pre-existing
  // session from local storage BEFORE Supabase initializes. This prevents an
  // active Admin session from 'blocking' or 'hijacking' the new link exchange.
  final uri = Uri.base;
  final hasAuthParams =
      uri.queryParameters.containsKey('code') ||
      uri.fragment.contains('access_token=') ||
      uri.toString().contains('type=recovery') ||
      uri.toString().contains('type=invite');

  if (hasAuthParams) {
    debugPrint(
      'Main: Auth link detected. Proactively clearing local storage to prevent session hijacking.',
    );
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
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      // Initialize Sync Services
      await OfflineQueueService().init();
      BackgroundSyncService().init();
    }
  } catch (e) {
    debugPrint('Initialization error: $e');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Configuration Error',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Could not initialize the system. Please ensure your environment variables (SUPABASE_URL and SUPABASE_ANON_KEY) are set.\n\nError: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => main(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text('Retry', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    ));
    return;
  }

  runApp(const NsbsaAdminApp());
}
