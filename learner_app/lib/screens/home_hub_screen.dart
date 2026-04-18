import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../hub/daily_topics_service.dart';
import '../hub/hub_daily_topic_progress.dart';
import '../state/game_pause_store.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/ikamva_app_bar_title.dart';

const double _hubTextGutter = 20;
const double _hubMaxContentWidth = 560;

class _HubPayload {
  const _HubPayload(this.offers, this.done);

  final List<HubTopicOffer> offers;
  final Set<String> done;
}

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> {
  late final Future<GamePauseSnapshot?> _pauseFuture = GamePauseStore.load();
  late Future<_HubPayload> _hubPayload;
  late final PageController _pageController;

  int _pageIndex = 0;

  String get _todayKey => DailyTopicsService.calendarDayKeyLocal();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _hubPayload = _fetchHub();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<_HubPayload> _fetchHub() async {
    final offers = await DailyTopicsService.loadOffersForToday();
    final done = await HubDailyTopicProgress.completedForDay(_todayKey);
    return _HubPayload(offers, done);
  }

  Future<void> _openTopic(HubTopicOffer offer) async {
    final q =
        'topic=${Uri.encodeQueryComponent(offer.topic)}&day=${Uri.encodeQueryComponent(_todayKey)}';
    await context.push('/game?$q');
    if (!mounted) return;
    setState(() {
      _hubPayload = _fetchHub();
    });
  }

  int _pageCount(int offerCount) => (offerCount + 1) >> 1;

  Widget _topicCard({
    required ThemeData theme,
    required IkamvaColors ik,
    required HubTopicOffer offer,
    required bool doneToday,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: doneToday
              ? ik.success.withValues(alpha: 0.65)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: doneToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ik.accentSun.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      offer.label,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('A1', style: theme.textTheme.bodySmall),
              ],
            ),
            if (doneToday) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: ik.success),
                  const SizedBox(width: 6),
                  Text(
                    'Done today',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ik.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            Text(
              'Short games — about 3 minutes.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _openTopic(offer),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _hubTextGutter,
                8,
                _hubTextGutter,
                0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _hubMaxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Today's topics",
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Swipe sideways — two themes per screen. Fresh picks each day.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Resets after midnight (your device time).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_HubPayload>(
                future: _hubPayload,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError ||
                      !snap.hasData ||
                      snap.data!.offers.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _hubTextGutter,
                      ),
                      child: Center(
                        child: Text(
                          'Could not load topics. Try again later.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    );
                  }
                  final payload = snap.data!;
                  final offers = payload.offers;
                  final done = payload.done;
                  final practised =
                      offers.where((o) => done.contains(o.topic)).length;
                  final pages = _pageCount(offers.length);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$practised of ${offers.length} topics practised today',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        child: Text(
                          pages > 1
                              ? 'More themes on the left or right →'
                              : 'All today’s themes fit on this screen.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CarouselSideChevron(
                              icon: Icons.chevron_left_rounded,
                              enabled: _pageIndex > 0,
                              label: 'Previous pair',
                              onTap: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                            ),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: pages,
                                onPageChanged: (i) {
                                  setState(() => _pageIndex = i);
                                },
                                itemBuilder: (context, pageIdx) {
                                  final i0 = pageIdx * 2;
                                  final i1 = i0 + 1;
                                  final a = offers[i0];
                                  final b =
                                      i1 < offers.length ? offers[i1] : null;
                                  return Column(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 2,
                                            right: 2,
                                          ),
                                          child: _topicCard(
                                            theme: theme,
                                            ik: ik,
                                            offer: a,
                                            doneToday: done.contains(a.topic),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 2,
                                            right: 2,
                                          ),
                                          child: b != null
                                              ? _topicCard(
                                                  theme: theme,
                                                  ik: ik,
                                                  offer: b,
                                                  doneToday:
                                                      done.contains(b.topic),
                                                )
                                              : const SizedBox.expand(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            _CarouselSideChevron(
                              icon: Icons.chevron_right_rounded,
                              enabled: _pageIndex < pages - 1,
                              label: 'Next pair',
                              onTap: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: _PageDots(
                          count: pages,
                          index: _pageIndex,
                          color: theme.colorScheme.primary,
                          inactive: theme.colorScheme.outline
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _hubTextGutter,
                8,
                _hubTextGutter,
                8,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _hubMaxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselSideChevron extends StatelessWidget {
  const _CarouselSideChevron({
    required this.icon,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          label: label,
          button: true,
          enabled: enabled,
          child: SizedBox(
            width: 28,
            child: Center(
              child: Icon(
                icon,
                size: 28,
                color: enabled
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.color,
    required this.inactive,
  });

  final int count;
  final int index;
  final Color color;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 12);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? color : inactive,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}
