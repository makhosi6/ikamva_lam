import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';

class GameShellScreen extends StatelessWidget {
  const GameShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Practice'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Hint'),
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: 0.35,
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.primary,
                backgroundColor: ik.accentSun.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'Task 2 of 6 · Vocabulary',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Fill in the blank (coming next)',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'The real cloze UI, voice, and on-device Gemma generation will plug in here.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/session-summary'),
                child: const Text('Finish sample session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
