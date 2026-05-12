import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/developer_controls_provider.dart';

/// Shown when a shell module is turned off via [DeveloperControlsProvider].
class FeatureDisabledPlaceholder extends StatelessWidget {
  final String featureKey;

  const FeatureDisabledPlaceholder({super.key, required this.featureKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.watch<DeveloperControlsProvider>().flagFor(featureKey)?.label ?? featureKey;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 64, color: theme.colorScheme.primary.withOpacity(0.6)),
              const SizedBox(height: 24),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'This feature is temporarily unavailable.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
