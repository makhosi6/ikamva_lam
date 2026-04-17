import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';

class HomeHubScreen extends StatelessWidget {
  const HomeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Practice from your teacher will show here. For now, try a sample session.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ik.accentSun.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Topic: Food',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'A1',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sample quest',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Short games — about 3 minutes.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => context.push('/game'),
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.push('/session-summary'),
                child: const Text('View sample session summary'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
