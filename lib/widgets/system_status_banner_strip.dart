import 'package:flutter/material.dart';

import '../models/developer_controls.dart';

/// Full-width strip for the active [SystemBannerModel] (main shell).
class SystemStatusBannerStrip extends StatelessWidget {
  final SystemBannerModel banner;
  final VoidCallback? onDismiss;

  const SystemStatusBannerStrip({super.key, required this.banner, this.onDismiss});

  Color _background(ThemeData theme) {
    switch (banner.severity) {
      case 'critical':
        return Colors.red.shade900.withOpacity(0.92);
      case 'info':
        return Colors.blue.shade900.withOpacity(0.88);
      case 'warning':
      default:
        return Colors.amber.shade900.withOpacity(0.9);
    }
  }

  String get _typeLabel {
    switch (banner.bannerType) {
      case 'under_development':
        return 'UNDER DEVELOPMENT';
      case 'system_update':
      default:
        return 'SYSTEM UPDATE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _background(theme);
    final textColor = banner.severity == 'warning' ? Colors.black87 : Colors.white;

    return Material(
      color: bg,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                banner.bannerType == 'under_development' ? Icons.engineering : Icons.info_outline,
                color: textColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel,
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      banner.title,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner.message,
                      style: TextStyle(color: textColor.withOpacity(0.95), fontSize: 12, height: 1.35),
                    ),
                    if (banner.endsAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Until ${banner.endsAt!.toLocal().toString().substring(0, 16)}',
                        style: TextStyle(color: textColor.withOpacity(0.75), fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(Icons.close, color: textColor.withOpacity(0.85), size: 20),
                  onPressed: onDismiss,
                  tooltip: 'Hide for this session',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
