import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ikamva_lam/llm/model_diagnostics.dart';

import '../../../../llm/flutter_gemma_llm_engine.dart';
import '../../../../llm/model_prepare_config.dart';
import '../../../../state/settings_scope.dart';
import '../../application/home_hub_state.dart';

const double kOnDeviceHubLoadingDiagnosticsHeight = 144;
const int _hubDiagnosticsTailMax = 48;

/// Single hub loading surface: spinner + fixed copy + optional live diagnosticolorScheme.
class OnDeviceHubLoadingPanel extends StatefulWidget {
  const OnDeviceHubLoadingPanel({
    super.key,
    this.scrollController,
    this.showDiagnostics = true,
    this.showElapsedExpectations = false,
    this.modelInitPercent,
    this.loadPhase,
    this.useOnPrimaryContainerTextColors = false,
    this.diagnosticsHeight = kOnDeviceHubLoadingDiagnosticsHeight,
  });

  final ScrollController? scrollController;
  final bool showDiagnostics;

  /// Elapsed timer + first-launch expectations (main hub load only).
  final bool showElapsedExpectations;

  /// Install / lifecycle progress (0–100); `null` shows an indeterminate bar.
  final int? modelInitPercent;

  /// Distinguishes model install vs daily topic generation (different copy).
  final HomeHubLoadPhase? loadPhase;

  /// When true, hub copy uses [ColorScheme.onPrimaryContainer] (solid card).
  final bool useOnPrimaryContainerTextColors;
  final double diagnosticsHeight;

  /// Same line as legacy `HomeHubScreen` loading card.
  static const String message = 'Loading / verifying on-device Gemma';

  @override
  State<OnDeviceHubLoadingPanel> createState() =>
      _OnDeviceHubLoadingPanelState();
}

