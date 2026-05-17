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
    const define = String.fromEnvironment('SUPABASE_URL');
    final url = define.isNotEmpty ? define : _sanitize(dotenv.env['SUPABASE_URL']);
    if (url.isEmpty) {
      throw Exception('SUPABASE_URL is not set. Use --dart-define or .env');
    }
    return url;
  }

  static String get supabaseAnonKey {
    const define = String.fromEnvironment('SUPABASE_ANON_KEY');
    final key = define.isNotEmpty ? define : _sanitize(dotenv.env['SUPABASE_ANON_KEY']);
    if (key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is not set. Use --dart-define or .env');
    }
    return key;
  }

  /// SECURITY WARNING: The Service Role Key should NEVER be used on the client-side
  /// in production. It bypasses all RLS policies. This is currently used for 
  /// admin tasks but should be migrated to Supabase Edge Functions.
  static String get supabaseServiceRoleKey {
    const define = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
    final key = define.isNotEmpty ? define : _sanitize(dotenv.env['SUPABASE_SERVICE_ROLE_KEY']);
    if (key.isEmpty) {
      throw Exception('SUPABASE_SERVICE_ROLE_KEY is not set.');
    }
    return key;
  }

  static String get mailerSendApiKey {
    const define = String.fromEnvironment('MAILERSEND_API_KEY');
    return define.isNotEmpty ? define : _sanitize(dotenv.env['MAILERSEND_API_KEY']);
  }
}
