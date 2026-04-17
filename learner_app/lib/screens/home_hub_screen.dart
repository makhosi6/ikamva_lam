import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../db/seed.dart';
import '../state/game_pause_store.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
  late final Future<GamePauseSnapshot?> _pauseFuture = GamePauseStore.load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ik = context.ikamvaColors;
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Your quests'),
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
              const SizedBox(height: 12),
              FutureBuilder<GamePauseSnapshot?>(
                future: _pauseFuture,
                builder: (context, snap) {
                  final pause = snap.data;
                  final canResume =
                      pause != null && pause.questId == kSeedQuestId;
                  if (!canResume) return const SizedBox.shrink();
                  return OutlinedButton(
                    onPressed: () => context.push('/game?resume=1'),
                    child: const Text('Resume sample session'),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.push('/session-summary'),
                child: const Text('View sample session summary'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/teacher'),
                child: const Text('Teacher mode'),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/dev/stats'),
                  child: const Text('Debug stats (dev)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
