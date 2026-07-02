import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';
import '../services/cache_service.dart';
import '../services/realtime_service.dart';
import '../services/system_audit_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class CommentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  String? _currentScope;
  String? _currentScopeValue;
  Timer? _cacheDebounce;

  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;

  CommentProvider() {
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeService().subscribeToTable(
      tableName: 'comments',
      onData: (payload) {
        final event = payload.eventType;
        final data = payload.newRecord;
        final oldData = payload.oldRecord;

        try {
          // Only apply if the change matches our current scope
          if (event == PostgresChangeEvent.insert) {
            final newComment = CommentModel.fromJson(data);
            if (_matchesScope(newComment, oldData: data)) {
              if (!_comments.any((c) => c.id == newComment.id)) {
                _comments.insert(0, newComment);
                _syncCacheAndNotify();
              }
            }
          } else if (event == PostgresChangeEvent.update) {
            final updated = CommentModel.fromJson(data);
            if (_matchesScope(updated, oldData: data)) {
              final index = _comments.indexWhere((c) => c.id == updated.id);
              if (index != -1) {
                _comments[index] = updated;
                _syncCacheAndNotify();
              }
            }
          } else if (event == PostgresChangeEvent.delete) {
            final id = oldData['id'];
            final before = _comments.length;
            _comments.removeWhere((c) => c.id == id);
            if (_comments.length != before) {
              _syncCacheAndNotify();
            }
          }
        } catch (e) {
          debugPrint('Error processing comments realtime update: $e');
        }
      },
    );
  }

  /// Returns true if the comment belongs to the currently-viewed scope.
  bool _matchesScope(CommentModel comment, {Map<String, dynamic>? oldData}) {
    if (_currentScope == null) return false;
    final source = oldData ?? const {};
    if (_currentScope!.startsWith('group_')) {
      final groupId = _currentScope!.substring('group_'.length);
      return (comment.groupId == groupId) || (source['group_id'] == groupId);
    } else if (_currentScope!.startsWith('vendor_')) {
      final vendorId = _currentScope!.substring('vendor_'.length);
      return (comment.vendorId == vendorId) || (source['vendor_id'] == vendorId);
    }
    return false;
  }

  void _syncCacheAndNotify() {
    notifyListeners();
    final scope = _currentScope;
    if (scope == null) return;
    _cacheDebounce?.cancel();
    _cacheDebounce = Timer(const Duration(seconds: 2), () {
      CacheService.saveCache(
        'comments_$scope',
        _comments.map((e) => e.toJson()).toList(),
      );
    });
  }

  @override
  void dispose() {
    _cacheDebounce?.cancel();
    super.dispose();
  }

  Future<void> fetchCommentsByGroup(String groupId) async {
    _currentScope = 'group_$groupId';
    final cached = await CacheService.getCache('comments_$_currentScope');
    if (cached != null) {
      _comments = cached.map((e) => CommentModel.fromJson(e)).toList();
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('comments')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      _comments = (response as List)
          .map((e) => CommentModel.fromJson(e))
          .toList();
      CacheService.saveCache(
        'comments_$_currentScope',
        _comments.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching group comments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCommentsByVendor(String vendorId) async {
    _currentScope = 'vendor_$vendorId';
    final cached = await CacheService.getCache('comments_$_currentScope');
    if (cached != null) {
      _comments = cached.map((e) => CommentModel.fromJson(e)).toList();
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('comments')
          .select()
          .or('vendor_id.eq.$vendorId,mentioned_vendor_ids.cs.{"$vendorId"}')
          .order('created_at', ascending: false);

      _comments = (response as List)
          .map((e) => CommentModel.fromJson(e))
          .toList();
      CacheService.saveCache(
        'comments_$_currentScope',
        _comments.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching vendor comments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addComment(CommentModel comment) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempComment = CommentModel(
      id: tempId,
      content: comment.content,
      vendorId: comment.vendorId,
      groupId: comment.groupId,
      createdAt: DateTime.now(),
      authorName: comment.authorName,
      authorRole: comment.authorRole,
      mentionedVendorIds: comment.mentionedVendorIds,
    );
    _comments.insert(0, tempComment);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: tempId,
        table: 'comments',
        type: OfflineActionType.create,
        data: comment.toJson(),
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final response = await _supabase
          .from('comments')
          .insert(comment.toJson())
          .select()
          .single();
      final newComment = CommentModel.fromJson(response);
      final index = _comments.indexWhere((c) => c.id == tempId);
      if (index != -1) {
        _comments[index] = newComment;
      } else {
        _comments.insert(0, newComment);
      }
      notifyListeners();
      if (_currentScope != null) {
        CacheService.saveCache(
          'comments_$_currentScope',
          _comments.map((e) => e.toJson()).toList(),
        );
      }

      SystemAuditService.logAction(
        actionType: 'ADD_COMMENT',
        affectedEntity: comment.groupId != null ? 'Group ID: ${comment.groupId}' : 'Vendor ID: ${comment.vendorId}',
        description: 'Added comment by ${comment.authorName}.',
      );
    } catch (e) {
      _comments.removeWhere((c) => c.id == tempId);
      notifyListeners();
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  Future<void> updateComment(String id, String content) async {
    final index = _comments.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final oldComment = _comments[index];
    _comments[index] = CommentModel(
      id: oldComment.id,
      content: content,
      vendorId: oldComment.vendorId,
      groupId: oldComment.groupId,
      createdAt: oldComment.createdAt,
      authorName: oldComment.authorName,
      authorRole: oldComment.authorRole,
      mentionedVendorIds: oldComment.mentionedVendorIds,
    );
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'comments',
        type: OfflineActionType.update,
        data: {'id': id, 'content': content},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      final response = await _supabase
          .from('comments')
          .update({'content': content})
          .eq('id', id)
          .select()
          .single();

      final updatedComment = CommentModel.fromJson(response);
      final idx = _comments.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _comments[idx] = updatedComment;
        notifyListeners();
      }
      if (_currentScope != null) {
        CacheService.saveCache(
          'comments_$_currentScope',
          _comments.map((e) => e.toJson()).toList(),
        );
      }

      SystemAuditService.logAction(
        actionType: 'UPDATE_COMMENT',
        affectedEntity: 'Comment ID: $id',
        description: 'Updated comment content.',
      );
    } catch (e) {
      _comments[index] = oldComment;
      notifyListeners();
      debugPrint('Error updating comment: $e');
      rethrow;
    }
  }

  Future<void> deleteComment(String id) async {
    final index = _comments.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final deletedComment = _comments.removeAt(index);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'comments',
        type: OfflineActionType.delete,
        data: {'id': id},
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.from('comments').delete().eq('id', id);
      if (_currentScope != null) {
        CacheService.saveCache(
          'comments_$_currentScope',
          _comments.map((e) => e.toJson()).toList(),
        );
      }

      SystemAuditService.logAction(
        actionType: 'DELETE_COMMENT',
        affectedEntity: 'Comment ID: $id',
        description: 'Deleted comment by ${deletedComment.authorName}.',
      );
    } catch (e) {
      _comments.insert(index, deletedComment);
      notifyListeners();
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }
}
