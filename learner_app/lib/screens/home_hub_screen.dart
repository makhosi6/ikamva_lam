import 'dart:async';
import 'dart:convert';

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
import '../llm/model_diagnostics.dart';
import '../llm/model_prepare_config.dart';
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
const int _hubDiagnosticsTailMax = 48;
const double _hubDiagnosticsPeekHeight = 144;

/// Data for the hub carousel once async work finishes.
///
/// Built by [_fetchHub]: topic offers for today, which topics the learner
/// already completed, plus quest template metadata for copy on cards.
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

  /// Single future shared by both hub [FutureBuilder]s: **warm LLM (if any) →
  /// then** load hub data.
  ///
  /// **Assigned in** [didChangeDependencies] (`??=` so only the first assignment
  /// sticks): [_warmModelThenFetchHub]. **Replaced** (new future) when the user
  /// refreshes [_reloadHubContent] or returns from a topic [_openTopic].
  ///
  /// **Why it can take a long time**
  ///
  /// 1. **On Android/iOS** ([shouldUseFlutterGemmaEngine]): awaits
  ///    [LlmService.ensureReady] first — copies/opens the bundled `.litertlm`
  ///    (first launch is often minutes). That call is wrapped in a **10 minute**
  ///    timeout inside the service.
  /// 2. **Then always:** [DailyTopicsService.loadOffersForToday] — fast if
  ///    SharedPreferences cache hits for today; otherwise runs **on-device
  ///    generation** ([LlmService.generate] in a loop, up to several attempts)
  ///    plus child-safety checks — can add many more seconds per attempt
  ///    (generation has its own timeout in [LlmService]).
  /// 3. **Also:** DB reads for completed topics and the seed quest template.
  ///
  /// Until this future completes, [FutureBuilder] stays in
  /// [ConnectionState.waiting] and the UI shows the loading branch.
  Future<_HubPayload>? _hubPayload;
  late final PageController _pageController;

  /// Full-screen hub loading diagnostics (only one list uses this at a time).
  late final ScrollController _loadingDiagnosticsScroll;

  /// Peek panel on the loaded hub; separate from [_loadingDiagnosticsScroll]
  /// so two lists never share one controller (e.g. resume banner + peek).
  late final ScrollController _hubPeekDiagnosticsScroll;

  int _pageIndex = 0;

  /// Last synced with [LayoutBuilder] carousel height; controller reset when this changes.
  int _carouselTopicsPerPage = 2;
  bool _carouselSyncScheduled = false;

  bool _hubLlmCallbacksBound = false;
  PageRoute<dynamic>? _routeSubscription;
  bool _resumeModelBusy = false;

  int? _modelInitPercent;

  /// Start time for the active [_hubPayload] future; cleared when it completes.
  DateTime? _hubPayloadLoadStartedAt;

  /// Drives a once-per-second [setState] so elapsed loading time stays visible.
  Timer? _hubPayloadElapsedTimer;

  /// Bumped on each new [_hubPayload] assignment so an older future's
  /// [Future.whenComplete] cannot clear timer/start time for a newer load.
  int _hubPayloadGeneration = 0;

  String get _todayKey => DailyTopicsService.calendarDayKeyLocal();

  /// Wraps hub loads so the UI can show elapsed time until [whenComplete].
  Future<_HubPayload> _trackHubFuture(Future<_HubPayload> inner) {
    final gen = ++_hubPayloadGeneration;
    _hubPayloadLoadStartedAt = DateTime.now();
    _hubPayloadElapsedTimer?.cancel();
    _hubPayloadElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && gen == _hubPayloadGeneration) setState(() {});
    });
    return inner.whenComplete(() {
      if (gen != _hubPayloadGeneration) return;
      _hubPayloadElapsedTimer?.cancel();
      _hubPayloadElapsedTimer = null;
      _hubPayloadLoadStartedAt = null;
      if (mounted) setState(() {});
    });
  }

  static String _formatElapsedCompact(Duration d) {
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m '
          '${d.inSeconds.remainder(60)}s';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  /// Timer + expectations copy while [_hubPayload] is in flight.
  Widget _hubElapsedAndExpectationsCopy(ThemeData theme) {
    final start = _hubPayloadLoadStartedAt;
    if (start == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().difference(start);
    final gbApprox =
        (ModelPrepareConfig.estimatedDownloadMb / 1024).ceil().clamp(1, 999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Loading so far: ${_formatElapsedCompact(elapsed)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          shouldUseFlutterGemmaEngine
              ? 'This step installs roughly $gbApprox GB from the app bundle '
                    'into device storage (copy + engine setup). First launch '
                    'often takes several minutes on many phones — that is '
                    'normal and depends more on storage speed than RAM.'
              : 'Generating today\'s topics can take up to a few minutes on '
                    'first run (on-device generation and safety checks).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  void _onDiagnosticsEventsChanged() {
    _scheduleDiagnosticsScroll();
  }

  List<ModelDiagnosticEvent> _tailDiagnostics(List<ModelDiagnosticEvent> all) {
    if (all.length <= _hubDiagnosticsTailMax) return all;
    return all.sublist(all.length - _hubDiagnosticsTailMax);
  }

  String _formatHubDiagnosticLine(ModelDiagnosticEvent e) {
    final ts = e.timestamp.toIso8601String();
    final shortTs = ts.length >= 19 ? ts.substring(11, 19) : ts;
    final extra = e.data.isEmpty ? '' : ' ${jsonEncode(e.data)}';
    return '$shortTs [${e.area}/${e.action}] ${e.message}$extra';
  }

  Widget _buildDiagnosticsScrollView(
    ThemeData theme, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(8),
    double? height,
    ScrollController? scrollController,
  }) {
    final view = ValueListenableBuilder<List<ModelDiagnosticEvent>>(
      valueListenable: ModelDiagnostics.instance.events,
      builder: (context, events, _) {
        final tail = _tailDiagnostics(events);
        final child = tail.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No engine events yet. Lines appear as install, open, '
                    'and inference steps run.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                controller: scrollController,
                padding: padding,
                itemCount: tail.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText(
                      _formatHubDiagnosticLine(tail[i]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontFamilyFallback: const ['monospace'],
                      ),
                    ),
                  );
                },
              );
        if (height != null) {
          return SizedBox(height: height, child: child);
        }
        return child;
      },
    );
    return view;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _loadingDiagnosticsScroll = ScrollController();
    _hubPeekDiagnosticsScroll = ScrollController();
    ModelDiagnostics.instance.events.addListener(_onDiagnosticsEventsChanged);
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
          if (!mounted || _modelInitPercent != null && (_modelInitPercent?? 0) >= p) return;
          print('onModelInstallProgress: $p');
          setState(() => _modelInitPercent = p);
        },
        onModelLifecycle: (phase, message, percent) {
          if (!mounted) return;
          print('onModelLifecycle: $phase $message $percent');
          setState(() {
            if (percent != null && (_modelInitPercent == null || (_modelInitPercent?? 0) < percent)) {
              _modelInitPercent = percent;
            }
          });
        },
      );
    }
    _hubPayload ??=
        _trackHubFuture(_warmModelThenFetchHub(DatabaseScope.of(context)));
  }

  @override
  void dispose() {
    _hubPayloadElapsedTimer?.cancel();
    ModelDiagnostics.instance.events.removeListener(
      _onDiagnosticsEventsChanged,
    );
    if (_routeSubscription != null) {
      ikamvaRouteObserver.unsubscribe(this);
    }
    _loadingDiagnosticsScroll.dispose();
    _hubPeekDiagnosticsScroll.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_recheckModelAfterReturningToHub());
  }

  Future<void> _recheckModelAfterReturningToHub() async {
    if (!shouldUseFlutterGemmaEngine || !mounted) return;
    ModelDiagnostics.instance.log(
      area: 'hub',
      action: 'resume_check',
      message: 'Back on hub — verifying on-device model…',
    );
    setState(() {
      _resumeModelBusy = true;
      _modelInitPercent = null;
    });
    try {
      await LlmService.instance.ensureReady();
      if (!mounted) return;
      ModelDiagnostics.instance.log(
        area: 'hub',
        action: 'resume_ok',
        message: 'Model is ready.',
      );
      setState(() {
        _resumeModelBusy = false;
        _modelInitPercent = 100;
      });
    } on Object catch (e) {
      if (!mounted) return;
      ModelDiagnostics.instance.log(
        area: 'hub',
        action: 'resume_failed',
        message: 'Model check failed: $e',
      );
      setState(() {
        _resumeModelBusy = false;
      });
    }
  }

  /// First screen entry: optionally block on the on-device model, then load hub
  /// rows from disk/LLM.
  ///
  /// When [shouldUseFlutterGemmaEngine] is true, **nothing after this returns**
  /// until [LlmService.instance.ensureReady] finishes (install from bundle if
  /// needed, native open, retries). Failures are logged to [ModelDiagnostics];
  /// [_fetchHub] still runs afterward so the hub can show empty/error state.
  ///
  /// When false (e.g. desktop), this immediately continues to [_fetchHub]
  /// only — no model warm step, but topic generation may still call the LLM
  /// service if the app is configured to use it on that platform.
  Future<_HubPayload> _warmModelThenFetchHub(IkamvaDatabase db) async {
    if (shouldUseFlutterGemmaEngine) {
      ModelDiagnostics.instance.log(
        area: 'hub',
        action: 'warm_start',
        message:
            'Warming on-device Gemma (first launch can take a few minutes)…',
      );
      if (mounted) {
        setState(() => _modelInitPercent = null);
        _scheduleDiagnosticsScroll();
      }
      try {
        await LlmService.instance.ensureReady();
        if (mounted) {
          ModelDiagnostics.instance.log(
            area: 'hub',
            action: 'warm_ok',
            message: 'Gemma is ready for today\'s topics.',
          );
          setState(() => _modelInitPercent = 100);
          _scheduleDiagnosticsScroll();
        }
      } on Object catch (e) {
        if (mounted) {
          ModelDiagnostics.instance.log(
            area: 'hub',
            action: 'warm_failed',
            message: 'Could not finish model setup: $e',
            data: <String, Object?>{
              'hint': 'Settings → Warm up model; free storage',
            },
          );
          setState(() {});
          _scheduleDiagnosticsScroll();
        }
      }
    }
    return _fetchHub(db);
  }

  void _scheduleDiagnosticsScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final c in [_loadingDiagnosticsScroll, _hubPeekDiagnosticsScroll]) {
        if (c.hasClients) {
          c.jumpTo(c.position.maxScrollExtent);
        }
      }
    });
  }

  /// Loads everything the carousel needs **after** any model warm-up.
  ///
  /// Order: daily topic offers (cache or LLM + safety gates) → completed set
  /// for today → quest template for level / max task copy.
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

  void _reloadHubContent() {
    setState(() {
      _pageIndex = 0;
      _hubPayload = _trackHubFuture(_fetchHub(DatabaseScope.of(context)));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(0);
    });
  }

  Future<void> _openTopic(HubTopicOffer offer) async {
    final q =
        'topic=${Uri.encodeQueryComponent(offer.topic)}&day=${Uri.encodeQueryComponent(_todayKey)}';
    await context.push('/game?$q');
    if (!mounted) return;
    setState(() {
      _hubPayload = _trackHubFuture(_fetchHub(DatabaseScope.of(context)));
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
                            Text(questLevel, style: theme.textTheme.bodySmall),
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
    final showResumeBanner =
        shouldUseFlutterGemmaEngine && _resumeModelBusy;
    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Your quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reload quests',
            onPressed: _reloadHubContent,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top strip: headers vs. Gemma status card while [_hubPayload] runs.
            FutureBuilder<_HubPayload>(
              future: _hubPayload,
              builder: (context, snap) {
                final gemmaBlockingUi =
                    shouldUseFlutterGemmaEngine &&
                    (_resumeModelBusy ||
                        snap.connectionState == ConnectionState.waiting);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!gemmaBlockingUi)
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
                                  'Swipe sideways for more themes. '
                                  'Fresh picks each day.',
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
                    if (showResumeBanner || (_modelInitPercent?? 0) < 100)
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
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.35),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
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
                                            'Loading / verifying on-device '
                                            'Gemma',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
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
                                        value:
                                            _modelInitPercent!.clamp(0, 100) /
                                            100.0,
                                      )
                                    else
                                      LinearProgressIndicator(
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    _hubElapsedAndExpectationsCopy(theme),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Model diagnostics',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Live timeline from the engine (install, '
                                      'open, probe — same stream as Developer → '
                                      'Event Log).',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.72),
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: _buildDiagnosticsScrollView(
                                        theme,
                                        height: _hubDiagnosticsPeekHeight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!gemmaBlockingUi || showResumeBanner)
                      const SizedBox(height: 12),
                  ],
                );
              },
            ),
            // Main hub body: show once Gemma install reached 100% (or no Gemma).
            if (!showResumeBanner &&
                (!shouldUseFlutterGemmaEngine ||
                    (_modelInitPercent ?? 0) >= 100))
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
                              _hubElapsedAndExpectationsCopy(theme),
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
                              const SizedBox(height: 20),
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
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              _hubElapsedAndExpectationsCopy(theme),
                              const SizedBox(height: 16),
                              if (_modelInitPercent != null)
                                LinearProgressIndicator(
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(6),
                                  value:
                                      _modelInitPercent!.clamp(0, 100) / 100.0,
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
                                          '(and open / verify steps below)'
                                    : 'Progress: preparing… (see diagnostics below)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Model diagnostics',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Engine timeline: service + hub + native steps '
                                '(matches Developer → Event Log).',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  // max space for the diagnostics scroll view
                                  child: SizedBox(
                                    height: _hubDiagnosticsPeekHeight,
                                    child: _buildDiagnosticsScrollView(
                                      theme,
                                      padding: const EdgeInsets.all(12),
                                      scrollController: _loadingDiagnosticsScroll,
                                    ),
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
                      if (shouldUseFlutterGemmaEngine)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            left: 6,
                            right: 6,
                          ),
                          child: Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timeline_outlined,
                                        size: 22,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'On-device model diagnostics',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Same live log as Developer → Event Log: '
                                    'install, open, inference, and hub steps.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.72),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface
                                          .withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: _buildDiagnosticsScrollView(
                                      theme,
                                      height: _hubDiagnosticsPeekHeight,
                                      scrollController:
                                          _hubPeekDiagnosticsScroll,
                                    ),
                                  ),
                                ],
                              ),
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
