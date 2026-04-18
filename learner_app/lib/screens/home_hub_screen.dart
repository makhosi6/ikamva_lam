import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../hub/daily_topics_service.dart';
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
  late final Future<List<HubTopicOffer>> _topicsFuture =
      DailyTopicsService.loadOffersForToday();

  String get _todayKey => DailyTopicsService.calendarDayKeyLocal();

  void _openTopic(HubTopicOffer offer) {
    final q =
        'topic=${Uri.encodeQueryComponent(offer.topic)}&day=${Uri.encodeQueryComponent(_todayKey)}';
    context.push('/game?$q');
  }

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
                "Today's topics",
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Fresh themes each day — with AI when your device can run it. '
                'Pick one to practise.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Resets after midnight (your device time).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<HubTopicOffer>>(
                  future: _topicsFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'Could not load topics. Pull down later or check settings.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      );
                    }
                    final offers = snap.data!;
                    return ListView.separated(
                      itemCount: offers.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final offer = offers[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ik.accentSun
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          offer.label,
                                          style: theme.textTheme.labelLarge,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'A1',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Short games — about 3 minutes.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => _openTopic(offer),
                                  child: const Text('Start'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<GamePauseSnapshot?>(
                future: _pauseFuture,
                builder: (context, snap) {
                  final pause = snap.data;
                  if (pause == null) return const SizedBox.shrink();
                  return OutlinedButton(
                    onPressed: () => context.push('/game?resume=1'),
                    child: const Text('Resume paused session'),
                  );
                },
              ),
              const SizedBox(height: 12),
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
