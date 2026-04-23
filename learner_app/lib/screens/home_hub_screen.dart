import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/quest_repository.dart';
import '../db/app_database.dart';
import '../db/seed.dart';
import '../hub/daily_topics_service.dart';
import '../hub/hub_daily_topic_progress.dart';
import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/llm_service.dart';
import '../router/route_observers.dart';
import '../state/database_scope.dart';
import '../state/game_pause_store.dart';
import '../state/settings_scope.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/ikamva_app_bar_title.dart';

const double _hubTextGutter = 20;
const double _hubMaxContentWidth = 560;

/// Min height (approx.) for the [PageView] row to stack two topic cards; otherwise 1×1.
/// Based on [LayoutBuilder] height for the carousel strip (below the swipe hint), minus dots.
const double _carouselMinHeightForTwoUp = 296;

class _HubPayload {
  const _HubPayload(
    this.offers,
    this.done, {
    required this.questLevel,
    required this.questMaxTasks,
  });

  final List<HubTopicOffer> offers;
  final Set<String> done;
  /// CEFR-style level from the template quest used for hub sessions.
  final String questLevel;
  /// Max task slots per hub session (same cap as the template quest).
  final int questMaxTasks;
}

class HomeHubScreen extends StatefulWidget {
  const HomeHubScreen({super.key});

