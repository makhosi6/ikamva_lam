import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session done'),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 64,
                color: ik.accentSun,
              ),
              const SizedBox(height: 16),
              Text(
                'Great work!',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Placeholder stats — accuracy, hints used, and streak will come from SQLite.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _StatRow(label: 'Accuracy', value: '—'),
              _StatRow(label: 'Hints used', value: '—'),
              _StatRow(label: 'Tasks completed', value: '—'),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
