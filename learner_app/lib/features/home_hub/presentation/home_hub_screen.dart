import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../hub/daily_topics_service.dart';
import '../../../llm/llm_service.dart';
import '../../../llm/model_diagnostics.dart';
import '../../../router/route_observers.dart';
import '../../../state/database_scope.dart';
import '../../../state/game_pause_store.dart';
import '../../../state/settings_scope.dart';
import '../../../theme/ikamva_colors.dart';
import '../../../widgets/ikamva_app_bar_title.dart';
import '../application/home_hub_bloc.dart';
import '../application/home_hub_event.dart';
import '../application/home_hub_state.dart';
import 'widgets/home_hub_footer_actions.dart';
import 'widgets/home_hub_main_content.dart';
import 'widgets/home_hub_resume_banner.dart';
import 'widgets/home_hub_topic_headers.dart';

/// Home hub: DDD feature entry — provides [HomeHubBloc] and route lifecycle.
class HomeHubScreen extends StatelessWidget {
  const HomeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeHubBloc(
        database: DatabaseScope.of(context, listen: false),
        settingsStore: SettingsScope.of(context, listen: false),
      )..add(const HomeHubStarted()),
      child: const _HomeHubRouteScope(),
    );
  }
}

class _HomeHubRouteScope extends StatefulWidget {
  const _HomeHubRouteScope();

  @override
  State<_HomeHubRouteScope> createState() => _HomeHubRouteScopeState();
}

class _HomeHubRouteScopeState extends State<_HomeHubRouteScope>
    with RouteAware {
  PageRoute<dynamic>? _routeSubscription;
  bool _llmConfigured = false;
  int? _modelInitPercent;

  late final ScrollController _loadingDiagnosticsScroll =
      ScrollController();
  late final ScrollController _hubPeekDiagnosticsScroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_routeSubscription == null && route is PageRoute<dynamic>) {
      _routeSubscription = route;
      ikamvaRouteObserver.subscribe(this, route);
    }
    if (!_llmConfigured) {
      _llmConfigured = true;
      LlmService.instance.configure(
        SettingsScope.of(context),
        onModelInstallProgress: (p) {
          if (!mounted) return;
          if (_modelInitPercent != null && _modelInitPercent! >= p) return;
          setState(() => _modelInitPercent = p);
        },
        onModelLifecycle: (phase, message, percent) {
          if (!mounted) return;
          setState(() {
            if (percent != null &&
                (_modelInitPercent == null || _modelInitPercent! < percent)) {
              _modelInitPercent = percent;
            }
          });
        },
      );
    }
  }

  @override
  void dispose() {
    if (_routeSubscription != null) {
      ikamvaRouteObserver.unsubscribe(this);
    }
    _loadingDiagnosticsScroll.dispose();
    _hubPeekDiagnosticsScroll.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    context.read<HomeHubBloc>().add(const HomeHubResumeVerifyRequested());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeHubBloc, HomeHubState>(
          listenWhen: (prev, curr) =>
              (curr is HomeHubLoading &&
                  curr.phase == HomeHubLoadPhase.modelWarm &&
                  (prev is! HomeHubLoading ||
                      prev.phase != HomeHubLoadPhase.modelWarm)) ||
              (curr is HomeHubReady &&
                  curr.resumeBusy &&
                  (prev is! HomeHubReady || !prev.resumeBusy)),
          listener: (_, _) {
            setState(() => _modelInitPercent = null);
          },
        ),
        BlocListener<HomeHubBloc, HomeHubState>(
          listenWhen: (prev, curr) =>
              prev is HomeHubLoading &&
              prev.phase == HomeHubLoadPhase.modelWarm &&
              curr is HomeHubLoading &&
              curr.phase == HomeHubLoadPhase.fetchingHub,
          listener: (_, _) {
            setState(() => _modelInitPercent = null);
          },
        ),
        BlocListener<HomeHubBloc, HomeHubState>(
          listenWhen: (prev, curr) =>
              prev is HomeHubLoading &&
              prev.phase == HomeHubLoadPhase.modelWarm &&
              curr is HomeHubReady,
          listener: (_, _) {
            setState(() => _modelInitPercent = null);
          },
        ),
      ],
      child: _HomeHubView(
        loadingDiagnosticsScroll: _loadingDiagnosticsScroll,
        hubPeekDiagnosticsScroll: _hubPeekDiagnosticsScroll,
        modelInitPercent: _modelInitPercent,
      ),
    );
  }
}

class _HomeHubView extends StatefulWidget {
  const _HomeHubView({
    required this.loadingDiagnosticsScroll,
    required this.hubPeekDiagnosticsScroll,
    required this.modelInitPercent,
  });

  final ScrollController loadingDiagnosticsScroll;
  final ScrollController hubPeekDiagnosticsScroll;
  final int? modelInitPercent;

  @override
  State<_HomeHubView> createState() => _HomeHubViewState();
}

class _HomeHubViewState extends State<_HomeHubView> {
  late final Future<GamePauseSnapshot?> _pauseFuture = GamePauseStore.load();

  @override
  void initState() {
    super.initState();
    ModelDiagnostics.instance.events.addListener(_onDiagnosticsEventsChanged);
  }

  @override
  void dispose() {
    ModelDiagnostics.instance.events.removeListener(_onDiagnosticsEventsChanged);
    super.dispose();
  }

  void _onDiagnosticsEventsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = widget.hubPeekDiagnosticsScroll;
      if (c.hasClients) c.jumpTo(c.position.maxScrollExtent);
    });
  }

  Future<void> _openTopic(HubTopicOffer offer) async {
    final day = DailyTopicsService.calendarDayKeyLocal();
    final q =
        'topic=${Uri.encodeQueryComponent(offer.topic)}'
        '&day=${Uri.encodeQueryComponent(day)}';
    await context.push('/game?$q');
    if (!mounted) return;
    context.read<HomeHubBloc>().add(const HomeHubReturnedFromTopic());
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
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Reload quests',
            onPressed: () {
              context.read<HomeHubBloc>().add(const HomeHubReloadRequested());
            },
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
            const HomeHubTopicHeaders(),
            HomeHubResumeBanner(modelInitPercent: widget.modelInitPercent),
            Expanded(
              child: HomeHubMainContent(
                loadingDiagnosticsScroll: widget.loadingDiagnosticsScroll,
                hubPeekDiagnosticsScroll: widget.hubPeekDiagnosticsScroll,
                modelInitPercent: widget.modelInitPercent,
                theme: theme,
                ik: ik,
                onOpenTopic: _openTopic,
              ),
            ),
            HomeHubFooterActions(pauseFuture: _pauseFuture),
          ],
        ),
      ),
    );
  }
}
