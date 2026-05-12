import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration management for the NSBSA Admin System.
/// This prevents hardcoded secrets and unmanaged environment variable access.
class AppConfig {
  /// Ensures the string is stripped of leading/trailing quotes from the .env file.
  static String _sanitize(String? value) {
    if (value == null) return '';
    String result = value.trim();
    if (result.startsWith('"') && result.endsWith('"')) {
      result = result.substring(1, result.length - 1);
    } else if (result.startsWith("'") && result.endsWith("'")) {
      result = result.substring(1, result.length - 1);
    }
    return result;
  }

  static String get supabaseUrl {
    final url = _sanitize(dotenv.env['SUPABASE_URL']);
    if (url.isEmpty) {
      throw Exception('SUPABASE_URL is not set in .env');
    }
    return url;
  }

  static String get supabaseAnonKey {
    final key = _sanitize(dotenv.env['SUPABASE_ANON_KEY']);
    if (key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not set in .env');
    }
    return key;
  }

  static String get supabaseServiceRoleKey {
    final key = _sanitize(dotenv.env['SUPABASE_SERVICE_ROLE_KEY']);
    if (key.isEmpty) {
      throw Exception('SUPABASE_SERVICE_ROLE_KEY is not set in .env');
    }
    return key;
  }
}
