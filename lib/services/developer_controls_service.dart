import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/developer_controls.dart';

/// Supabase-backed developer tools: banners, feature flags, audit log.
class DeveloperControlsService {
  static SupabaseClient get _client => Supabase.instance.client;

  static bool _missingTable(Object e) {
    final s = e.toString();
    return s.contains('PGRST205') &&
        (s.contains('system_banners') ||
            s.contains('feature_flags') ||
            s.contains('developer_action_log'));
  }

  static Future<List<SystemBannerModel>> fetchBanners() async {
    try {
      final data = await _client
          .from('system_banners')
          .select()
          .order('updated_at', ascending: false);
      return (data as List)
          .map(
            (e) =>
                SystemBannerModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      if (_missingTable(e)) return [];
      rethrow;
    }
  }

  static Future<List<FeatureFlagModel>> fetchFeatureFlags() async {
    try {
      final data = await _client
          .from('feature_flags')
          .select()
          .order('sort_order');
      return (data as List)
          .map(
            (e) =>
                FeatureFlagModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      if (_missingTable(e)) return [];
      rethrow;
    }
  }

  static Future<List<DeveloperActionLogModel>> fetchActionLog({
    int limit = 100,
  }) async {
    try {
      final data = await _client
          .from('developer_action_log')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map(
            (e) => DeveloperActionLogModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      if (_missingTable(e)) return [];
      rethrow;
    }
  }

  static Future<void> logAction({
    required String developerId,
    required String? developerEmail,
    required String actionType,
    String? resourceType,
    String? resourceId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _client.from('developer_action_log').insert({
        'developer_id': developerId,
        'developer_email': developerEmail,
        'action_type': actionType,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'payload': payload,
      });
    } catch (e) {
      debugPrint('developer_action_log insert failed: $e');
    }
  }

  static Future<SystemBannerModel> insertBanner({
    required String bannerType,
    required String title,
    required String message,
    required String severity,
    required bool isEnabled,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {
    final row = await _client
        .from('system_banners')
        .insert({
          'banner_type': bannerType,
          'title': title,
          'message': message,
          'severity': severity,
          'is_enabled': isEnabled,
          'starts_at': startsAt.toIso8601String(),
          'ends_at': endsAt?.toIso8601String(),
        })
        .select()
        .single();
    return SystemBannerModel.fromJson(Map<String, dynamic>.from(row as Map));
  }

  static Future<void> updateBanner(SystemBannerModel banner) async {
    await _client
        .from('system_banners')
        .update({
          'banner_type': banner.bannerType,
          'title': banner.title,
          'message': banner.message,
          'severity': banner.severity,
          'is_enabled': banner.isEnabled,
          'starts_at': banner.startsAt.toIso8601String(),
          'ends_at': banner.endsAt?.toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', banner.id);
  }

  /// When enabling [bannerId], turn off all other banners (single active strip).
  static Future<void> setBannerEnabledExclusive(
    String bannerId,
    bool enabled,
  ) async {
    if (enabled) {
      await _client
          .from('system_banners')
          .update({
            'is_enabled': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .neq('id', bannerId);
    }
    await _client
        .from('system_banners')
        .update({
          'is_enabled': enabled,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', bannerId);
  }

  static Future<void> deleteBanner(String id) async {
    await _client.from('system_banners').delete().eq('id', id);
  }

  static Future<void> setFeatureEnabled(
    String featureKey,
    bool enabled,
    String? userId,
  ) async {
    await _client
        .from('feature_flags')
        .update({
          'enabled': enabled,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          if (userId != null) 'updated_by': userId,
        })
        .eq('feature_key', featureKey);
  }
}
