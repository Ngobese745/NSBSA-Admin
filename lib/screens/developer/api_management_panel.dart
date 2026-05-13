import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class ApiManagementPanel extends StatefulWidget {
  const ApiManagementPanel({super.key});

  @override
  State<ApiManagementPanel> createState() => _ApiManagementPanelState();
}

class _ApiManagementPanelState extends State<ApiManagementPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApiManagementProvider>().fetchKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiProv = context.watch<ApiManagementProvider>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Third-Party API Integration',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Manage secure keys for messaging and external services',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddKeyDialog(context),
                icon: const Icon(Icons.add_link, size: 18),
                label: const Text('Add New Integration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (apiProv.isLoading && apiProv.keys.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (apiProv.keys.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No API integrations configured.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  _ServiceSection(
                    title: 'WeSender API',
                    serviceKey: 'wesender',
                    keys: apiProv.keys.where((k) => k['service_name'] == 'wesender').toList(),
                  ),
                  const SizedBox(height: 32),
                  _ServiceSection(
                    title: 'SMSWORX API',
                    serviceKey: 'smsworx',
                    keys: apiProv.keys.where((k) => k['service_name'] == 'smsworx').toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddKeyDialog(BuildContext context) {
    // Basic dialog to pick a service and add a key
    _openKeyEditor(context, null);
  }
}

class _ServiceSection extends StatelessWidget {
  final String title;
  final String serviceKey;
  final List<Map<String, dynamic>> keys;

  const _ServiceSection({required this.title, required this.serviceKey, required this.keys});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeKey = keys.cast<Map<String, dynamic>?>().firstWhere((k) => k?['status'] == 'active', orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: activeKey != null ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                activeKey != null ? 'CONNECTED' : 'DISCONNECTED',
                style: TextStyle(
                  color: activeKey != null ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (activeKey == null)
          _EmptyKeyPlaceholder(serviceKey: serviceKey)
        else
          _ApiKeyCard(keyData: activeKey),
      ],
    );
  }
}

class _ApiKeyCard extends StatelessWidget {
  final Map<String, dynamic> keyData;

  const _ApiKeyCard({required this.keyData});

  String _maskKey(String key) {
    if (key.length <= 8) return '••••${key.substring(key.length - 2)}';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiProv = context.read<ApiManagementProvider>();
    final auth = context.read<AuthProvider>();

    return Card(
      color: theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(keyData['label'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _maskKey(keyData['api_key']),
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openKeyEditor(context, keyData),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Update'),
                ),
                IconButton(
                  onPressed: () => _confirmRevoke(context, keyData),
                  icon: const Icon(Icons.link_off, color: Colors.redAccent),
                  tooltip: 'Revoke Access',
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Added: ${keyData['created_at'].toString().substring(0, 10)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await apiProv.testConnection(keyData['service_name'], keyData['api_key']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Connection Successful!' : 'Connection Failed'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRevoke(BuildContext context, Map<String, dynamic> keyData) async {
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke API Key?'),
        content: Text('Are you sure you want to revoke access for ${keyData['label']}? This will disconnect the service immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ApiManagementProvider>().revokeKey(
        keyData['id'],
        keyData['service_name'],
        auth.userProfile!.id,
        auth.userProfile!.email!,
      );
    }
  }
}

class _EmptyKeyPlaceholder extends StatelessWidget {
  final String serviceKey;
  const _EmptyKeyPlaceholder({required this.serviceKey});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openKeyEditor(context, {'service_name': serviceKey}),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05), style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.vpn_key_outlined, color: Colors.white.withOpacity(0.2), size: 32),
            const SizedBox(height: 12),
            const Text('No active key. Tap to configure.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

Future<void> _openKeyEditor(BuildContext context, Map<String, dynamic>? existing) async {
  final auth = context.read<AuthProvider>();
  final apiProv = context.read<ApiManagementProvider>();
  
  final labelCtrl = TextEditingController(text: existing?['label'] ?? '');
  final keyCtrl = TextEditingController();
  String service = existing?['service_name'] ?? 'wesender';

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing?['id'] == null ? 'Configure Integration' : 'Update API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: service,
              decoration: const InputDecoration(labelText: 'Service Provider'),
              items: const [
                DropdownMenuItem(value: 'wesender', child: Text('WeSender API')),
                DropdownMenuItem(value: 'smsworx', child: Text('SMSWORX API')),
              ],
              onChanged: existing?['id'] != null ? null : (v) => setLocal(() => service = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Description / Label', hintText: 'e.g. Production Key 2025'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your secure key',
                helperText: 'Key will be masked and stored securely.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (keyCtrl.text.isEmpty) return;
              final testOk = await apiProv.testConnection(service, keyCtrl.text);
              if (testOk && ctx.mounted) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Test & Save'),
          ),
        ],
      ),
    ),
  );

  if (result == true && context.mounted) {
    try {
      await apiProv.saveKey(
        serviceName: service,
        label: labelCtrl.text,
        apiKey: keyCtrl.text,
        userId: auth.userProfile!.id,
        userEmail: auth.userProfile!.email!,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Integration Saved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
