import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../services/import_service.dart';
import '../services/system_audit_service.dart';
import '../providers/auth_provider.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importService = ImportService();
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _pickAndImportFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting file...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result != null) {
        setState(
          () => _statusMessage = 'Importing data... this may take a moment.',
        );
        await _importService.importExcel(result.files.first.bytes!);

        await SystemAuditService.logAction(
          actionType: 'IMPORT',
          affectedEntity: 'SYSTEM',
          description: 'Imported Excel loan book data.',
        );

        setState(() => _statusMessage = 'Import successful!');
      } else {
        setState(() => _statusMessage = 'No file selected.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error during import: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating system backup...';
    });

    try {
      final backupData = await _importService.generateBackup();
      final jsonString = jsonEncode(backupData);

      // Basic Encryption (Base64) - in production use a real encryption key
      final encryptedString = base64Encode(utf8.encode(jsonString));

      final bytes = utf8.encode(encryptedString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          "download",
          "NSBSA_Backup_${DateTime.now().toIso8601String().split('T')[0]}.nsbsa",
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      await SystemAuditService.logAction(
        actionType: 'BACKUP',
        affectedEntity: 'SYSTEM',
        description: 'Generated and downloaded a system backup.',
      );

      setState(
        () => _statusMessage = 'Backup generated and downloaded successfully.',
      );
    } catch (e) {
      setState(() => _statusMessage = 'Backup failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting backup file...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null) {
        setState(() => _statusMessage = 'Decrypting and restoring data...');

        final encryptedString = utf8.decode(result.files.first.bytes!);
        final jsonString = utf8.decode(base64Decode(encryptedString));
        final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

        await _importService.restoreBackup(backupData);

        await SystemAuditService.logAction(
          actionType: 'RESTORE',
          affectedEntity: 'SYSTEM',
          description: 'Restored system from a backup file.',
        );

        setState(() => _statusMessage = 'System restored successfully!');
      }
    } catch (e) {
      setState(
        () => _statusMessage =
            'Restore failed: Ensure the file is a valid NSBSA backup. Error: $e',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isSuperAdmin = authProvider.userRole == 'Super Admin';
    final isAdmin = authProvider.userRole == 'Admin' || isSuperAdmin;

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Header & Import
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 40),

                // Main Actions
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildActionCard(
                      title: 'Import Excel',
                      description:
                          'Import groups, vendors and loans from "VES Loan Book".',
                      icon: Icons.table_view,
                      buttonLabel: 'Select Excel File',
                      onPressed: _pickAndImportFile,
                      isLoading: _isLoading,
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
                        isLoading: _isLoading,
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
                    isLoading: _isLoading,
                    color: Colors.orangeAccent,
                    fullWidth: true,
                  ),
                ],

                if (_statusMessage != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          _statusMessage!.contains('Error') ||
                              _statusMessage!.contains('failed')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _statusMessage!.contains('Error') ||
                                _statusMessage!.contains('failed')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusMessage!.contains('Error') ||
                                  _statusMessage!.contains('failed')
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color:
                              _statusMessage!.contains('Error') ||
                                  _statusMessage!.contains('failed')
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color:
                                  _statusMessage!.contains('Error') ||
                                      _statusMessage!.contains('failed')
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 64),

                // Danger Zone - ONLY Super Admin
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
                    'Warning: This will permanently delete all groups, members, loans, and payments from the system.',
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
                        horizontal: 32,
                        vertical: 16,
                      ),
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: color == Theme.of(context).primaryColor
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
              backgroundColor: Colors.orangeAccent,
            ),
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
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
                _statusMessage = 'Clearing all data...';
              });
              try {
                await _importService.clearAllData();
                await SystemAuditService.logAction(
                  actionType: 'SYSTEM_WIPE',
                  affectedEntity: 'SYSTEM',
                  description: 'Cleared all system data.',
                );
                setState(() => _statusMessage = 'System reset successfully!');
              } catch (e) {
                setState(() => _statusMessage = 'Error clearing data: $e');
              } finally {
                setState(() => _isLoading = false);
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
