import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyApiUrl = 'api_base_url';
  static const _keyApiKey = 'api_key';
  static const _keySupabaseUrl = 'supabase_url';
  static const _keySupabaseAnonKey = 'supabase_anon_key';
  static const _keyAuthToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';

  // API configuration
  static Future<void> saveApiConfig({
    required String baseUrl,
    required String apiKey,
  }) async {
    await _storage.write(key: _keyApiUrl, value: baseUrl);
    await _storage.write(key: _keyApiKey, value: apiKey);
  }

  static Future<String?> getApiUrl() async => _storage.read(key: _keyApiUrl);
  static Future<String?> getApiKey() async => _storage.read(key: _keyApiKey);

  // Supabase configuration
  static Future<void> saveSupabaseConfig({
    required String url,
    required String anonKey,
  }) async {
    await _storage.write(key: _keySupabaseUrl, value: url);
    await _storage.write(key: _keySupabaseAnonKey, value: anonKey);
  }

  static Future<String?> getSupabaseUrl() async =>
      _storage.read(key: _keySupabaseUrl);
  static Future<String?> getSupabaseAnonKey() async =>
      _storage.read(key: _keySupabaseAnonKey);

  // Auth tokens
  static Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAuthToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<String?> getAuthToken() async =>
      _storage.read(key: _keyAuthToken);
  static Future<String?> getRefreshToken() async =>
      _storage.read(key: _keyRefreshToken);

  // Generic read/write
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> read(String key) async => _storage.read(key: key);

  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Migration helper: move a value from SharedPreferences to secure storage
  static Future<void> migrateFromPrefs(
    String prefsKey,
    String storageKey,
    String Function(String)? transform,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(prefsKey);
      if (value != null) {
        final stored = transform != null ? transform(value) : value;
        await _storage.write(key: storageKey, value: stored);
        await prefs.remove(prefsKey);
        debugPrint('Migrated $prefsKey to secure storage as $storageKey');
      }
    } catch (e) {
      debugPrint('Migration failed for $prefsKey: $e');
    }
  }
}
