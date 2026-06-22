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

  /// Null until the most recent import finishes.
  ImportResult? _lastImportResult;
  ImportResult? get lastImportResult => _lastImportResult;

  /// True when the last import finished with full month verification passing.
  bool get lastImportSuccess =>
      _lastImportResult?.success == true &&
      _lastImportResult?.allMonthsMatch == true;

  Future<void> runImport(List<int> bytes,
      {String fileName = 'unknown.xlsx', bool autoAssignToCurrentMonth = true}) async {
    if (_isImporting) return;

    _isImporting = true;
    _lastImportResult = null;
    _progress = 0.0;
    _statusMessage = 'Starting import…';
    notifyListeners();

    try {
      final result = await _importService.importExcel(
        bytes,
        fileName: fileName,
        autoAssignToCurrentMonth: autoAssignToCurrentMonth,
        onProgress: (prog, msg) {
          _progress = prog;
          _statusMessage = msg;
          notifyListeners();
        },
      );

      _lastImportResult = result;

      // The audit entry with per-month detail is already written inside
      // ImportService.importExcel.  We write a brief summary here too for
      // backward compatibility with existing audit-log viewers.
      await SystemAuditService.logAction(
        actionType: 'IMPORT',
        affectedEntity: 'EXCEL_IMPORT',
        description: 'File: $fileName | '
            'Records: ${result.totalRecordsImported}/${result.totalRecordsInExcel} | '
            'All months match: ${result.allMonthsMatch}',
      );

      _statusMessage = result.verificationMessage;
      _progress = 1.0;
    } catch (e) {
      _statusMessage = e.toString().startsWith('Exception:')
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Month values could not be imported correctly. '
              'Please check your Excel file format. ($e)';
    } finally {
      _isImporting = false;
      notifyListeners();

      // Auto-clear status after 20 s so the UI is not stuck.
      Future.delayed(const Duration(seconds: 20), () {
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
