import 'package:flutter/material.dart';
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

  // Deep Scan Fix: Strip quotes and whitespace that often come from Vercel env vars
  String supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
  String supabaseAnonKey = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  // Remove leading/trailing quotes if they exist
  if (supabaseUrl.startsWith('"') && supabaseUrl.endsWith('"')) {
    supabaseUrl = supabaseUrl.substring(1, supabaseUrl.length - 1);
  }
  if (supabaseAnonKey.startsWith('"') && supabaseAnonKey.endsWith('"')) {
    supabaseAnonKey = supabaseAnonKey.substring(1, supabaseAnonKey.length - 1);
  }

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Enable debug for better logging
    );
  }

  runApp(const NsbsaAdminApp());
}
