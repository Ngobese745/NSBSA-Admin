import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class DocumentProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<DocumentModel> _documents = [];
  bool _isLoading = false;
  String? _currentScope;

  List<DocumentModel> get documents => _documents;
  bool get isLoading => _isLoading;

  Future<void> fetchDocumentsByGroup(String groupId) async {
    _currentScope = 'group_$groupId';
    final cached = await CacheService.getCache('documents_$_currentScope');
    if (cached != null) {
      _documents = cached.map((e) => DocumentModel.fromJson(e)).toList();
    }

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
      CacheService.saveCache(
        'documents_$_currentScope',
        _documents.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching group documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDocumentsByVendor(String vendorId) async {
    _currentScope = 'vendor_$vendorId';
    final cached = await CacheService.getCache('documents_$_currentScope');
    if (cached != null) {
      _documents = cached.map((e) => DocumentModel.fromJson(e)).toList();
    }

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
      CacheService.saveCache(
        'documents_$_currentScope',
        _documents.map((e) => e.toJson()).toList(),
      );
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
    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'documents',
        type: OfflineActionType.create,
        data: {
          'group_id': groupId,
          'vendor_id': vendorId,
          'file_name': fileName,
          'file_bytes_base64': base64Encode(fileBytes),
          'file_type': fileName.split('.').last,
        },
        timestamp: DateTime.now(),
      ));
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final String folder = groupId != null
          ? 'groups/$groupId'
          : 'vendors/$vendorId';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path = '$folder/${timestamp}_$fileName';

      await _supabase.storage
          .from('documents')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

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

      _documents.insert(0, DocumentModel.fromJson(response));
      notifyListeners();
      if (_currentScope != null) {
        CacheService.saveCache(
          'documents_$_currentScope',
          _documents.map((e) => e.toJson()).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error in uploadDocument: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDocument(DocumentModel document) async {
    final index = _documents.indexWhere((d) => d.id == document.id);
    if (index == -1) return;

    final deletedDoc = _documents.removeAt(index);
    notifyListeners();

    if (ConnectivityService().currentStatus == AppConnectivityStatus.offline) {
      await OfflineQueueService().queueAction(OfflineAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        table: 'documents',
        type: OfflineActionType.delete,
        data: {
          'id': document.id,
          'file_path': document.filePath,
        },
        timestamp: DateTime.now(),
      ));
      return;
    }

    try {
      await _supabase.storage.from('documents').remove([document.filePath]);
      await _supabase.from('documents').delete().eq('id', document.id);
      if (_currentScope != null) {
        CacheService.saveCache(
          'documents_$_currentScope',
          _documents.map((e) => e.toJson()).toList(),
        );
      }
    } catch (e) {
      _documents.insert(index, deletedDoc);
      notifyListeners();
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  String getPublicUrl(String path) {
    return _supabase.storage.from('documents').getPublicUrl(path);
  }
}
