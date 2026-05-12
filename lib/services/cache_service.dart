import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const Duration defaultExpiration = Duration(minutes: 5);

  /// Saves a list of dynamically mapped data into SharedPreferences with a timestamp.
  static Future<void> saveCache(String key, List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };

    await prefs.setString(key, jsonEncode(cacheData));
  }

  /// Retrieves cached data if it exists and is within the expiration duration.
  /// Returns null if the cache is empty or expired.
  static Future<List<dynamic>?> getCache(
    String key, {
    Duration expiration = defaultExpiration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedString = prefs.getString(key);

    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestampStr = cacheData['timestamp'] as String?;
      final data = cacheData['data'] as List<dynamic>?;

      if (timestampStr == null || data == null) return null;

      final cachedTime = DateTime.parse(timestampStr);
      final age = DateTime.now().difference(cachedTime);

      if (age > expiration) {
        // Cache expired
        return null;
      }

      return data;
    } catch (e) {
      // If parsing fails, invalidate cache
      await prefs.remove(key);
      return null;
    }
  }

  /// Manually clears a specific cache key.
  static Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
