import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';

class CommentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<CommentModel> _comments = [];
  bool _isLoading = false;

  List<CommentModel> get comments => _comments;
  bool get isLoading => _isLoading;

  Future<void> fetchCommentsByGroup(String groupId) async {
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
    } catch (e) {
      debugPrint('Error fetching group comments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCommentsByVendor(String vendorId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch comments where vendor_id is explicitly set OR where vendor is mentioned
      final response = await _supabase
          .from('comments')
          .select()
          .or('vendor_id.eq.$vendorId,mentioned_vendor_ids.cs.{"$vendorId"}')
          .order('created_at', ascending: false);

      _comments = (response as List)
          .map((e) => CommentModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching vendor comments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addComment(CommentModel comment) async {
    try {
      final response = await _supabase
          .from('comments')
          .insert(comment.toJson())
          .select()
          .single();
      final newComment = CommentModel.fromJson(response);
      _comments.insert(0, newComment);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  Future<void> updateComment(String id, String content) async {
    try {
      final response = await _supabase
          .from('comments')
          .update({'content': content})
          .eq('id', id)
          .select()
          .single();

      final updatedComment = CommentModel.fromJson(response);
      final index = _comments.indexWhere((c) => c.id == id);
      if (index != -1) {
        _comments[index] = updatedComment;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating comment: $e');
      rethrow;
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await _supabase.from('comments').delete().eq('id', id);
      _comments.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }
}
