import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/system_audit_log_model.dart';
import '../services/system_audit_service.dart';
import '../services/audit_pdf_service.dart';

import '../core/pdf_branding.dart';
import '../models/developer_controls.dart';
import '../providers/auth_provider.dart';
import '../providers/developer_controls_provider.dart';
import '../services/access_control_service.dart';
import '../theme/app_theme.dart';

/// Super Admin + allowlisted developer only (see [AccessControlService.canAccessDeveloperTools]).
class DeveloperManagementScreen extends StatefulWidget {
  const DeveloperManagementScreen({super.key});

  @override
  State<DeveloperManagementScreen> createState() =>
      _DeveloperManagementScreenState();
}

class _DeveloperManagementScreenState extends State<DeveloperManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeveloperControlsProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    if (!AccessControlService.canAccessDeveloperTools(auth.userProfile)) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'You do not have access to Developer Management.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Icon(
                  Icons.developer_mode,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Developer Management',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                  onPressed: () =>
                      context.read<DeveloperControlsProvider>().refresh(),
                ),
              ],
            ),
          ),
          Consumer<DeveloperControlsProvider>(
            builder: (context, dev, _) {
              if (dev.tablesMissing) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Material(
                    color: Colors.deepOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Developer tables are not installed. Run '
                        'supabase/migrations/20250512120002_developer_controls.sql in Supabase SQL Editor.',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Material(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryGold,
              labelColor: AppTheme.primaryGold,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Banners', icon: Icon(Icons.campaign, size: 18)),
                Tab(
                  text: 'Feature toggles',
                  icon: Icon(Icons.toggle_on, size: 18),
                ),
                Tab(text: 'Activity log', icon: Icon(Icons.history, size: 18)),
                Tab(
                  text: 'System Audit Log',
                  icon: Icon(Icons.security, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _BannersPanel(),
                _FeaturesPanel(),
                _ActivityLogPanel(),
                _SystemAuditLogPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannersPanel extends StatelessWidget {
  const _BannersPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<DeveloperControlsProvider>(
      builder: (context, dev, _) {
        if (dev.isLoading && dev.banners.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FilledButton.icon(
              onPressed: dev.tablesMissing
                  ? null
                  : () => _openBannerEditor(context, null),
              icon: const Icon(Icons.add),
              label: const Text('New banner'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            if (dev.banners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No banners yet. Create one to show a system-wide notice.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...dev.banners.map((b) => _BannerCard(banner: b)),
          ],
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final SystemBannerModel banner;

  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dev = context.watch<DeveloperControlsProvider>();
    final auth = context.watch<AuthProvider>();
    final uid = auth.userProfile?.id;
    final email = auth.userProfile?.email;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    banner.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  banner.isEnabled ? 'ON' : 'off',
                  style: TextStyle(
                    color: banner.isEnabled ? Colors.greenAccent : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                Switch(
                  value: banner.isEnabled,
                  activeThumbColor: AppTheme.primaryGold,
                  onChanged: dev.tablesMissing || uid == null
                      ? null
                      : (v) async {
                          try {
                            await dev.setBannerEnabled(
                              bannerId: banner.id,
                              enabled: v,
                              developerId: uid,
                              developerEmail: email,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              banner.message,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    banner.bannerType,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    banner.severity,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: dev.tablesMissing
                      ? null
                      : () => _openBannerEditor(context, banner),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: dev.tablesMissing
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete banner?'),
                              content: const Text('This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted && uid != null) {
                            try {
                              await dev.removeBanner(
                                bannerId: banner.id,
                                developerId: uid,
                                developerEmail: email,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openBannerEditor(
  BuildContext context,
  SystemBannerModel? existing,
) async {
  final dev = context.read<DeveloperControlsProvider>();
  final auth = context.read<AuthProvider>();
  final uid = auth.userProfile?.id;
  final email = auth.userProfile?.email;
  if (uid == null) return;

  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final messageCtrl = TextEditingController(text: existing?.message ?? '');
  String type = existing?.bannerType ?? 'system_update';
  String severity = existing?.severity ?? 'warning';
  DateTime startsAt = existing?.startsAt ?? DateTime.now();
  DateTime? endsAt = existing?.endsAt;

  final enableState = <bool>[existing?.isEnabled ?? false];

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Create banner' : 'Edit banner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                subtitle: const Text(
                  'Only one live banner; enabling turns others off.',
                ),
                value: enableState[0],
                activeThumbColor: AppTheme.primaryGold,
                onChanged: (v) => setLocal(() => enableState[0] = v),
              ),
              const Divider(),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Banner type'),
                items: const [
                  DropdownMenuItem(
                    value: 'system_update',
                    child: Text('System update'),
                  ),
                  DropdownMenuItem(
                    value: 'under_development',
                    child: Text('Under development'),
                  ),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const [
                  DropdownMenuItem(value: 'info', child: Text('Info')),
                  DropdownMenuItem(value: 'warning', child: Text('Warning')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) => setLocal(() => severity = v ?? severity),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Starts'),
                subtitle: Text(startsAt.toLocal().toString().substring(0, 16)),
                trailing: IconButton(
                  icon: const Icon(Icons.event),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: startsAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null)
                      setLocal(
                        () => startsAt = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          startsAt.hour,
                          startsAt.minute,
                        ),
                      );
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ends (optional)'),
                subtitle: Text(
                  endsAt == null
                      ? 'No end — stays until disabled'
                      : endsAt!.toLocal().toString().substring(0, 16),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (endsAt != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setLocal(() => endsAt = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.event),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate:
                              endsAt ??
                              DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setLocal(
                            () => endsAt = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              23,
                              59,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) return;

  try {
    if (existing == null) {
      await dev.createBanner(
        bannerType: type,
        title: titleCtrl.text.trim(),
        message: messageCtrl.text.trim(),
        severity: severity,
        isEnabled: enableState[0],
        startsAt: startsAt.toUtc(),
        endsAt: endsAt?.toUtc(),
        developerId: uid,
        developerEmail: email,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Banner saved')));
      }
    } else {
      final updated = SystemBannerModel(
        id: existing.id,
        bannerType: type,
        title: titleCtrl.text.trim(),
        message: messageCtrl.text.trim(),
        severity: severity,
        isEnabled: enableState[0],
        startsAt: startsAt.toUtc(),
        endsAt: endsAt?.toUtc(),
        createdAt: existing.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await dev.saveBanner(updated, developerId: uid, developerEmail: email);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Banner updated')));
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _FeaturesPanel extends StatelessWidget {
  const _FeaturesPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<DeveloperControlsProvider>(
      builder: (context, dev, _) {
        if (dev.isLoading && dev.flags.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (dev.flags.isEmpty) {
          return const Center(
            child: Text(
              'No feature flags loaded.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        final auth = context.watch<AuthProvider>();
        final uid = auth.userProfile?.id;
        final email = auth.userProfile?.email;

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: dev.flags.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final f = dev.flags[i];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: SwitchListTile(
                secondary: Icon(
                  f.enabled ? Icons.check_circle : Icons.block,
                  color: f.enabled ? Colors.green : Colors.grey,
                ),
                title: Text(f.label),
                subtitle: Text(
                  f.featureKey,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: f.enabled,
                activeThumbColor: AppTheme.primaryGold,
                onChanged: dev.tablesMissing || uid == null
                    ? null
                    : (v) async {
                        try {
                          await dev.setFeatureFlag(
                            featureKey: f.featureKey,
                            enabled: v,
                            developerId: uid,
                            developerEmail: email,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityLogPanel extends StatefulWidget {
  const _ActivityLogPanel();

  @override
  State<_ActivityLogPanel> createState() => _ActivityLogPanelState();
}

class _ActivityLogPanelState extends State<_ActivityLogPanel> {
  String? _developerFilter;
  String? _actionFilter;
  DateTimeRange? _dateRangeFilter;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeveloperControlsProvider>(
      builder: (context, dev, _) {
        if (dev.isLoading && dev.recentLogs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (dev.recentLogs.isEmpty) {
          return const Center(
            child: Text(
              'No developer actions logged yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        final filteredLogs = _applyFilters(dev.recentLogs);
        final developerOptions = _developerOptions(dev.recentLogs);
        final actionOptions = _actionOptions(dev.recentLogs);

        return RefreshIndicator(
          onRefresh: dev.reloadLogsOnly,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: _developerFilter,
                      decoration: const InputDecoration(
                        labelText: 'Developer',
                        prefixIcon: Icon(Icons.person_search, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All developers'),
                        ),
                        ...developerOptions.map(
                          (developer) => DropdownMenuItem(
                            value: developer,
                            child: Text(
                              developer,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _developerFilter = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: _actionFilter,
                      decoration: const InputDecoration(
                        labelText: 'Action type',
                        prefixIcon: Icon(Icons.tune, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All actions'),
                        ),
                        ...actionOptions.map(
                          (action) => DropdownMenuItem(
                            value: action,
                            child: Text(
                              action,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _actionFilter = value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDateRange(context),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _dateRangeFilter == null
                          ? 'All dates'
                          : '${_formatDate(_dateRangeFilter!.start)} - ${_formatDate(_dateRangeFilter!.end)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _hasFilters
                        ? () {
                            setState(() {
                              _developerFilter = null;
                              _actionFilter = null;
                              _dateRangeFilter = null;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear filters'),
                  ),
                  FilledButton.icon(
                    onPressed: dev.tablesMissing || filteredLogs.isEmpty
                        ? null
                        : () => _downloadActivityLogsPdf(
                            context,
                            filteredLogs,
                            filterSummary: _filterSummary,
                          ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Download Logs (PDF)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (filteredLogs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No activity log entries match the selected filters.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...filteredLogs.map((log) {
                  final when = _formatDateTime(log.createdAt);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.bolt,
                        color: AppTheme.primaryGold,
                        size: 20,
                      ),
                      title: Text(
                        log.actionType,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '$when • ${_developerLabel(log)}\n'
                        '${_logDescription(log)}',
                        style: const TextStyle(fontSize: 11, height: 1.4),
                      ),
                      isThreeLine: true,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  bool get _hasFilters {
    return _developerFilter != null ||
        _actionFilter != null ||
        _dateRangeFilter != null;
  }

  String get _filterSummary {
    final filters = <String>[
      'Developer: ${_developerFilter ?? 'All'}',
      'Action: ${_actionFilter ?? 'All'}',
      'Date range: ${_dateRangeFilter == null ? 'All' : '${_formatDate(_dateRangeFilter!.start)} - ${_formatDate(_dateRangeFilter!.end)}'}',
    ];
    return filters.join(' | ');
  }

  List<DeveloperActionLogModel> _applyFilters(
    List<DeveloperActionLogModel> logs,
  ) {
    return logs.where((log) {
      final developerMatches =
          _developerFilter == null || _developerLabel(log) == _developerFilter;
      final actionMatches =
          _actionFilter == null || log.actionType == _actionFilter;
      final dateMatches =
          _dateRangeFilter == null || _isInDateRange(log.createdAt);
      return developerMatches && actionMatches && dateMatches;
    }).toList();
  }

  bool _isInDateRange(DateTime value) {
    final range = _dateRangeFilter;
    if (range == null) return true;
    final local = value.toLocal();
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return !local.isBefore(start) && !local.isAfter(end);
  }

  List<String> _developerOptions(List<DeveloperActionLogModel> logs) {
    final options = logs.map(_developerLabel).toSet().toList()..sort();
    return options;
  }

  List<String> _actionOptions(List<DeveloperActionLogModel> logs) {
    final options = logs.map((log) => log.actionType).toSet().toList()..sort();
    return options;
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRangeFilter,
    );
    if (picked != null) {
      setState(() => _dateRangeFilter = picked);
    }
  }
}

Future<void> _downloadActivityLogsPdf(
  BuildContext context,
  List<DeveloperActionLogModel> logs, {
  required String filterSummary,
}) async {
  if (logs.isEmpty) return;

  try {
    final generatedAt = DateTime.now();
    final sortedLogs = [...logs]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final startDate = sortedLogs.first.createdAt;
    final endDate = sortedLogs.last.createdAt;
    final pdf = pw.Document();
    final logo = await PdfBranding.loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildActivityLogPdfHeader(
          logo: logo,
          startDate: startDate,
          endDate: endDate,
          generatedAt: generatedAt,
          visibleCount: logs.length,
        ),
        footer: (context) => _buildActivityLogPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 24),
          pw.Text(
            'Export Filters',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Text(
            filterSummary,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Activity Log Entries',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.topLeft,
            headerAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(1.8),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(3.2),
            },
            headers: const ['Timestamp', 'User', 'Action Type', 'Description'],
            data: logs.map((log) {
              return [
                _formatDateTime(log.createdAt),
                _developerLabel(log),
                log.actionType,
                _logDescription(log),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'nsbsa_developer_activity_logs_${_fileDate(generatedAt)}.pdf',
      onLayout: (_) => pdf.save(),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate activity log PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

pw.Widget _buildActivityLogPdfHeader({
  required pw.MemoryImage logo,
  required DateTime startDate,
  required DateTime endDate,
  required DateTime generatedAt,
  required int visibleCount,
}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Image(logo, height: 50),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'NSBSA Developer Activity Log',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Date range: ${_formatDateTime(startDate)} - ${_formatDateTime(endDate)}',
          ),
          pw.Text('Exported: ${_formatDateTime(generatedAt)}'),
          pw.Text('Visible entries: $visibleCount'),
        ],
      ),
    ],
  );
}

pw.Widget _buildActivityLogPdfFooter(pw.Context context) {
  return pw.Column(
    children: [
      pw.Divider(color: PdfColors.grey300),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by NSBSA Developer Management System.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    ],
  );
}

String _developerLabel(DeveloperActionLogModel log) {
  final idPrefix = log.developerId.length > 8
      ? log.developerId.substring(0, 8)
      : log.developerId;
  return log.developerEmail ?? '$idPrefix...';
}

String _logDescription(DeveloperActionLogModel log) {
  final resource = '${log.resourceType ?? ''} ${log.resourceId ?? ''}'.trim();
  if (resource.isNotEmpty) return resource;
  if (log.payload == null || log.payload!.isEmpty) return '-';
  return log.payload!.entries
      .map((entry) => '${entry.key}: ${entry.value}')
      .join(', ');
}

String _formatDateTime(DateTime value) {
  return value.toLocal().toString().substring(0, 19);
}

String _formatDate(DateTime value) {
  return value.toLocal().toString().substring(0, 10);
}

String _fileDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}${two(local.month)}${two(local.day)}_${two(local.hour)}${two(local.minute)}';
}

class _SystemAuditLogPanel extends StatefulWidget {
  const _SystemAuditLogPanel();

  @override
  State<_SystemAuditLogPanel> createState() => _SystemAuditLogPanelState();
}

class _SystemAuditLogPanelState extends State<_SystemAuditLogPanel> {
  List<SystemAuditLogModel> _logs = [];
  bool _isLoading = true;
  String? _userFilter;
  String? _actionFilter;
  DateTimeRange? _dateRangeFilter;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final logs = await SystemAuditService.fetchLogs(limit: 500);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  List<SystemAuditLogModel> get _filteredLogs {
    return _logs.where((log) {
      if (_userFilter != null &&
          _userFilter!.isNotEmpty &&
          log.performedBy != _userFilter) {
        return false;
      }
      if (_actionFilter != null &&
          _actionFilter!.isNotEmpty &&
          log.actionType != _actionFilter) {
        return false;
      }
      if (_dateRangeFilter != null) {
        final date = log.timestamp;
        if (date.isBefore(_dateRangeFilter!.start) ||
            date.isAfter(_dateRangeFilter!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get _uniqueUsers =>
      _logs.map((e) => e.performedBy).toSet().toList()..sort();
  List<String> get _uniqueActions =>
      _logs.map((e) => e.actionType).toSet().toList()..sort();

  Future<void> _downloadPdf(List<SystemAuditLogModel> filteredLogs) async {
    try {
      final auth = context.read<AuthProvider>();
      final currentUserEmail = auth.userProfile?.email ?? 'Developer';

      SystemAuditService.logAction(
        actionType: 'EXPORT_AUDIT_LOG',
        affectedEntity: 'System Audit Log',
        description:
            'Exported ${filteredLogs.length} audit log entries to PDF.',
      );

      final pdfBytes = await AuditPdfService.generateAuditLogReport(
        filteredLogs,
      );
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'nsbsa_system_audit_log_$timestamp.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredLogs = _filteredLogs;

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _userFilter,
                  decoration: const InputDecoration(
                    labelText: 'User',
                    prefixIcon: Icon(Icons.person, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All users'),
                    ),
                    ..._uniqueUsers.map(
                      (user) => DropdownMenuItem(
                        value: user,
                        child: Text(user, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _userFilter = value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _actionFilter,
                  decoration: const InputDecoration(
                    labelText: 'Action Type',
                    prefixIcon: Icon(Icons.tune, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All actions'),
                    ),
                    ..._uniqueActions.map(
                      (action) => DropdownMenuItem(
                        value: action,
                        child: Text(action, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _actionFilter = value),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRangeFilter,
                  );
                  if (picked != null) {
                    setState(() => _dateRangeFilter = picked);
                  }
                },
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _dateRangeFilter == null
                      ? 'All dates'
                      : '${DateFormat('yyyy-MM-dd').format(_dateRangeFilter!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRangeFilter!.end)}',
                ),
              ),
              TextButton.icon(
                onPressed:
                    (_userFilter != null ||
                        _actionFilter != null ||
                        _dateRangeFilter != null)
                    ? () {
                        setState(() {
                          _userFilter = null;
                          _actionFilter = null;
                          _dateRangeFilter = null;
                        });
                      }
                    : null,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear filters'),
              ),
              FilledButton.icon(
                onPressed: filteredLogs.isEmpty
                    ? null
                    : () => _downloadPdf(filteredLogs),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Download Logs (PDF)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No system audit logs match the selected filters.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).cardColor,
                ),
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Action Type')),
                  DataColumn(label: Text('Performed By')),
                  DataColumn(label: Text('Affected Entity')),
                  DataColumn(label: Text('Description')),
                ],
                rows: filteredLogs.map((log) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(log.timestamp),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.actionType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(log.performedBy)),
                      DataCell(Text(log.affectedEntity)),
                      DataCell(Text(log.description)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
