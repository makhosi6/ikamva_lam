import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/ikamva_colors.dart';
import '../state/settings_scope.dart';
import '../widgets/constrained_content.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Ikamva Lam',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'My future — playful English practice that works offline.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.ikamvaColors.accentSun.withValues(
                      alpha: 0.25,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'You will read, listen, and speak in short games. Your teacher guides what you practise.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await SettingsScope.of(context).setOnboardingComplete(true);
                  if (context.mounted) context.go('/home');
                },
                child: const Text('Continue'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/settings'),
                child: const Text('Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
