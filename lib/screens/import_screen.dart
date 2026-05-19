import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../services/import_service.dart';
import '../services/system_audit_service.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importService = ImportService();

  // -------------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------------

  Future<void> _pickAndImportFile() async {
    final provider = context.read<ImportProvider>();
    if (provider.isImporting) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        final fileName = result.files.first.name;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Importing "$fileName" in background…'),
              backgroundColor: Colors.blueAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Run import and pass filename for audit traceability
        provider.runImport(result.files.first.bytes!, fileName: fileName);
      } else {
        provider.setStatus('No file selected.');
      }
    } catch (e) {
      provider.setStatus('Error during import: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Backup
  // -------------------------------------------------------------------------

  Future<void> _handleBackup() async {
    final provider = context.read<ImportProvider>();
    provider.startBackup();
    provider.setStatus('Generating system backup…');

    try {
      final backupData = await _importService.generateBackup();
      final jsonString = jsonEncode(backupData);
      final encryptedString = base64Encode(utf8.encode(jsonString));
      final bytes = utf8.encode(encryptedString);

      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'NSBSA_Backup_${DateTime.now().toIso8601String().split('T')[0]}.nsbsa',
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      await SystemAuditService.logAction(
        actionType: 'BACKUP',
        affectedEntity: 'SYSTEM',
        description: 'Generated and downloaded a system backup.',
      );

      provider.endBackup('Backup generated and downloaded successfully.');
    } catch (e) {
      provider.endBackup('Backup failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Restore
  // -------------------------------------------------------------------------

  Future<void> _handleRestore() async {
    final provider = context.read<ImportProvider>();
    provider.startRestore();
    provider.setStatus('Selecting backup file…');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null) {
        provider.setStatus('Decrypting and restoring data…');
        final encryptedString = utf8.decode(result.files.first.bytes!);
        final jsonString = utf8.decode(base64Decode(encryptedString));
        final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

        await _importService.restoreBackup(backupData);

        await SystemAuditService.logAction(
          actionType: 'RESTORE',
          affectedEntity: 'SYSTEM',
          description: 'Restored system from a backup file.',
        );

        provider.endRestore('System restored successfully!');
      } else {
        provider.endRestore(null);
      }
    } catch (e) {
      provider.endRestore('Restore failed: Ensure the file is valid. $e');
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final importProvider = context.watch<ImportProvider>();

    final isSuperAdmin = authProvider.userRole == 'Super Admin';
    final isAdmin = authProvider.userRole == 'Admin' || isSuperAdmin;
    final isLoadingAny = importProvider.isImporting ||
        importProvider.isBackupRunning ||
        importProvider.isRestoreRunning;

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 860),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────────
                Icon(Icons.upload_file, size: 64, color: theme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Data Management',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload Excel files to populate the system or manage system backups.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[400]),
                ),
                const SizedBox(height: 40),

                // ── Action cards ────────────────────────────────────────────
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildActionCard(
                      title: 'Import Excel',
                      description:
                          'Import groups, vendors and loans from the VES Loan Book. '
                          'Month sheets are automatically detected and verified.',
                      icon: Icons.table_view,
                      buttonLabel: 'Select Excel File',
                      onPressed: _pickAndImportFile,
                      isLoading: importProvider.isImporting,
                      color: theme.primaryColor,
                    ),
                    if (isAdmin)
                      _buildActionCard(
                        title: 'Backup System',
                        description:
                            'Export all records to a secure encrypted file.',
                        icon: Icons.backup,
                        buttonLabel: 'Backup Data',
                        onPressed: _handleBackup,
                        isLoading: importProvider.isBackupRunning,
                        color: Colors.blueAccent,
                      ),
                  ],
                ),

                if (isSuperAdmin) ...[
                  const SizedBox(height: 24),
                  _buildActionCard(
                    title: 'Restore System',
                    description:
                        'Restore the entire platform from a previously saved backup file.',
                    icon: Icons.restore,
                    buttonLabel: 'Restore Data',
                    onPressed: () => _confirmRestore(context),
                    isLoading: importProvider.isRestoreRunning,
                    color: Colors.orangeAccent,
                    fullWidth: true,
                  ),
                ],

                // ── Status / progress ────────────────────────────────────────
                if (importProvider.statusMessage != null) ...[
                  const SizedBox(height: 32),
                  _buildStatusBanner(importProvider, isLoadingAny),
                ],

                // ── Per-month verification results ───────────────────────────
                if (importProvider.lastImportResult != null &&
                    !importProvider.isImporting) ...[
                  const SizedBox(height: 24),
                  _buildVerificationPanel(importProvider.lastImportResult!),
                ],

                const SizedBox(height: 64),

                // ── Danger zone ─────────────────────────────────────────────
                if (isSuperAdmin) ...[
                  const Divider(),
                  const SizedBox(height: 32),
                  const Text(
                    'Danger Zone',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Warning: This will permanently delete all groups, members, '
                    'loans, and payments from the system.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _confirmClearData,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Clear All Data',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Status banner widget
  // -------------------------------------------------------------------------

  Widget _buildStatusBanner(ImportProvider provider, bool isLoadingAny) {
    final msg = provider.statusMessage!;
    final isError = msg.toLowerCase().contains('error') ||
        msg.toLowerCase().contains('failed') ||
        msg.toLowerCase().contains('could not');
    final isSuccess = !isError && !isLoadingAny;

    final Color borderColor =
        isError ? Colors.redAccent : (isSuccess ? Colors.green : Colors.blue);
    final Color bgColor = borderColor.withOpacity(0.08);
    final IconData icon = isError
        ? Icons.error_outline
        : (isLoadingAny ? Icons.hourglass_top_rounded : Icons.check_circle_outline);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoadingAny)
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                  ),
                )
              else
                Icon(icon, color: borderColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (provider.isImporting && provider.progress > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.progress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(provider.progress * 100).toInt()}% complete',
                style: TextStyle(
                  color: borderColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Per-month verification panel
  // -------------------------------------------------------------------------

  Widget _buildVerificationPanel(ImportResult result) {
    final allGood = result.allMonthsMatch && result.success;
    final headerColor = allGood ? Colors.green : Colors.orangeAccent;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: headerColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: headerColor.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Icon(
                  allGood
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: headerColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Month-by-Month Verification Report',
                    style: TextStyle(
                      color: headerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Summary badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${result.totalRecordsImported} / ${result.totalRecordsInExcel} records',
                    style: TextStyle(
                      color: headerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Month rows table header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: _tableHeaderCell('Excel Sheet Label')),
                Expanded(
                    flex: 2,
                    child: _tableHeaderCell('Mapped Month')),
                Expanded(child: _tableHeaderCell('In File')),
                Expanded(child: _tableHeaderCell('Imported')),
                const SizedBox(width: 60),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Month rows
          ...result.monthSummaries.map((s) => _buildMonthRow(s)),

          // Errors section (if any)
          if (result.errors.isNotEmpty) ...[
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Row-level errors (import continued for other rows)',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...result.errors.take(5).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $e',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ),
                  if (result.errors.length > 5)
                    Text(
                      '… and ${result.errors.length - 5} more errors.',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],

          // Bottom summary
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: allGood
                  ? Colors.green.withOpacity(0.07)
                  : Colors.orangeAccent.withOpacity(0.07),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  allGood ? Icons.check_circle : Icons.info_outline,
                  color: allGood ? Colors.green : Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.verificationMessage,
                    style: TextStyle(
                      color: allGood ? Colors.green : Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthRow(MonthImportSummary s) {
    final matched = s.matched;
    final rowColor = matched ? Colors.green : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Raw Excel label – preserved exactly as in the file
          Expanded(
            flex: 3,
            child: Text(
              s.rawSheetLabel,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white70,
                  fontSize: 12),
            ),
          ),
          // Mapped canonical month name
          Expanded(
            flex: 2,
            child: Text(
              s.monthLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
          // In-file count
          Expanded(
            child: Text(
              '${s.rowsInExcel}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          // Imported count (coloured)
          Expanded(
            child: Text(
              '${s.rowsImported}',
              style: TextStyle(
                  color: rowColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          // Status badge
          SizedBox(
            width: 60,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: rowColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                matched ? '✓ OK' : '✗ Mismatch',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: rowColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String label) => Text(
        label,
        style: const TextStyle(
            color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
      );

  // -------------------------------------------------------------------------
  // Action card
  // -------------------------------------------------------------------------

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required String buttonLabel,
    required VoidCallback onPressed,
    required bool isLoading,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(description,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor:
                    color == Theme.of(context).primaryColor
                        ? Colors.black
                        : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Confirmation dialogs
  // -------------------------------------------------------------------------

  void _confirmRestore(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Text('System Restore'),
          ],
        ),
        content: const Text(
          'Restoring from a backup will OVERWRITE all current system data. '
          'This action cannot be undone. Are you sure you want to proceed?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleRestore();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent),
            child: const Text('Yes, Proceed with Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'This will permanently wipe all groups, members, and loans. '
          'Please ensure you have a backup before proceeding.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<ImportProvider>();
              Navigator.pop(context);
              provider.setStatus('Clearing all data…');
              try {
                await _importService.clearAllData();
                await SystemAuditService.logAction(
                  actionType: 'SYSTEM_WIPE',
                  affectedEntity: 'SYSTEM',
                  description: 'Cleared all system data.',
                );
                provider.setStatus('System reset successfully!');
              } catch (e) {
                provider.setStatus('Error clearing data: $e');
              }
            },
            child: const Text(
              'Yes, Delete Everything',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
