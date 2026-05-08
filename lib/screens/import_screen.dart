import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _importService = ImportService();
  bool _isImporting = false;
  String? _statusMessage;

  Future<void> _pickAndImportFile() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'Selecting file...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result != null) {
        setState(() => _statusMessage = 'Importing data... this may take a moment.');
        await _importService.importExcel(result.files.first.bytes!);
        setState(() => _statusMessage = 'Import successful!');
      } else {
        setState(() => _statusMessage = 'No file selected.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error during import: $e');
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.upload_file,
                size: 80,
                color: theme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Upload your "VES Loan Book" Excel file to automatically populate the system with groups, vendors, and loans.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
              ),
              const SizedBox(height: 48),
              if (_isImporting)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickAndImportFile,
                  icon: const Icon(Icons.add),
                  label: const Text('Select Excel File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains('Error') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const Spacer(),
              const Divider(height: 64),
              const Text(
                'Danger Zone',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Warning: This will permanently delete all groups, members, loans, and payments from the system.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _confirmClearData,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Are you absolutely sure?', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        content: const Text('This action cannot be undone. All data will be permanently wiped.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isImporting = true;
                _statusMessage = 'Clearing all data...';
              });
              try {
                await _importService.clearAllData();
                setState(() => _statusMessage = 'System reset successfully!');
              } catch (e) {
                setState(() => _statusMessage = 'Error clearing data: $e');
              } finally {
                setState(() => _isImporting = false);
              }
            },
            child: const Text('Yes, Delete Everything', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
