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
import '../widgets/nsbsa_loading_overlay.dart';
import '../models/developer_controls.dart';
import '../providers/auth_provider.dart';
import '../providers/developer_controls_provider.dart';
import '../services/access_control_service.dart';
import 'developer/api_management_panel.dart';
import '../theme/app_theme.dart';

/// A small section label for dialogs.
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
      ),
    );
  }
}

/// A small icon button for the header action area.
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

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
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<DeveloperControlsProvider>().refresh();
        } catch (_) {}
      }
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
          // ─── Header ───
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.developer_mode,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Developer Management',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _HeaderAction(
                  icon: Icons.refresh,
                  tooltip: 'Reload',
                  onPressed: () {
                    final devCtrl = context.read<DeveloperControlsProvider>();
                    runWithLoading(context, task: () => devCtrl.refresh());
                  },
                ),
              ],
            ),
          ),
          // ─── Missing tables warning ───
          Consumer<DeveloperControlsProvider>(
            builder: (context, dev, _) {
              if (dev.tablesMissing) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.deepOrange.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.deepOrange.shade300,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Developer tables are not installed. Run '
                            'supabase/migrations/20250512120002_developer_controls.sql '
                            'in Supabase SQL Editor.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.deepOrange.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // ─── Tab bar ───
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryGold,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppTheme.primaryGold,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: theme.textTheme.bodyMedium,
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'Banners'),
                Tab(text: 'Feature toggles'),
                Tab(text: 'Activity log'),
                Tab(text: 'System Audit Log'),
                Tab(text: 'API Keys'),
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
                ApiManagementPanel(),
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
    final theme = Theme.of(context);
    return Consumer<DeveloperControlsProvider>(
      builder: (context, dev, _) {
        if (dev.isLoading && dev.banners.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // ─── Section header ───
            Row(
              children: [
                Text(
                  'System Banners',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${dev.banners.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: dev.tablesMissing
                      ? null
                      : () => _openBannerEditor(context, null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New banner'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryGold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (dev.banners.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.15),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 36,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No banners yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create one to show a system-wide notice.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
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

    final severityColor = switch (banner.severity) {
      'critical' => Colors.red,
      'warning' => Colors.amber,
      _ => Colors.blue,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.12),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top row: title + toggle ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: banner.isEnabled
                        ? severityColor
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banner.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: banner.isEnabled,
                  activeThumbColor: AppTheme.primaryGold,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: dev.tablesMissing || uid == null
                      ? null
                      : (v) {
                          runWithLoading(context, task: () async {
                            await dev.setBannerEnabled(
                              bannerId: banner.id,
                              enabled: v,
                              developerId: uid,
                              developerEmail: email,
                            );
                          }, successMessage: v ? 'Banner enabled.' : 'Banner disabled.');
                        },
                ),
              ],
            ),
          ),
          // ─── Meta row ───
          Padding(
            padding: const EdgeInsets.fromLTRB(31, 8, 12, 8),
            child: Row(
              children: [
                _MetaChip(
                  label: banner.bannerType.replaceAll('_', ' '),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                _MetaChip(
                  label: banner.severity,
                  color: severityColor,
                ),
                const Spacer(),
                _MiniButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed: dev.tablesMissing
                      ? null
                      : () => _openBannerEditor(context, banner),
                ),
                const SizedBox(width: 4),
                _MiniButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
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
                            final ctx = context;
                            runWithLoadingAfterPop(
                              ctx, task: () async {
                                await dev.removeBanner(
                                  bannerId: banner.id,
                                  developerId: uid,
                                  developerEmail: email,
                                );
                              },
                              successMessage: 'Banner deleted.',
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  const _MiniButton({
    required this.icon,
    required this.label,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = color ?? theme.textTheme.bodySmall?.color;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: fgColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
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
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Banner type',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
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
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) => setLocal(() => severity = v ?? severity),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starts',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: startsAt,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) {
                                setLocal(
                                  () => startsAt = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    startsAt.hour,
                                    startsAt.minute,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(
                              startsAt.toLocal().toString().substring(0, 16),
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ends (optional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: ctx,
                                      initialDate:
                                          endsAt ??
                                          DateTime.now().add(
                                            const Duration(days: 1),
                                          ),
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
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                  ),
                                  label: Text(
                                    endsAt == null
                                        ? 'No end'
                                        : endsAt!
                                            .toLocal()
                                            .toString()
                                            .substring(0, 16),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                              ),
                              if (endsAt != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () =>
                                      setLocal(() => endsAt = null),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
    final theme = Theme.of(context);
    return Consumer<DeveloperControlsProvider>(
      builder: (context, dev, _) {
        if (dev.isLoading && dev.flags.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (dev.flags.isEmpty) {
          return Center(
            child: Text(
              'No feature flags loaded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          );
        }
        final auth = context.watch<AuthProvider>();
        final uid = auth.userProfile?.id;
        final email = auth.userProfile?.email;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // ─── Section header ───
            Row(
              children: [
                Text(
                  'Feature Flags',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${dev.flags.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...dev.flags.map((f) => _FeatureCard(
                  flag: f,
                  uid: uid,
                  email: email,
                  tablesMissing: dev.tablesMissing,
                )),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final FeatureFlagModel flag;
  final String? uid;
  final String? email;
  final bool tablesMissing;

  const _FeatureCard({
    required this.flag,
    required this.uid,
    required this.email,
    required this.tablesMissing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dev = context.read<DeveloperControlsProvider>();
    final hasAccessRules =
        flag.allowedRoles.isNotEmpty || flag.allowedUsers.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.12),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            // ─── Status dot ───
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: flag.enabled ? Colors.green : Colors.grey.withOpacity(0.4),
              ),
            ),
            const SizedBox(width: 12),
            // ─── Label + key ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    flag.featureKey,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                  if (hasAccessRules) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (flag.allowedRoles.isNotEmpty)
                          _FeatureAccessBadge(
                            label: flag.allowedRoles.join(', '),
                          ),
                        if (flag.allowedRoles.isNotEmpty &&
                            flag.allowedUsers.isNotEmpty)
                          const SizedBox(width: 6),
                        if (flag.allowedUsers.isNotEmpty)
                          _FeatureAccessBadge(
                            label: '${flag.allowedUsers.length} user${flag.allowedUsers.length == 1 ? '' : 's'}',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // ─── Toggle ───
            Switch(
              value: flag.enabled,
              activeThumbColor: AppTheme.primaryGold,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: tablesMissing || uid == null
                      ? null
                      : (v) {
                          runWithLoading(context, task: () async {
                            await dev.setFeatureFlag(
                              featureKey: flag.featureKey,
                              enabled: v,
                              developerId: uid!,
                              developerEmail: email,
                              allowedRoles: flag.allowedRoles,
                              allowedUsers: flag.allowedUsers,
                            );
                          }, successMessage: v ? 'Feature enabled.' : 'Feature disabled.');
                        },
            ),
            const SizedBox(width: 4),
            // ─── Access config button ───
            _MiniButton(
              icon: Icons.settings_outlined,
              label: 'Access',
              onPressed: tablesMissing || uid == null
                  ? null
                  : () => _editFeatureAccess(
                        context,
                        dev,
                        flag,
                        uid!,
                        email,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureAccessBadge extends StatelessWidget {
  final String label;

  const _FeatureAccessBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: AppTheme.primaryGold,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

const List<String> _allRoles = [
  'Super Admin',
  'Admin',
  'Finance',
  'Marketing',
  'Development Facilitator',
  'Verifying Operator',
];

Future<void> _editFeatureAccess(
  BuildContext context,
  DeveloperControlsProvider dev,
  FeatureFlagModel flag,
  String uid,
  String? email,
) async {
  final roles = List<String>.from(flag.allowedRoles);
  final users = List<String>.from(flag.allowedUsers);
  final userCtrl = TextEditingController();

  final enableState = <bool>[flag.enabled];

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('Access control: ${flag.label}'),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When this feature is disabled, who should still be able '
                  'to access it for testing?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 20),
                // ─── Feature state ───
                _SectionLabel(label: 'Feature state'),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  subtitle: const Text(
                    'Toggle feature for all users',
                  ),
                  value: enableState[0],
                  activeThumbColor: AppTheme.primaryGold,
                  dense: true,
                  onChanged: (v) => setLocal(() => enableState[0] = v),
                ),
                const SizedBox(height: 8),
                // ─── Allowed roles ───
                _SectionLabel(label: 'Allowed roles'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _allRoles.map((role) {
                    final selected = roles.contains(role);
                    return FilterChip(
                      label: Text(role, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      selectedColor: AppTheme.primaryGold.withOpacity(0.2),
                      checkmarkColor: AppTheme.primaryGold,
                      side: BorderSide.none,
                      onSelected: (v) {
                        setLocal(() {
                          if (v) {
                            roles.add(role);
                          } else {
                            roles.remove(role);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // ─── Allowed users ───
                _SectionLabel(label: 'Allowed users (email addresses)'),
                const SizedBox(height: 4),
                Text(
                  'colane@mwelasefin.co.za always has access via '
                  'Super Admin allowlist.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                if (users.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: users.asMap().entries.map((entry) {
                        final i = entry.key;
                        final u = entry.value;
                        return Chip(
                          label: Text(
                            u,
                            style: const TextStyle(fontSize: 11),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setLocal(() => users.removeAt(i)),
                        );
                      }).toList(),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          hintText: 'email@example.com',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        final text = userCtrl.text.trim();
                        if (text.isNotEmpty && !users.contains(text)) {
                          setLocal(() => users.add(text));
                          userCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
    await dev.setFeatureFlag(
      featureKey: flag.featureKey,
      enabled: enableState[0],
      developerId: uid,
      developerEmail: email,
      allowedRoles: roles,
      allowedUsers: users,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feature access updated')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
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
    final theme = Theme.of(context);
    return Consumer<DeveloperControlsProvider>(
      builder: (context, dev, _) {
        if (dev.isLoading && dev.recentLogs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredLogs = _applyFilters(dev.recentLogs);
        final developerOptions = _developerOptions(dev.recentLogs);
        final actionOptions = _actionOptions(dev.recentLogs);

        return RefreshIndicator(
          onRefresh: dev.reloadLogsOnly,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              // ─── Section header ───
              Row(
                children: [
                  Text(
                    'Activity Log',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${filteredLogs.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: dev.tablesMissing || filteredLogs.isEmpty
                        ? null
                        : () => _downloadActivityLogsPdf(
                              context,
                              filteredLogs,
                              filterSummary: _filterSummary,
                            ),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGold,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ─── Filters ───
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.12),
                    width: 0.5,
                  ),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _developerFilter,
                        decoration: const InputDecoration(
                          hintText: 'Developer',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All developers'),
                          ),
                          ...developerOptions.map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                d,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _developerFilter = v),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _actionFilter,
                        decoration: const InputDecoration(
                          hintText: 'Action type',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All actions'),
                          ),
                          ...actionOptions.map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(
                                a,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _actionFilter = v),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickDateRange(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: theme.dividerColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _dateRangeFilter == null
                            ? 'All dates'
                            : '${_formatDate(_dateRangeFilter!.start)} – ${_formatDate(_dateRangeFilter!.end)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (_hasFilters)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _developerFilter = null;
                            _actionFilter = null;
                            _dateRangeFilter = null;
                          });
                        },
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ─── Log entries ───
              if (filteredLogs.isEmpty && dev.recentLogs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.filter_alt_off_outlined,
                          size: 32,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No entries match the selected filters.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (dev.recentLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 32,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No developer actions logged yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredLogs.map((log) {
                  final when = _formatDateTime(log.createdAt);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.bolt,
                              size: 14,
                              color: AppTheme.primaryGold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.actionType,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$when • ${_developerLabel(log)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                  ),
                                ),
                                if (_logDescription(log).isNotEmpty &&
                                    _logDescription(log) != '-')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _logDescription(log),
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  runWithLoading(context, task: () async {
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
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
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
    }, successMessage: 'Activity log PDF generated.');
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
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
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
    try {
      final logs = await SystemAuditService.fetchLogs(limit: 500);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching audit logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    runWithLoading(context, task: () async {
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
    }, successMessage: 'Audit PDF downloaded.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredLogs = _filteredLogs;

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          // ─── Section header ───
          Row(
            children: [
              Text(
                'System Audit Log',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${filteredLogs.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: filteredLogs.isEmpty
                    ? null
                    : () => _downloadPdf(filteredLogs),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ─── Filters ───
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.12),
                width: 0.5,
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _userFilter,
                    decoration: const InputDecoration(
                      hintText: 'User',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All users'),
                      ),
                      ..._uniqueUsers.map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text(
                            u,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _userFilter = v),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _actionFilter,
                    decoration: const InputDecoration(
                      hintText: 'Action Type',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All actions'),
                      ),
                      ..._uniqueActions.map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(
                            a,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _actionFilter = v),
                  ),
                ),
                OutlinedButton(
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
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: theme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _dateRangeFilter == null
                        ? 'All dates'
                        : '${DateFormat('yyyy-MM-dd').format(_dateRangeFilter!.start)} – ${DateFormat('yyyy-MM-dd').format(_dateRangeFilter!.end)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (_userFilter != null ||
                    _actionFilter != null ||
                    _dateRangeFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _userFilter = null;
                        _actionFilter = null;
                        _dateRangeFilter = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ─── Log table ───
          if (filteredLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.filter_alt_off_outlined,
                      size: 32,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No system audit logs match the selected filters.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.12),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    theme.scaffoldBackgroundColor,
                  ),
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 48,
                  horizontalMargin: 16,
                  columnSpacing: 28,
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
                              'yyyy-MM-dd HH:mm',
                            ).format(log.timestamp),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.actionType,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            log.performedBy,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        DataCell(
                          Text(
                            log.affectedEntity,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              log.description,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
