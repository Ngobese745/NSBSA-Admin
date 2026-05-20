import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../platform_bridge.dart';

class EnvUtils {
  static String? _cachedUrl;
  static String? _cachedAnonKey;
  static String? _cachedZernioToken;
  static String? _cachedOpenRouterKey;

  static Future<String> getSupabaseUrl() async {
    if (_cachedUrl != null && _cachedUrl!.isNotEmpty) return _cachedUrl!;
    await _loadEnv();
    return _cachedUrl ?? '';
  }

  static Future<String> getSupabaseAnonKey() async {
    if (_cachedAnonKey != null && _cachedAnonKey!.isNotEmpty) return _cachedAnonKey!;
    await _loadEnv();
    return _cachedAnonKey ?? '';
  }

  static Future<String> getZernioApiToken() async {
    if (_cachedZernioToken != null && _cachedZernioToken!.isNotEmpty) return _cachedZernioToken!;
    await _loadEnv();
    if (_cachedZernioToken == null || _cachedZernioToken!.isEmpty) {
      return 'sk_7e2ad29496870c74ce15562d0c62f67c933c70600257938972805877f44a4053';
    }
    return _cachedZernioToken ?? '';
  }

  static Future<String> getOpenRouterApiKey() async {
    if (_cachedOpenRouterKey != null && _cachedOpenRouterKey!.isNotEmpty) return _cachedOpenRouterKey!;
    await _loadEnv();
    return _cachedOpenRouterKey ?? '';
  }

  static Future<String?> getEnv(String key) async {
    // Ensure environment is loaded
    await _loadEnv();
    // Try cached specific variables first
    switch (key) {
      case 'SUPABASE_URL':
        return _cachedUrl;
      case 'SUPABASE_ANON_KEY':
        return _cachedAnonKey;
      case 'ZERNIO_API_TOKEN':
        return _cachedZernioToken;
      case 'OPENROUTER_API_KEY':
        return _cachedOpenRouterKey;
      default:
        // Fallback to dotenv values
        return dotenv.env[key];
    }
  }
    // 0. Query Parameters (Web only)
    if (kIsWeb) {
      try {
        final params = Uri.base.queryParameters;
        final qUrl = params['sb_url'];
        final qKey = params['sb_key'];
        if (qUrl != null && qKey != null && qUrl.isNotEmpty) {
          _cachedUrl = qUrl;
          _cachedAnonKey = qKey;
          return;
        }
      } catch (_) {}
    }

    // 1. window.flutterEnv (Vercel/Web)
    if (kIsWeb) {
      try {
        final flutterEnv = PlatformBridge.jsContext?['flutterEnv'];
        if (flutterEnv != null) {
          final env = flutterEnv;
          final urlStr = env['SUPABASE_URL']?.toString();
          final keyStr = env['SUPABASE_ANON_KEY']?.toString();
          final zernioStr = env['ZERNIO_API_TOKEN']?.toString();
          final orKeyStr = env['OPENROUTER_API_KEY']?.toString();
          if (zernioStr != null && !zernioStr.startsWith('{{') && zernioStr.isNotEmpty) {
            _cachedZernioToken = zernioStr;
          }
          if (orKeyStr != null && !orKeyStr.startsWith('{{') && orKeyStr.isNotEmpty) {
            _cachedOpenRouterKey = orKeyStr;
          }
          if (urlStr != null && keyStr != null && !urlStr.startsWith('{{') && urlStr.isNotEmpty) {
            _cachedUrl = urlStr;
            _cachedAnonKey = keyStr;
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Asset Scan
    final pathsToTry = [
      'assets/app_env.txt',
      'assets/assets/app_env.txt',
      'app_env.txt',
    ];

    for (final path in pathsToTry) {
      try {
        final content = await rootBundle.loadString(path);
        if (content.isNotEmpty) {
          final lines = content.split('\n');
          for (var line in lines) {
            line = line.trim();
            if (line.isEmpty || line.startsWith('#')) continue;
            final parts = line.split('=');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final val = parts.sublist(1).join('=').trim();
              if (key == 'SUPABASE_URL') _cachedUrl = val;
              if (key == 'SUPABASE_ANON_KEY') _cachedAnonKey = val;
              if (key == 'ZERNIO_API_TOKEN') _cachedZernioToken = val;
              if (key == 'OPENROUTER_API_KEY') _cachedOpenRouterKey = val;
            }
          }
          if (_cachedUrl != null && _cachedUrl!.isNotEmpty) return;
        }
      } catch (_) {}

      // Dotenv fallback
      try {
        await dotenv.load(fileName: path);
        _cachedUrl ??= dotenv.env['SUPABASE_URL'];
        _cachedAnonKey ??= dotenv.env['SUPABASE_ANON_KEY'];
        _cachedZernioToken ??= dotenv.env['ZERNIO_API_TOKEN'];
        _cachedOpenRouterKey ??= dotenv.env['OPENROUTER_API_KEY'];
        if (_cachedUrl != null && _cachedUrl!.isNotEmpty) return;
      } catch (_) {}
    }

    // 3. Last fallback: Dotenv default
    _cachedUrl ??= dotenv.env['SUPABASE_URL'];
    _cachedAnonKey ??= dotenv.env['SUPABASE_ANON_KEY'];
    _cachedZernioToken ??= dotenv.env['ZERNIO_API_TOKEN'];
    _cachedOpenRouterKey ??= dotenv.env['OPENROUTER_API_KEY'];
  }
}
