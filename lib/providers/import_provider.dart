import 'package:flutter/material.dart';
import '../services/import_service.dart';
import '../services/system_audit_service.dart';

class ImportProvider with ChangeNotifier {
  final _importService = ImportService();
  
  bool _isImporting = false;
  bool get isImporting => _isImporting;
  
  double _progress = 0.0;
  double get progress => _progress;
  
  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  bool _isBackupRunning = false;
  bool get isBackupRunning => _isBackupRunning;

  bool _isRestoreRunning = false;
  bool get isRestoreRunning => _isRestoreRunning;

  Future<void> runImport(List<int> bytes) async {
    if (_isImporting) return;

    _isImporting = true;
    _progress = 0.0;
    _statusMessage = 'Starting import...';
    notifyListeners();

    try {
      await _importService.importExcel(
        bytes,
        onProgress: (prog, msg) {
          _progress = prog;
          _statusMessage = msg;
          notifyListeners();
        },
      );

      await SystemAuditService.logAction(
        actionType: 'IMPORT',
        affectedEntity: 'SYSTEM',
        description: 'Imported Excel loan book data in background.',
      );

      _statusMessage = 'Import completed successfully.';
      _progress = 1.0;
    } catch (e) {
      _statusMessage = 'Import failed: $e';
    } finally {
      _isImporting = false;
      notifyListeners();
      
      // Clear status after some time if finished
      Future.delayed(const Duration(seconds: 10), () {
        if (!_isImporting) {
          _statusMessage = null;
          _progress = 0;
          notifyListeners();
        }
      });
    }
  }

  void setStatus(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  void startBackup() {
    _isBackupRunning = true;
    notifyListeners();
  }

  void endBackup(String? message) {
    _isBackupRunning = false;
    _statusMessage = message;
    notifyListeners();
  }

  void startRestore() {
    _isRestoreRunning = true;
    notifyListeners();
  }

  void endRestore(String? message) {
    _isRestoreRunning = false;
    _statusMessage = message;
    notifyListeners();
  }
}
