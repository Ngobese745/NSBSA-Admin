import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/developer_controls.dart';
import '../models/profile.dart';
import '../services/access_control_service.dart';
import '../services/developer_controls_service.dart';
import '../services/realtime_service.dart';
import '../services/system_audit_service.dart';

/// Loads system banners, feature flags, and developer audit entries from Supabase.
class DeveloperControlsProvider extends ChangeNotifier {
  List<SystemBannerModel> _banners = [];
  List<FeatureFlagModel> _flags = [];
  List<DeveloperActionLogModel> _logs = [];
  bool _tablesMissing = false;
  bool _isLoading = false;
  String? _lastError;

  List<SystemBannerModel> get banners => List.unmodifiable(_banners);
  List<FeatureFlagModel> get flags => List.unmodifiable(_flags);
  List<DeveloperActionLogModel> get recentLogs => List.unmodifiable(_logs);
  bool get tablesMissing => _tablesMissing;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  DeveloperControlsProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'system_banners',
      onData: (payload) {
        try {
          final event = payload.eventType;
          if (event == PostgresChangeEvent.insert) {
            final newBanner = SystemBannerModel.fromJson(payload.newRecord);
            if (!_banners.any((b) => b.id == newBanner.id)) {
              _banners.insert(0, newBanner);
              notifyListeners();
            }
          } else if (event == PostgresChangeEvent.update) {
            final updated = SystemBannerModel.fromJson(payload.newRecord);
            final index = _banners.indexWhere((b) => b.id == updated.id);
            if (index != -1) {
              _banners[index] = updated;
              notifyListeners();
            }
          } else if (event == PostgresChangeEvent.delete) {
            final id = payload.oldRecord['id'];
            final before = _banners.length;
            _banners.removeWhere((b) => b.id == id);
            if (_banners.length != before) notifyListeners();
          }
        } catch (e) {
          debugPrint('Error processing banners realtime: $e');
        }
      },
    );

    RealtimeService().subscribeToTable(
      tableName: 'feature_flags',
      onData: (payload) {
        try {
          final event = payload.eventType;
          if (event == PostgresChangeEvent.insert) {
            final newFlag = FeatureFlagModel.fromJson(payload.newRecord);
            if (!_flags.any((f) => f.featureKey == newFlag.featureKey)) {
              _flags.add(newFlag);
              notifyListeners();
            }
          } else if (event == PostgresChangeEvent.update) {
            final updated = FeatureFlagModel.fromJson(payload.newRecord);
            final index = _flags.indexWhere((f) => f.featureKey == updated.featureKey);
            if (index != -1) {
              _flags[index] = updated;
              notifyListeners();
            }
          } else if (event == PostgresChangeEvent.delete) {
            final key = payload.oldRecord['feature_key'];
            final before = _flags.length;
            _flags.removeWhere((f) => f.featureKey == key);
            if (_flags.length != before) notifyListeners();
          }
        } catch (e) {
          debugPrint('Error processing feature flags realtime: $e');
        }
      },
    );

    RealtimeService().subscribeToTable(
      tableName: 'developer_action_log',
      onData: (payload) {
        try {
          if (payload.eventType == PostgresChangeEvent.insert) {
            final newLog = DeveloperActionLogModel.fromJson(payload.newRecord);
            _logs.insert(0, newLog);
            // Keep list bounded
            if (_logs.length > 200) {
              _logs = _logs.sublist(0, 200);
            }
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error processing dev action log realtime: $e');
        }
      },
    );
  }

  /// If migrations are not applied, all features stay enabled (fail-open).
  bool isFeatureEnabled(String featureKey) {
    if (_tablesMissing || _flags.isEmpty) return true;
    for (final f in _flags) {
      if (f.featureKey == featureKey) return f.enabled;
    }
    return true;
  }

  /// Whether the current user can access a feature.
  /// Returns true if:
  ///  - The feature is enabled for everyone, OR
  ///  - The user is Super Admin (by role or allowlisted email), OR
  ///  - The user's role is in the flag's [allowedRoles], OR
  ///  - The user's email is in the flag's [allowedUsers].
  bool canAccessFeature(String featureKey, ProfileModel? profile) {
    if (_tablesMissing || _flags.isEmpty) return true;
    final flag = flagFor(featureKey);
    if (flag == null) return true;
    if (flag.enabled) return true;

    // Feature is disabled — check bypass rules.
    if (profile == null) return false;
    if (profile.isSuperAdmin) return true;
    if (AccessControlService.isSuperAdminEmail(profile.email)) return true;

    if (flag.allowedRoles.isNotEmpty &&
        flag.allowedRoles.contains(profile.role)) {
      return true;
    }

    if (flag.allowedUsers.isNotEmpty && profile.email != null) {
      final email = profile.email!.trim().toLowerCase();
      if (flag.allowedUsers.any((u) => u.trim().toLowerCase() == email)) {
        return true;
      }
    }

    return false;
  }

  FeatureFlagModel? flagFor(String featureKey) {
    for (final f in _flags) {
      if (f.featureKey == featureKey) return f;
    }
    return null;
  }

  /// Highest-severity enabled banner within its time window (for global strip).
  SystemBannerModel? get primaryActiveBanner {
    if (_tablesMissing || _banners.isEmpty) return null;
    final now = DateTime.now();
    final candidates = _banners.where((b) => b.isActiveNow(now)).toList();
    if (candidates.isEmpty) return null;
    const severityRank = {'critical': 0, 'warning': 1, 'info': 2};
    candidates.sort((a, b) {
      final ra = severityRank[a.severity] ?? 3;
      final rb = severityRank[b.severity] ?? 3;
      if (ra != rb) return ra.compareTo(rb);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return candidates.first;
  }

  Future<void> refresh() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        DeveloperControlsService.fetchBanners(),
        DeveloperControlsService.fetchFeatureFlags(),
        DeveloperControlsService.fetchActionLog(limit: 80),
      ]);
      _banners = results[0] as List<SystemBannerModel>;
      _flags = results[1] as List<FeatureFlagModel>;
      _logs = results[2] as List<DeveloperActionLogModel>;
      _tablesMissing = false;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('DeveloperControlsProvider.refresh: $e');
      if (e.toString().contains('PGRST205')) {
        _tablesMissing = true;
        _banners = [];
        _flags = [];
        _logs = [];
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadLogsOnly() async {
    try {
      _logs = await DeveloperControlsService.fetchActionLog(limit: 80);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setFeatureFlag({
    required String featureKey,
    required bool enabled,
    required String developerId,
    required String? developerEmail,
    List<String>? allowedRoles,
    List<String>? allowedUsers,
  }) async {
    await DeveloperControlsService.setFeatureEnabled(
      featureKey: featureKey,
      enabled: enabled,
      userId: developerId,
      allowedRoles: allowedRoles,
      allowedUsers: allowedUsers,
    );
    await DeveloperControlsService.logAction(
      developerId: developerId,
      developerEmail: developerEmail,
      actionType: enabled ? 'feature_enabled' : 'feature_disabled',
      resourceType: 'feature_flag',
      resourceId: featureKey,
      payload: {
        'feature_key': featureKey,
        'enabled': enabled,
        if (allowedRoles != null) 'allowed_roles': allowedRoles,
        if (allowedUsers != null) 'allowed_users': allowedUsers,
      },
    );
    SystemAuditService.logAction(
      actionType: 'TOGGLE_FEATURE',
      affectedEntity: 'Feature: $featureKey',
      description: 'Set feature enabled to: $enabled',
    );
    await refresh();
  }

  Future<void> saveBanner(
    SystemBannerModel banner, {
    required String developerId,
    required String? developerEmail,
  }) async {
    await DeveloperControlsService.updateBanner(banner);
    if (banner.isEnabled) {
      await DeveloperControlsService.setBannerEnabledExclusive(banner.id, true);
    }
    await DeveloperControlsService.logAction(
      developerId: developerId,
      developerEmail: developerEmail,
      actionType: 'banner_updated',
      resourceType: 'system_banner',
      resourceId: banner.id,
      payload: banner.toJson(),
    );
    SystemAuditService.logAction(
      actionType: 'UPDATE_BANNER',
      affectedEntity: 'Banner ID: ${banner.id}',
      description: 'Updated system banner.',
    );
    await refresh();
  }

  Future<void> createBanner({
    required String bannerType,
    required String title,
    required String message,
    required String severity,
    required bool isEnabled,
    required DateTime startsAt,
    DateTime? endsAt,
    required String developerId,
    required String? developerEmail,
  }) async {
    final created = await DeveloperControlsService.insertBanner(
      bannerType: bannerType,
      title: title,
      message: message,
      severity: severity,
      isEnabled: isEnabled,
      startsAt: startsAt,
      endsAt: endsAt,
    );
    if (isEnabled) {
      await DeveloperControlsService.setBannerEnabledExclusive(
        created.id,
        true,
      );
    }
    await DeveloperControlsService.logAction(
      developerId: developerId,
      developerEmail: developerEmail,
      actionType: 'banner_created',
      resourceType: 'system_banner',
      resourceId: created.id,
      payload: {'title': title, 'is_enabled': isEnabled},
    );
    SystemAuditService.logAction(
      actionType: 'CREATE_BANNER',
      affectedEntity: 'Banner: $title',
      description: 'Created a new system banner.',
    );
    await refresh();
  }

  Future<void> setBannerEnabled({
    required String bannerId,
    required bool enabled,
    required String developerId,
    required String? developerEmail,
  }) async {
    await DeveloperControlsService.setBannerEnabledExclusive(bannerId, enabled);
    await DeveloperControlsService.logAction(
      developerId: developerId,
      developerEmail: developerEmail,
      actionType: enabled ? 'banner_enabled' : 'banner_disabled',
      resourceType: 'system_banner',
      resourceId: bannerId,
      payload: {'is_enabled': enabled},
    );
    SystemAuditService.logAction(
      actionType: 'TOGGLE_BANNER',
      affectedEntity: 'Banner ID: $bannerId',
      description: 'Set banner enabled to: $enabled',
    );
    await refresh();
  }

  Future<void> removeBanner({
    required String bannerId,
    required String developerId,
    required String? developerEmail,
  }) async {
    await DeveloperControlsService.deleteBanner(bannerId);
    await DeveloperControlsService.logAction(
      developerId: developerId,
      developerEmail: developerEmail,
      actionType: 'banner_deleted',
      resourceType: 'system_banner',
      resourceId: bannerId,
      payload: const {},
    );
    SystemAuditService.logAction(
      actionType: 'DELETE_BANNER',
      affectedEntity: 'Banner ID: $bannerId',
      description: 'Deleted system banner.',
    );
    await refresh();
  }
}
