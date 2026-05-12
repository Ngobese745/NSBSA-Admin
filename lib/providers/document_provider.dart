import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';

class DocumentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<DocumentModel> _documents = [];
  bool _isLoading = false;

  List<DocumentModel> get documents => _documents;
  bool get isLoading => _isLoading;

  Future<void> fetchDocumentsByGroup(String groupId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('documents')
          .select()
          .eq('group_id', groupId)
          .order('uploaded_at', ascending: false);

      _documents = (response as List)
          .map((e) => DocumentModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching group documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDocumentsByVendor(String vendorId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('documents')
          .select()
          .eq('vendor_id', vendorId)
          .order('uploaded_at', ascending: false);

      _documents = (response as List)
          .map((e) => DocumentModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching vendor documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadDocument({
    String? groupId,
    String? vendorId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final String folder = groupId != null
          ? 'groups/$groupId'
          : 'vendors/$vendorId';
      debugPrint('Starting upload for $fileName to $folder');
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = '$folder/$timestamp\_$fileName';

      // 1. Upload to Supabase Storage
      await _supabase.storage
          .from('documents')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      debugPrint('Storage upload successful: $path');

      // 2. Save metadata to database
      final docMetadata = DocumentModel(
        id: '',
        groupId: groupId,
        vendorId: vendorId,
        fileName: fileName,
        filePath: path,
        fileType: fileName.split('.').last,
        uploadedAt: DateTime.now(),
      );

      final response = await _supabase
          .from('documents')
          .insert(docMetadata.toJson())
          .select()
          .single();
      debugPrint('Database metadata saved');
      _documents.insert(0, DocumentModel.fromJson(response));
    } catch (e) {
      debugPrint('Error in uploadDocument: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(DocumentModel document) async {
    try {
      // 1. Delete from Storage
      await _supabase.storage.from('documents').remove([document.filePath]);

      // 2. Delete from Database
      await _supabase.from('documents').delete().eq('id', document.id);

      _documents.removeWhere((doc) => doc.id == document.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  String getPublicUrl(String path) {
    return _supabase.storage.from('documents').getPublicUrl(path);
  }
}
