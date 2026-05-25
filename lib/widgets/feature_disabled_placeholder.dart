import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/developer_controls_provider.dart';

/// Shown when a shell module is turned off via [DeveloperControlsProvider].
class FeatureDisabledPlaceholder extends StatelessWidget {
  final String? featureKey;
  final String? customLabel;
  final String? customMessage;

  const FeatureDisabledPlaceholder({
    super.key,
    this.featureKey,
    this.customLabel,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dev = context.watch<DeveloperControlsProvider>();
    final auth = context.watch<AuthProvider>();

    String label = customLabel ?? featureKey ?? 'Feature Unavailable';
    if (featureKey != null && customLabel == null) {
      label = dev.flagFor(featureKey!)?.label ?? featureKey!;
    }

    final canBypass = featureKey != null &&
        dev.canAccessFeature(featureKey!, auth.userProfile);

    final message = canBypass
        ? 'This feature is currently disabled for general users. You have access as a test reviewer.'
        : (customMessage ?? 'This feature is temporarily unavailable.');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                canBypass ? Icons.science : Icons.construction,
                size: 64,
                color: canBypass
                    ? theme.colorScheme.secondary.withOpacity(0.8)
                    : theme.colorScheme.primary.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: canBypass ? Colors.amber.shade300 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
