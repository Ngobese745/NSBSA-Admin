import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class CommentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  String? _currentScope;

  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;

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
    } catch (e) {
      _comments.insert(index, deletedComment);
      notifyListeners();
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }
}