  @override
  State<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends State<HomeHubScreen> with RouteAware {
  late final Future<GamePauseSnapshot?> _pauseFuture = GamePauseStore.load();
  Future<_HubPayload>? _hubPayload;
  late final PageController _pageController;
  late final ScrollController _modelLogScroll;

  int _pageIndex = 0;

  /// Last synced with [LayoutBuilder] carousel height; controller reset when this changes.
  int _carouselTopicsPerPage = 2;
  bool _carouselSyncScheduled = false;

  bool _hubLlmCallbacksBound = false;
  PageRoute<dynamic>? _routeSubscription;
  bool _resumeModelBusy = false;

  final List<String> _modelInitLog = <String>[];
  int? _modelInitPercent;

  static const int _maxModelLogLines = 40;

  String get _todayKey => DailyTopicsService.calendarDayKeyLocal();

  void _appendModelLog(String line) {
    _modelInitLog.add(line);
    while (_modelInitLog.length > _maxModelLogLines) {
      _modelInitLog.removeAt(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_modelLogScroll.hasClients) return;
      final max = _modelLogScroll.position.maxScrollExtent;
      _modelLogScroll.jumpTo(max);
    });
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _modelLogScroll = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_routeSubscription == null && route is PageRoute<dynamic>) {
      _routeSubscription = route;
      ikamvaRouteObserver.subscribe(this, route);
    }
    if (!_hubLlmCallbacksBound) {
      _hubLlmCallbacksBound = true;
      final settings = SettingsScope.of(context);
      LlmService.instance.configure(
        settings,
        onModelInstallProgress: (p) {
          if (!mounted) return;
          setState(() => _modelInitPercent = p.clamp(0, 100));
        },
        onModelLifecycle: (phase, message, percent) {
          if (!mounted) return;
          setState(() {
            final pct = percent != null ? ' (${percent.clamp(0, 100)}%)' : '';
            _appendModelLog('[$phase]$pct $message');
            if (percent != null) {
              _modelInitPercent = percent.clamp(0, 100);
            }
          });
        },
      );
    }
    _hubPayload ??= _warmModelThenFetchHub(DatabaseScope.of(context));
  }

  @override
  void dispose() {
    if (_routeSubscription != null) {
      ikamvaRouteObserver.unsubscribe(this);
    }
    _modelLogScroll.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_recheckModelAfterReturningToHub());
  }

  Future<void> _recheckModelAfterReturningToHub() async {
    if (!shouldUseFlutterGemmaEngine || !mounted) return;
    setState(() {
      _resumeModelBusy = true;
      _modelInitPercent = null;
      _appendModelLog('[home] Back on hub — verifying on-device model…');
    });
    try {
      await LlmService.instance.ensureReady();
      if (!mounted) return;
      setState(() {
        _resumeModelBusy = false;
        _modelInitPercent = 100;
        _appendModelLog('[home] Model is ready.');
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _resumeModelBusy = false;
        _appendModelLog('[home] Model check failed: $e');
        _appendModelLog(
          '[home] Try Settings → Warm up model or free storage and return here.',
        );
      });
    }
  }

  Future<_HubPayload> _warmModelThenFetchHub(IkamvaDatabase db) async {
    if (shouldUseFlutterGemmaEngine) {
      if (mounted) {
        setState(() {
          _modelInitLog
            ..clear()
            ..add('[init] Warming on-device Gemma (first launch can take a few minutes)…');
          _modelInitPercent = null;
        });
        _scheduleModelLogScroll();
      }
      try {
        await LlmService.instance.ensureReady();
        if (mounted) {
          setState(() {
            _modelInitLog.add('[init] Gemma is ready for today\'s topics.');
            _modelInitPercent = 100;
          });
          _scheduleModelLogScroll();
        }
      } on Object catch (e) {
        if (mounted) {
          setState(() {
            _modelInitLog.add('[init] Could not finish model setup: $e');
            _modelInitLog.add(
              '[init] You can open Settings → Warm up model, or retry after freeing storage.',
            );
          });
          _scheduleModelLogScroll();
        }
      }
    }
    return _fetchHub(db);
  }

  void _scheduleModelLogScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_modelLogScroll.hasClients) return;
      _modelLogScroll.jumpTo(_modelLogScroll.position.maxScrollExtent);
    });
  }

  Future<_HubPayload> _fetchHub(IkamvaDatabase db) async {
    final offers = await DailyTopicsService.loadOffersForToday();
    final done = await HubDailyTopicProgress.completedForDay(_todayKey);
    final template = await QuestRepository(db).getById(kSeedQuestId);
    final level = (template?.level ?? 'A1').trim();
    final maxTasks = template?.maxTasks ?? 24;
    return _HubPayload(
      offers,
      done,
      questLevel: level.isEmpty ? 'A1' : level,
      questMaxTasks: maxTasks < 1 ? 24 : maxTasks,
    );
  }

  Future<void> _openTopic(HubTopicOffer offer) async {
    final q =
        'topic=${Uri.encodeQueryComponent(offer.topic)}&day=${Uri.encodeQueryComponent(_todayKey)}';
    await context.push('/game?$q');
    if (!mounted) return;
    setState(() {
      _hubPayload = _fetchHub(DatabaseScope.of(context));
    });
  }

  static int _pageCount(int offerCount, int topicsPerPage) {
    if (topicsPerPage < 1) return 0;
    return (offerCount + topicsPerPage - 1) ~/ topicsPerPage;
  }

  void _syncCarouselTopicsPerPageIfNeeded(int layoutPerPage) {
    if (layoutPerPage == _carouselTopicsPerPage) return;
    if (_carouselSyncScheduled) return;
    _carouselSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carouselSyncScheduled = false;
      if (!mounted || layoutPerPage == _carouselTopicsPerPage) return;
      setState(() {
        _pageController.dispose();
        _pageController = PageController(viewportFraction: 1);
        _carouselTopicsPerPage = layoutPerPage;
        _pageIndex = 0;
      });
    });
  }

  Widget _topicCard({
    required ThemeData theme,
    required IkamvaColors ik,
    required HubTopicOffer offer,
    required bool doneToday,
    required String questLevel,
    required int questMaxTasks,
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
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      offer.label,
                                      style: theme.textTheme.labelLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (doneToday)
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: ik.success,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              questLevel,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'About $questMaxTasks questions / games.(est 10min playtime)',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => _openTopic(offer),
                          child: const Text('Start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
                        'Swipe sideways for more themes. Fresh picks each day.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Resets after midnight (your device time).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (shouldUseFlutterGemmaEngine && _resumeModelBusy)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _hubTextGutter,
                  0,
                  _hubTextGutter,
                  8,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _hubMaxContentWidth,
                    ),
                    child: Card(
                      elevation: 0,
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Loading / verifying on-device Gemma',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_modelInitPercent != null)
                              Text(
                                'Progress: '
                                '${_modelInitPercent!.clamp(0, 100)}%',
                                style: theme.textTheme.labelMedium,
                              ),
                            const SizedBox(height: 6),
                            if (_modelInitPercent != null)
                              LinearProgressIndicator(
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                                value: _modelInitPercent!.clamp(0, 100) / 100.0,
                              )
                            else
                              LinearProgressIndicator(
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Verbose log',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 120,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: _modelInitLog.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Waiting…',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: _modelLogScroll,
                                        padding: const EdgeInsets.all(8),
                                        itemCount: _modelInitLog.length,
                                        itemBuilder: (context, i) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: SelectableText(
                                              _modelInitLog[i],
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                fontFamily: 'monospace',
                                                fontFamilyFallback: const [
                                                  'monospace',
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_HubPayload>(
                future: _hubPayload,
                builder: (context, snap) {
                  if (_hubPayload == null ||
                      snap.connectionState == ConnectionState.waiting) {
                    if (!shouldUseFlutterGemmaEngine) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Loading your quests… On-device Gemma runs on '
                                'Android and iOS; this build still loads hub '
                                'content.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _hubTextGutter,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _hubMaxContentWidth,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Loading on-device Gemma',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The model is copied from the app bundle into '
                                'plugin storage; detailed engine steps are below.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.75),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              if (_modelInitPercent != null)
                                LinearProgressIndicator(
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(6),
                                  value: _modelInitPercent!.clamp(0, 100) /
                                      100.0,
                                )
                              else
                                LinearProgressIndicator(
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              const SizedBox(height: 10),
                              Text(
                                _modelInitPercent != null
                                    ? 'Bundle → device copy: '
                                          '${_modelInitPercent!.clamp(0, 100)}% '
                                          '(and open / verify steps in log)'
                                    : 'Progress: preparing… (see log for phase)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Verbose log',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: _modelInitLog.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Text(
                                              'Waiting for engine status…',
                                              style:
                                                  theme.textTheme.bodySmall,
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          controller: _modelLogScroll,
                                          padding: const EdgeInsets.all(12),
                                          itemCount: _modelInitLog.length,
                                          itemBuilder: (context, i) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: SelectableText(
                                                _modelInitLog[i],
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  fontFamily: 'monospace',
                                                  fontFamilyFallback: const [
                                                    'monospace',
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
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
                          snap.hasError
                              ? 'Could not load topics. Try again later.'
                              : 'Daily topics are generated on this device. When the '
                                  'learning model is ready, fresh child-safe themes '
                                  'will appear here. Try again in a moment, or check Settings.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    );
                  }
                  final payload = snap.data!;
                  final offers = payload.offers;
                  final done = payload.done;
                  final practised = offers
                      .where((o) => done.contains(o.topic))
                      .length;

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
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
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
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _hubMaxContentWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 4),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, rowConstraints) {
                                      // Reserve ~24px for page dots below the row.
                                      final rowBudget =
                                          rowConstraints.maxHeight - 24;
                                      final perPage =
                                          rowBudget >=
                                              _carouselMinHeightForTwoUp
                                          ? 2
                                          : 1;
                                      _syncCarouselTopicsPerPageIfNeeded(
                                        perPage,
                                      );
                                      final pages = _pageCount(
                                        offers.length,
                                        perPage,
                                      );
                                      final safePages = pages > 0 ? pages : 1;
                                      final safeIndex = _pageIndex.clamp(
                                        0,
                                        safePages - 1,
                                      );

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _CarouselSideChevron(
                                                  icon: Icons
                                                      .chevron_left_rounded,
                                                  enabled: safeIndex > 0,
                                                  label: perPage == 2
                                                      ? 'Previous pair'
                                                      : 'Previous topic',
                                                  onTap: () {
                                                    _pageController
                                                        .previousPage(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    280,
                                                              ),
                                                          curve: Curves
                                                              .easeOutCubic,
                                                        );
                                                  },
                                                ),
                                                Expanded(
                                                  child: PageView.builder(
                                                    controller: _pageController,
                                                    itemCount: pages,
                                                    onPageChanged: (i) {
                                                      setState(
                                                        () => _pageIndex = i,
                                                      );
                                                    },
                                                    itemBuilder: (context, pageIdx) {
                                                      final children =
                                                          <Widget>[];
                                                      for (
                                                        var slot = 0;
                                                        slot < perPage;
                                                        slot++
                                                      ) {
                                                        final idx =
                                                            pageIdx * perPage +
                                                            slot;
                                                        if (idx >=
                                                            offers.length) {
                                                          children.add(
                                                            const Expanded(
                                                              child:
                                                                  SizedBox.shrink(),
                                                            ),
                                                          );
                                                        } else {
                                                          children.add(
                                                            Expanded(
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      left: 2,
                                                                      right: 2,
                                                                    ),
                                                                child: _topicCard(
                                                                  theme: theme,
                                                                  ik: ik,
                                                                  offer:
                                                                      offers[idx],
                                                                  doneToday: done
                                                                      .contains(
                                                                        offers[idx]
                                                                            .topic,
                                                                      ),
                                                                  questLevel:
                                                                      payload
                                                                          .questLevel,
                                                                  questMaxTasks:
                                                                      payload
                                                                          .questMaxTasks,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        if (slot <
                                                            perPage - 1) {
                                                          children.add(
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                          );
                                                        }
                                                      }
                                                      return Column(
                                                        children: children,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                _CarouselSideChevron(
                                                  icon: Icons
                                                      .chevron_right_rounded,
                                                  enabled:
                                                      safeIndex < safePages - 1,
                                                  label: perPage == 2
                                                      ? 'Next pair'
                                                      : 'Next topic',
                                                  onTap: () {
                                                    _pageController.nextPage(
                                                      duration: const Duration(
                                                        milliseconds: 280,
                                                      ),
                                                      curve:
                                                          Curves.easeOutCubic,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                              bottom: 4,
                                            ),
                                            child: _PageDots(
                                              count: pages,
                                              index: safeIndex,
                                              color: theme.colorScheme.primary,
                                              inactive: theme
                                                  .colorScheme
                                                  .outline
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                        child: const Text('Teacher/Parent mode'),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.push('/dev/stats'),
                          child: const Text('Developer tools (dev)'),
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
