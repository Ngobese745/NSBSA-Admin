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

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode, // Enable debug for better logging in development
    );
  }

  runApp(const NsbsaAdminApp());
}
