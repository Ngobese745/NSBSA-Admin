import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class _CacheEntry {
  final List<dynamic> data;
  final DateTime expiresAt;

  _CacheEntry(this.data, this.expiresAt);
}

class CacheService {
  static const Duration defaultExpiration = Duration(minutes: 5);
  static final Map<String, _CacheEntry> _memoryCache = {};
  static const Duration _memoryTtl = Duration(seconds: 30);

  /// Saves a list of dynamically mapped data into in-memory cache and SharedPreferences.
  static Future<void> saveCache(String key, List<dynamic> data) async {
    _memoryCache[key] = _CacheEntry(
      data,
      DateTime.now().add(_memoryTtl),
    );

    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
    await prefs.setString(key, jsonEncode(cacheData));
  }

  /// Retrieves cached data from in-memory first, then SharedPreferences.
  /// Returns null if the cache is empty or expired.
  static Future<List<dynamic>?> getCache(
    String key, {
    Duration expiration = defaultExpiration,
  }) async {
    final memEntry = _memoryCache[key];
    if (memEntry != null && DateTime.now().isBefore(memEntry.expiresAt)) {
      return memEntry.data;
    }
    _memoryCache.remove(key);

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
        await prefs.remove(key);
        return null;
      }

      return data;
    } catch (e) {
      await prefs.remove(key);
      return null;
    }
  }

  /// Manually clears a specific cache key from both in-memory and SharedPreferences.
  static Future<void> clearCache(String key) async {
    _memoryCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Clears all cached data from both in-memory and SharedPreferences.
  static Future<void> clearAll() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) =>
        k.startsWith('groups_cache') ||
        k.startsWith('centers_cache') ||
        k.startsWith('comments_') ||
        k.startsWith('documents_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