class _OnDeviceHubLoadingPanelState extends State<OnDeviceHubLoadingPanel> {
  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null && widget.showDiagnostics) {
      ModelDiagnostics.instance.events.addListener(_scheduleDiagnosticsScroll);
    }
  }

  @override
  void didUpdateWidget(covariant OnDeviceHubLoadingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.showDiagnostics != widget.showDiagnostics) {
      ModelDiagnostics.instance.events.removeListener(
        _scheduleDiagnosticsScroll,
      );
      if (widget.scrollController != null && widget.showDiagnostics) {
        ModelDiagnostics.instance.events.addListener(
          _scheduleDiagnosticsScroll,
        );
      }
    }
  }

  @override
  void dispose() {
    ModelDiagnostics.instance.events.removeListener(_scheduleDiagnosticsScroll);
    super.dispose();
  }

  void _scheduleDiagnosticsScroll() {
    final c = widget.scrollController;
    if (c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !c.hasClients) return;
      c.jumpTo(c.position.maxScrollExtent);
    });
  }

  static List<ModelDiagnosticEvent> _tail(List<ModelDiagnosticEvent> all) {
    if (all.length <= _hubDiagnosticsTailMax) return all;
    return all.sublist(all.length - _hubDiagnosticsTailMax);
  }

  static String _formatLine(ModelDiagnosticEvent e) {
    final ts = e.timestamp.toIso8601String();
    final shortTs = ts.length >= 19 ? ts.substring(11, 19) : ts;
    final extra = e.data.isEmpty ? '' : ' ${jsonEncode(e.data)}';
    return '$shortTs [${e.area}/${e.action}] ${e.message}$extra';
  }

  List<Widget> _elapsedIfAny() {
    if (!widget.showElapsedExpectations) return const [];
    var estimatedMb = ModelPrepareConfig.estimatedDownloadMb;
    if (shouldUseFlutterGemmaEngine) {
      final v = SettingsScope.of(context).gemma4OnDeviceVariant;
      estimatedMb = ModelPrepareConfig.estimatedInstallMbFor(v);
    }
    return [
      _HubElapsedExpectationsCopy(
        useOnPrimaryContainerTone: widget.useOnPrimaryContainerTextColors,
        isTopicGenerationPhase:
            widget.loadPhase == HomeHubLoadPhase.fetchingHub,
        estimatedInstallMb: estimatedMb,
      ),
    ];
  }

  /// During topic fetch the install % is meaningless; show indeterminate bar.
  int? get _effectiveInstallPercent {
    if (widget.loadPhase == HomeHubLoadPhase.fetchingHub) return null;
    return widget.modelInitPercent;
  }

  String get _headlineText {
    if (widget.loadPhase == HomeHubLoadPhase.fetchingHub) {
      return 'Preparing today\'s topics';
    }
    return OnDeviceHubLoadingPanel.message;
  }

  /// Matches legacy hub card: 8px, optional %, 6px, bar, then elapsed copy.
  List<Widget> _progressAndElapsed(
    ThemeData theme,
    ColorScheme cs,
    Color? onCard,
  ) {
    final p = _effectiveInstallPercent;
    return [
      const SizedBox(height: 8),
      if (p != null)
        Text(
          'Progress: ${p.clamp(0, 100)}%',
          style: theme.textTheme.labelMedium?.copyWith(color: onCard),
        ),
      const SizedBox(height: 6),
      if (p != null)
        LinearProgressIndicator(
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          value: p.clamp(0, 100) / 100.0,
        )
      else
        LinearProgressIndicator(
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ..._elapsedIfAny(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onCard = null;//colorScheme.onPrimaryContainer;
    final row = Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: onCard),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _headlineText,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: onCard,
            ),
          ),
        ),
      ],
    );

    if (!widget.showDiagnostics || widget.scrollController == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [row, ..._progressAndElapsed(theme, colorScheme, onCard)],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        ..._progressAndElapsed(theme, colorScheme, onCard),
        const SizedBox(height: 8),
        Text(
          'Model diagnostics',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: onCard,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Live timeline from the engine (install, open, probe — same stream '
          'as Developer → Event Log).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: (onCard ?? colorScheme.onSurface).withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: SizedBox(
            height: widget.diagnosticsHeight,
            child: ValueListenableBuilder<List<ModelDiagnosticEvent>>(
              valueListenable: ModelDiagnostics.instance.events,
              builder: (context, events, _) {
                final tail = _tail(events);
                if (tail.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No engine events yet. Lines appear as install, open, '
                        'and inference steps run.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: tail.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        _formatLine(tail[i]),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['monospace'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

String _formatElapsedCompact(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m '
        '${d.inSeconds.remainder(60)}s';
  }
  if (d.inMinutes >= 1) {
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }
  return '${d.inSeconds}s';
}

/// Timer-driven copy from the legacy hub screen while load is in flight.
class _HubElapsedExpectationsCopy extends StatefulWidget {
  const _HubElapsedExpectationsCopy({
    required this.useOnPrimaryContainerTone,
    required this.isTopicGenerationPhase,
    required this.estimatedInstallMb,
  });

  final bool useOnPrimaryContainerTone;
  final bool isTopicGenerationPhase;
  final int estimatedInstallMb;

  @override
  State<_HubElapsedExpectationsCopy> createState() =>
      _HubElapsedExpectationsCopyState();
}

class _HubElapsedExpectationsCopyState
    extends State<_HubElapsedExpectationsCopy> {
  late final DateTime _startedAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = DateTime.now().difference(_startedAt);
    final gbApprox = (widget.estimatedInstallMb / 1024).ceil().clamp(1, 999);
    final titleColor = null;
    final bodyColor = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Loading so far: ${_formatElapsedCompact(elapsed)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isTopicGenerationPhase
              ? (shouldUseFlutterGemmaEngine
                    ? 'The model is ready. Generating and checking today\'s theme '
                          'list on-device can still take several minutes '
                          '(multiple Gemma runs and safety checks).'
                    : 'Loading today\'s theme list for this build.')
              : (shouldUseFlutterGemmaEngine
                    ? 'This step may download and install roughly $gbApprox GB of '
                          'Gemma 4 on first use, then copy into the engine sandbox. '
                          'First launch often takes several minutes on many phones '
                          '— that is normal and depends more on network and storage '
                          'speed than RAM.'
                    : 'Generating today\'s topics can take up to a few minutes on '
                          'first run (on-device generation and safety checks).'),
          style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
        ),
      ],
    );
  }
}
