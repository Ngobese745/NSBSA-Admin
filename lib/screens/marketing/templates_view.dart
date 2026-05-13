import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class TemplatesView extends StatefulWidget {
  const TemplatesView({super.key});

  @override
  State<TemplatesView> createState() => _TemplatesViewState();
}

class _TemplatesViewState extends State<TemplatesView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketing = context.watch<MarketingProvider>();
    final gold = const Color(0xFFD4AF37);

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
                  Text(
                    'Template Library',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reusable branded templates for consistent messaging',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateTemplateDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (marketing.templates.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 48, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text('No templates yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.2,
                ),
                itemCount: marketing.templates.length,
                itemBuilder: (context, index) {
                  final t = marketing.templates[index];
                  return _TemplateCard(template: t);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog(BuildContext context) {
    // Implementation
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = template['type'] as String? ?? 'email';

    return Card(
      color: theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    type == 'email'
                        ? Icons.mail_outline
                        : type == 'sms'
                            ? Icons.sms_outlined
                            : Icons.chat_outlined,
                    color: const Color(0xFFD4AF37),
                    size: 20,
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                    itemBuilder: (_) => [
                      const PopupMenuItem(child: Text('Edit')),
                      const PopupMenuItem(child: Text('Duplicate')),
                      const PopupMenuItem(child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                template['name'] ?? 'Untitled Template',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  template['content'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Last used: 2 days ago',
                style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
