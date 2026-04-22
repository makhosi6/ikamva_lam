import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics/export_summary_service.dart';
import '../game/task_queue_service.dart';
import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/gemma_model_config.dart';
import '../llm/llm_service.dart';
import '../llm/model_prepare_config.dart';
import '../llm/model_prepare_prefs.dart';
import '../metrics/metrics_store.dart';
import '../state/database_scope.dart';
import '../state/settings_scope.dart';
import '../sync/sync_outbox_flush_service.dart';
import '../version.dart';
import '../widgets/constrained_content.dart';
import '../widgets/ikamva_app_bar_title.dart';

String _buildModeLabel() {
  if (kDebugMode) return 'debug';
  if (kProfileMode) return 'profile';
  return 'release';
}

/// Dev-only diagnostics (TASKS §8.5, §15.3).
class DebugStatsScreen extends StatefulWidget {
  const DebugStatsScreen({super.key});

  @override
  State<DebugStatsScreen> createState() => _DebugStatsScreenState();
}

class _DebugStatsScreenState extends State<DebugStatsScreen> {
  int _refreshToken = 0;
  bool _busy = false;
  bool? _activeModelProbeOk;
  String? _activeModelProbeDetail;

  String get _resolvedEngineLabel {
    if (shouldUseFlutterGemmaEngine) {
      return 'FlutterGemmaLlmEngine (Android/iOS)';
    }
    return 'FlutterGemmaLlmEngine (non-mobile host; prepare/generate need device)';
  }

  Future<void> _probeActiveModel() async {
    if (!mounted) return;
    final settings = SettingsScope.of(context);
    setState(() {
      _activeModelProbeOk = null;
      _activeModelProbeDetail = null;
    });
    final ok = await probeFlutterGemmaActiveModelReady(settings);
    if (!mounted) return;
    setState(() {
      _activeModelProbeOk = ok;
      _activeModelProbeDetail =
          ok ? 'getActiveModel + close succeeded' : 'getActiveModel failed (see console)';
    });
  }

  String _downloadUrlPreview() {
    final u = ModelPrepareConfig.networkUrl;
    if (u.isEmpty) return '(empty)';
    if (u.length <= 56) return u;
    return '${u.substring(0, 56)}…';
  }

  Future<void> _copyToClipboard(String label, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('$label copied'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _probeActiveModel();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Debug panel is only available in debug builds.')),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final db = DatabaseScope.of(context);
    final settings = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const IkamvaAppBarTitle(title: 'Developer', logoHeight: 28),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _refreshToken++;
                      _probeActiveModel();
                    });
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ConstrainedContent(
          scrollable: false,
          child: FutureBuilder<Map<String, dynamic>>(
            key: ValueKey(_refreshToken),
            future: MetricsStore.load(),
            builder: (context, snap) {
              final metrics = snap.data ?? {};
              final metricsPretty = const JsonEncoder.withIndent('  ').convert(metrics);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    'Diagnostics',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Debug builds only (release shows a single-line notice). '
                    'Nothing here is learner-facing in production.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _Section(
                    title: 'Runtime',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv(context, 'App version', kAppVersion),
                        _kv(context, 'Build', _buildModeLabel()),
                        _kv(context, 'Target', defaultTargetPlatform.name),
                        if (!kIsWeb)
                          _kv(context, 'OS', Platform.operatingSystem),
                      ],
                    ),
                  ),

                  _Section(
                    title: 'On-device LLM',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv(context, 'Resolved engine', _resolvedEngineLabel),
                        _kv(
                          context,
                          'IKAMVA_MODEL_DOWNLOAD_URL',
                          ModelPrepareConfig.hasNetworkModelUrl
                              ? _downloadUrlPreview()
                              : '(not set)',
                        ),
                        _kv(
                          context,
                          'ModelType',
                          GemmaModelConfig.modelType.name,
                        ),
                        ListenableBuilder(
                          listenable: settings,
                          builder: (context, _) {
                            return _kv(
                              context,
                              'Low RAM profile',
                              '${settings.lowRamProfile}',
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        if (_activeModelProbeOk != null)
                          _kv(
                            context,
                            'Active model probe',
                            _activeModelProbeOk!
                                ? 'OK — $_activeModelProbeDetail'
                                : 'FAIL — $_activeModelProbeDetail',
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _probeActiveModel,
                          icon: const Icon(Icons.memory_outlined, size: 20),
                          label: const Text('Probe active Gemma model'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () {
                                  LlmService.instance.invalidateCachedEngine();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('LLM engine cache cleared.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.memory_outlined, size: 20),
                          label: const Text('Invalidate LLM engine cache'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await ModelPreparePrefs.clearPrepareDone();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Model prepare flag cleared — '
                                          'restart the app to see the prepare screen.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.restart_alt_outlined, size: 20),
                          label: const Text('Reset model prepare (next launch)'),
                        ),
                      ],
                    ),
                  ),

                  _Section(
                    title: 'Task queue',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          TaskQueueService.lastFillError ?? '—',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  _Section(
                    title: 'Metrics',
                    trailing: TextButton(
                      onPressed: () => _copyToClipboard('Metrics', metricsPretty),
                      child: const Text('Copy'),
                    ),
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Theme(
                            data: theme.copyWith(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              title: Text(
                                '${metrics.length} keys',
                                style: theme.textTheme.titleSmall,
                              ),
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withValues(
                                      alpha: 0.35,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.all(12),
                                    child: SelectableText(
                                      metricsPretty,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        fontFamilyFallback: const ['monospace'],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  _Section(
                    title: 'Actions',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    final json =
                                        await ExportSummaryService(db).buildSummaryJson();
                                    await _copyToClipboard('Export summary', json);
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: _busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.copy_all_outlined, size: 20),
                          label: Text(_busy ? 'Working…' : 'Copy export summary JSON'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() => _busy = true);
                                  try {
                                    final n =
                                        await SyncOutboxFlushService(db).flushPending();
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Flushed $n outbox row(s) (if sync URL set).',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                          label: const Text('Try sync outbox flush'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _kv(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
